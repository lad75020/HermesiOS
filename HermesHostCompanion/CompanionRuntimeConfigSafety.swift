import Darwin
import Foundation

/// Small, fail-closed mutations of raw configuration. Never loads Hermes defaults,
/// expands environment references, or treats a parse/read failure as an empty file.
enum CompanionRuntimeConfigSafety {
    enum Failure: LocalizedError {
        case unavailable, rejected, changed, invalidEnvReplacement
        var errorDescription: String? {
            switch self {
            case .unavailable: "The selected Hermes Python runtime with PyYAML is required for safe configuration edits."
            case .rejected: "Configuration was not changed. It must be valid, unambiguous YAML; tool toggles require an explicit CLI toolset list (not a composite such as hermes-cli). Use Hermes tools to configure defaults/composites first."
            case .invalidEnvReplacement: "Enter a nonempty, single-line replacement value. Presence markers cannot be saved; use the explicit Remove action to delete a key."
            case .changed: "Configuration changed during this request. Reload and retry; no replacement was written."
            }
        }
    }

    static let configuredMarker = "[configured]"

    /// Legacy wire dictionaries now carry presence markers, never values, even for
    /// text fields. Filter to the panel's permitted keys before leaving the host.
    static func envMetadata(content: String, allowedKey: (String) -> Bool) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            var assignment = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if assignment.hasPrefix("export ") { assignment = String(assignment.dropFirst(7)) }
            guard !assignment.hasPrefix("#"), let equals = assignment.firstIndex(of: "=") else { continue }
            let key = assignment[..<equals].trimmingCharacters(in: .whitespaces)
            guard allowedKey(key) else { continue }
            var value = assignment[assignment.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, (value.first == "\"" && value.last == "\"" || value.first == "'" && value.last == "'") {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value.isEmpty ? nil : configuredMarker
        }
        return result
    }

    static func validateEnvReplacement(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value != configuredMarker,
              value.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n\0")) == nil else { throw Failure.invalidEnvReplacement }
    }

    static func read(_ url: URL) throws -> String {
        // Only a genuinely absent file may be initialized. Permissions/encoding
        // failures must never discard an existing configuration.
        do { return try String(contentsOf: url, encoding: .utf8) }
        catch CocoaError.fileReadNoSuchFile { return "" }
    }

    static func apply(configURL: URL, request: [String: Any]) async throws -> [String: Any] {
        let original = try read(configURL)
        var payload = request
        payload["content"] = original
        let result = try await transform(workspacePath: configURL.deletingLastPathComponent().path, request: payload)
        if let content = result["content"] as? String {
            // Optimistic conflict detection protects edits while parsing. Atomic
            // replacement protects readers (not a cross-process writer lock).
            guard try read(configURL) == original else { throw Failure.changed }
            try content.write(to: configURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        }
        return result
    }

    static func transform(workspacePath: String, request: [String: Any]) async throws -> [String: Any] {
        guard let context = CompanionWorkspaceSecurity.resolvedHermesCLIContext(from: workspacePath) else { throw Failure.unavailable }
        let python = context.cliRootURL.appendingPathComponent("hermes-agent/venv/bin/python")
        guard FileManager.default.isExecutableFile(atPath: python.path) else { throw Failure.unavailable }
        let data = try JSONSerialization.data(withJSONObject: request)
        guard data.count <= 2_000_000 else { throw Failure.rejected }
        let temporaryHome = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: temporaryHome) }
        let output: CompanionSubprocess.Output
        do {
            output = try await CompanionSubprocess.run(
                executableURL: python,
                arguments: ["-I", "-c", yamlScript],
                environment: ["PATH": "/usr/bin:/bin", "HOME": temporaryHome.path, "HERMES_HOME": temporaryHome.path],
                input: data,
                timeout: 10,
                maxOutputBytes: 2_000_001
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Failure.unavailable
        }
        guard output.status == 0,
              let response = try JSONSerialization.jsonObject(with: output.stdout) as? [String: Any] else { throw Failure.rejected }
        return response
    }

    // Exposed internally so fixture tests execute this exact production transformer.
    static let yamlScript = #"""
import copy, json, sys, yaml
from yaml.tokens import AliasToken, AnchorToken

# Only SafeLoader constructors are inherited: Python object tags remain forbidden.
class StrictLoader(yaml.SafeLoader):
    pass

def mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, str) or key in result or key == '<<':
            raise ValueError('Ambiguous mapping')
        result[key] = loader.construct_object(value_node, deep=deep)
    return result
StrictLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)

def child(parent, key, create=False):
    if key not in parent and create:
        parent[key] = {}
    value = parent.get(key, {})
    if not isinstance(value, dict):
        raise ValueError('Expected mapping')
    return value

r = json.load(sys.stdin)
text = r['content']
if len(text) > 1000000 or any(isinstance(t, (AliasToken, AnchorToken)) for t in yaml.scan(text)):
    raise ValueError('Unsupported YAML aliases or size')
cfg = yaml.load(text, Loader=StrictLoader)
if cfg is None and not text.strip(): cfg = {}
if cfg is None and all(not s.strip() or s.lstrip().startswith('#') for s in text.splitlines()): cfg = {}
if not isinstance(cfg, dict): raise ValueError('Expected root mapping')
action = r['action']
result = {}
if action in ('listTools', 'setTool'):
    platforms = child(cfg, 'platform_toolsets')
    names = platforms.get('cli')
    if not isinstance(names, list) or any(not isinstance(n, str) or n.startswith('hermes-') for n in names):
        raise ValueError('Explicit CLI list required')
    if action == 'setTool':
        key = r['key']
        if not isinstance(key, str) or type(r['enabled']) is not bool: raise ValueError('Invalid toggle')
        if key == 'stt':
            # Hermes treats STT as a configuration-only capability: its switch
            # is stt.enabled and it must never enter platform_toolsets.cli.
            child(cfg, 'stt', create=True)['enabled'] = r['enabled']
        else:
            names = list(names)
            if r['enabled'] and key not in names: names.append(key)
            if not r['enabled']: names = [n for n in names if n != key]
            platforms['cli'] = names
    result['enabledToolsets'] = names
    stt = child(cfg, 'stt')
    stt_value = stt.get('enabled', True)
    stt_enabled = (stt_value.strip().lower() in ('1', 'true', 'yes', 'on')
                   if isinstance(stt_value, str) else bool(stt_value))
    result['configOnlyEnabledToolsets'] = ['stt'] if stt_enabled else []
elif action in ('listPlatforms', 'setPlatform'):
    # Match gateway/config_loader.py merge_platform_sections: nested, root,
    # then gateway.<platform>. Inspect only raw YAML; never load auth/defaults.
    gateway = child(cfg, 'gateway')
    nested = child(gateway, 'platforms')
    platforms = child(cfg, 'platforms')
    def blocks(key):
        return [child(parent, key) for parent in (nested, platforms, gateway) if key in parent]
    def enabled_value(key):
        value = False
        for block in blocks(key):
            if 'enabled' in block: value = block['enabled'] is True
        return value
    if action == 'setPlatform':
        key = r['platform']
        if not isinstance(key, str) or key not in r['platforms'] or type(r['enabled']) is not bool: raise ValueError('Invalid toggle')
        existing = blocks(key)
        # Write the highest-precedence existing block, retaining every other
        # key. Explicit false prevents the plugin env pass from re-enabling it.
        target = existing[-1] if existing else child(child(cfg, 'platforms', create=True), key, create=True)
        target['enabled'] = r['enabled']
        platforms = child(cfg, 'platforms')
    result['platformEnabled'] = {key: enabled_value(key) for key in r['platforms']}
else:
    raise ValueError('Unsupported operation')
if action in ('setTool', 'setPlatform'):
    content = yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True)
    # Fail before write if serialization changes an unrelated value/type.
    if yaml.load(content, Loader=StrictLoader) != cfg: raise ValueError('Round-trip changed data')
    result['content'] = content
print(json.dumps(result))
"""#
}
