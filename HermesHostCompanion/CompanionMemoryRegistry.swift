
import Foundation

enum CompanionMemoryRegistryError: LocalizedError {
    case invalidWorkspace(String)
    case invalidEnvironmentKey(String)
    case inactiveSupermemoryProvider
    case supermemoryCommandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            return "The Hermes workspace path '\(path)' is invalid."
        case .invalidEnvironmentKey(let key):
            return "The memory provider environment key '\(key)' is not allowlisted."
        case .inactiveSupermemoryProvider:
            return "Supermemory is not the active Hermes memory provider."
        case .supermemoryCommandFailed(let message):
            return message
        }
    }
}

final class CompanionMemoryRegistry {
    private let entryDelimiter = "\n§\n"
    private let memoryCharLimit = 2_200
    private let userCharLimit = 1_375

    private struct KnownProvider {
        let description: String
        let envVars: [String]
    }

    private static let knownProviders: [String: KnownProvider] = [
        "honcho": .init(description: "Honcho — managed memory and user-profile backend.", envVars: ["HONCHO_API_KEY"]),
        "hindsight": .init(description: "Hindsight — memory bank provider.", envVars: ["HINDSIGHT_API_KEY", "HINDSIGHT_API_URL", "HINDSIGHT_BANK_ID"]),
        "mem0": .init(description: "Mem0 — hosted long-term memory provider.", envVars: ["MEM0_API_KEY"]),
        "retaindb": .init(description: "RetainDB — hosted memory storage.", envVars: ["RETAINDB_API_KEY"]),
        "supermemory": .init(description: "Supermemory — hosted memory provider.", envVars: ["SUPERMEMORY_API_KEY"]),
        "holographic": .init(description: "Holographic — local/plugin memory provider.", envVars: []),
        "openviking": .init(description: "OpenViking — endpoint-backed memory provider.", envVars: ["OPENVIKING_ENDPOINT", "OPENVIKING_API_KEY"]),
        "byterover": .init(description: "ByteRover — hosted memory backend.", envVars: ["BRV_API_KEY"])
    ]

    func load(workspacePath: String) throws -> MemoryConfigResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let memory = readMemoryFile(workspaceURL: workspaceURL)
        let user = readUserFile(workspaceURL: workspaceURL)
        let provider = readActiveProvider(workspaceURL: workspaceURL)
        let providers = discoverProviders(workspaceURL: workspaceURL, activeProvider: provider)
        let env = readEnv(workspaceURL: workspaceURL, allowedKeys: Set(providers.flatMap(\.envVars)))
        return MemoryConfigResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            memoryFilePath: memoryURL(for: workspaceURL).path,
            userFilePath: userURL(for: workspaceURL).path,
            configPath: configURL(for: workspaceURL).path,
            envFilePath: envURL(for: workspaceURL).path,
            configSizeOnDiskBytes: sizeOnDisk(for: configURL(for: workspaceURL)),
            envSizeOnDiskBytes: sizeOnDisk(for: envURL(for: workspaceURL)),
            memory: memory,
            user: user,
            stats: readStats(workspaceURL: workspaceURL),
            provider: provider,
            providers: providers,
            env: env
        )
    }

    func addEntry(workspacePath: String, content: String) throws -> MemoryOperationResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let entries = parseMemoryEntries(readFile(memoryURL(for: workspaceURL)).content)
        let newEntries = entries + [MemoryEntry(index: entries.count, content: content.trimmingCharacters(in: .whitespacesAndNewlines))]
        let serialized = serialize(entries: newEntries)
        guard serialized.count <= memoryCharLimit else {
            return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: false, error: "Would exceed memory limit (\(serialized.count)/\(memoryCharLimit) chars)")
        }
        try write(serialized, to: memoryURL(for: workspaceURL))
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: true, error: nil)
    }

    func updateEntry(workspacePath: String, index: Int, content: String) throws -> MemoryOperationResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        var entries = parseMemoryEntries(readFile(memoryURL(for: workspaceURL)).content)
        guard index >= 0 && index < entries.count else {
            return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: false, error: "Entry not found")
        }
        entries[index] = MemoryEntry(index: index, content: content.trimmingCharacters(in: .whitespacesAndNewlines))
        let serialized = serialize(entries: entries)
        guard serialized.count <= memoryCharLimit else {
            return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: false, error: "Would exceed memory limit (\(serialized.count)/\(memoryCharLimit) chars)")
        }
        try write(serialized, to: memoryURL(for: workspaceURL))
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: true, error: nil)
    }

    func removeEntry(workspacePath: String, index: Int) throws -> MemoryOperationResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        var entries = parseMemoryEntries(readFile(memoryURL(for: workspaceURL)).content)
        guard index >= 0 && index < entries.count else {
            return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: false, error: "Entry not found")
        }
        entries.remove(at: index)
        try write(serialize(entries: entries), to: memoryURL(for: workspaceURL))
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: true, error: nil)
    }

    func writeUserProfile(workspacePath: String, content: String) throws -> MemoryOperationResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        guard content.count <= userCharLimit else {
            return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: false, error: "Exceeds limit (\(content.count)/\(userCharLimit) chars)")
        }
        try write(content, to: userURL(for: workspaceURL))
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: true, error: nil)
    }

    func setProvider(workspacePath: String, provider: String) throws -> SetMemoryProviderResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        try writeMemoryProvider(workspaceURL: workspaceURL, provider: provider)
        return SetMemoryProviderResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            configPath: configURL(for: workspaceURL).path,
            provider: provider,
            providers: discoverProviders(workspaceURL: workspaceURL, activeProvider: provider)
        )
    }

    func setEnv(workspacePath: String, key: String, value: String) throws -> SetMemoryEnvResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let providers = discoverProviders(workspaceURL: workspaceURL, activeProvider: readActiveProvider(workspaceURL: workspaceURL))
        guard Set(providers.flatMap(\.envVars)).contains(key) else { throw CompanionMemoryRegistryError.invalidEnvironmentKey(key) }
        try writeEnvValue(workspaceURL: workspaceURL, key: key, value: value)
        return SetMemoryEnvResult(workspacePath: workspacePath, resolvedWorkspacePath: workspaceURL.path, envFilePath: envURL(for: workspaceURL).path, key: key, value: value)
    }


    func exportSupermemoryDelta(workspacePath: String) throws -> SupermemoryManagementResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        try ensureSupermemoryActive(workspaceURL: workspaceURL)
        return try runSupermemoryCommand(mode: "export", workspacePath: workspacePath, workspaceURL: workspaceURL)
    }

    func importSupermemoryDelta(workspacePath: String) throws -> SupermemoryManagementResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        try ensureSupermemoryActive(workspaceURL: workspaceURL)
        return try runSupermemoryCommand(mode: "import", workspacePath: workspacePath, workspaceURL: workspaceURL)
    }

    private func ensureSupermemoryActive(workspaceURL: URL) throws {
        guard readActiveProvider(workspaceURL: workspaceURL).lowercased() == "supermemory" else {
            throw CompanionMemoryRegistryError.inactiveSupermemoryProvider
        }
    }

    private func runSupermemoryCommand(mode: String, workspacePath: String, workspaceURL: URL) throws -> SupermemoryManagementResult {
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("hermes-supermemory-management-")
            .appendingPathExtension(UUID().uuidString)
            .appendingPathExtension("py")
        try supermemoryPythonScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let process = Process()
        process.executableURL = pythonExecutable(for: workspaceURL)
        process.arguments = [scriptURL.path, mode, workspaceURL.path]
        process.currentDirectoryURL = workspaceURL
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = workspaceURL.path
        environment["PYTHONUNBUFFERED"] = "1"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CompanionMemoryRegistryError.supermemoryCommandFailed("Unable to run Supermemory helper: \(error.localizedDescription)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let stderr = String(data: errorData, encoding: .utf8) ?? ""
        guard let data = output.data(using: .utf8), !data.isEmpty else {
            throw CompanionMemoryRegistryError.supermemoryCommandFailed(stderr.isEmpty ? "Supermemory helper returned no output." : stderr)
        }
        let result = try JSONDecoder().decode(SupermemoryManagementResult.self, from: data)
        if process.terminationStatus != 0 || result.success == false {
            throw CompanionMemoryRegistryError.supermemoryCommandFailed(result.error ?? stderr)
        }
        return result
    }

    private func pythonExecutable(for workspaceURL: URL) -> URL {
        let candidates = [
            workspaceURL.appendingPathComponent("hermes-agent/venv/bin/python3"),
            workspaceURL.appendingPathComponent("hermes-agent/venv/bin/python"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".hermes/hermes-agent/venv/bin/python3"),
            URL(fileURLWithPath: "/usr/bin/python3")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? URL(fileURLWithPath: "/usr/bin/python3")
    }

    private var supermemoryPythonScript: String {
        #"""
import json, os, re, sys
from datetime import datetime, timezone
from pathlib import Path


def iso_now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')


def parse_iso(value):
    if not value:
        return datetime.fromtimestamp(0, timezone.utc)
    value = str(value).replace('Z', '+00:00')
    try:
        return datetime.fromisoformat(value)
    except Exception:
        return datetime.fromtimestamp(0, timezone.utc)


def load_env(workspace):
    env_path = workspace / '.env'
    if not env_path.exists():
        return
    for raw in env_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def dump_model(obj):
    if hasattr(obj, 'model_dump'):
        return obj.model_dump(mode='json', by_alias=True)
    if hasattr(obj, 'dict'):
        return obj.dict(by_alias=True)
    return obj


def safe_name(value):
    value = re.sub(r'[^A-Za-z0-9._-]+', '-', value or '').strip('-')
    return value[:80] or 'document'


def doc_created_at(doc):
    return doc.get('createdAt') or doc.get('created_at') or ''


def doc_title(doc):
    return doc.get('title') or doc.get('filepath') or doc.get('url') or doc.get('id') or 'Untitled'


def doc_content(doc):
    return doc.get('content') or doc.get('summary') or ''


def state_paths(workspace):
    base = workspace / 'memories' / 'supermemory'
    base.mkdir(parents=True, exist_ok=True)
    return base, base / 'export-state.json'


def load_state(path):
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return {}


def save_state(path, state):
    path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def export_delta(workspace):
    load_env(workspace)
    from supermemory import Supermemory
    base, state_path = state_paths(workspace)
    state = load_state(state_path)
    previous = state.get('last_export_started_at') or ''
    previous_dt = parse_iso(previous)
    started = iso_now()
    export_dir = base / 'exports'
    export_dir.mkdir(parents=True, exist_ok=True)
    export_path = export_dir / f"supermemory-delta-{started.replace(':','').replace('-','')}.jsonl"
    client = Supermemory()
    count = 0
    page = 1
    limit = 100
    with export_path.open('w', encoding='utf-8') as fh:
        while True:
            resp = client.documents.list(include_content=True, page=page, limit=limit, order='asc', sort='createdAt')
            docs = [dump_model(doc) for doc in getattr(resp, 'memories', [])]
            for doc in docs:
                if parse_iso(doc_created_at(doc)) > previous_dt:
                    fh.write(json.dumps(doc, ensure_ascii=False, separators=(',', ':')) + '\n')
                    count += 1
            pagination = getattr(resp, 'pagination', None)
            total_pages = int(getattr(pagination, 'total_pages', None) or getattr(pagination, 'totalPages', None) or page)
            if page >= total_pages:
                break
            page += 1
    state.update({'last_export_started_at': started, 'last_export_path': str(export_path), 'last_export_count': count, 'previous_export_started_at': previous})
    save_state(state_path, state)
    return {
        'workspacePath': str(workspace), 'resolvedWorkspacePath': str(workspace), 'success': True,
        'status': f'Exported {count} Supermemory documents created since {previous or "the beginning"}.',
        'exportedCount': count, 'importedCount': 0, 'exportPath': str(export_path), 'digestPath': '', 'skillReferencePath': '',
        'previousExportStartedAt': previous, 'exportStartedAt': started, 'error': None
    }


def append_memory_entry(workspace, entry):
    memory_path = workspace / 'memories' / 'MEMORY.md'
    memory_path.parent.mkdir(parents=True, exist_ok=True)
    current = memory_path.read_text(encoding='utf-8') if memory_path.exists() else ''
    delimiter = '\n§\n'
    candidate = (current.rstrip() + delimiter + entry).strip() if current.strip() else entry
    if len(candidate) <= 2200:
        memory_path.write_text(candidate + '\n', encoding='utf-8')
        return True
    return False


def import_delta(workspace):
    base, state_path = state_paths(workspace)
    state = load_state(state_path)
    export_path = Path(state.get('last_export_path') or '')
    if not export_path.exists():
        raise RuntimeError('No Supermemory export JSONL exists yet. Run Export first.')
    imported_at = iso_now()
    docs = []
    for raw in export_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        if raw.strip():
            docs.append(json.loads(raw))
    import_dir = base / 'imports'
    import_dir.mkdir(parents=True, exist_ok=True)
    digest_path = import_dir / f"supermemory-delta-{imported_at.replace(':','').replace('-','')}.md"
    lines = [f"# Supermemory delta import {imported_at}", '', f"Source JSONL: `{export_path}`", f"Documents: {len(docs)}", '']
    for i, doc in enumerate(docs, 1):
        lines += [f"## {i}. {doc_title(doc)}", '', f"- ID: `{doc.get('id','')}`", f"- Created: {doc_created_at(doc)}", f"- Updated: {doc.get('updatedAt') or doc.get('updated_at') or ''}", f"- Filepath: {doc.get('filepath') or ''}", f"- Tags: {', '.join(doc.get('containerTags') or doc.get('container_tags') or [])}", '']
        if doc.get('summary'):
            lines += ['Summary:', '', str(doc.get('summary')), '']
        content = doc_content(doc)
        if content:
            lines += ['Content:', '', str(content), '']
    digest_path.write_text('\n'.join(lines).rstrip() + '\n', encoding='utf-8')

    skill_dir = workspace / 'skills' / 'supermemory-imports'
    ref_dir = skill_dir / 'references'
    ref_dir.mkdir(parents=True, exist_ok=True)
    skill_md = skill_dir / 'SKILL.md'
    if not skill_md.exists():
        skill_md.write_text('---\nname: supermemory-imports\ndescription: Imported Supermemory knowledge deltas for Hermes reference.\n---\n\n# Supermemory Imports\n\nThis skill stores references generated by the HermesiOS Supermemory management utility. Load it when imported Supermemory deltas are relevant to the task.\n', encoding='utf-8')
    skill_ref = ref_dir / digest_path.name
    skill_ref.write_text(digest_path.read_text(encoding='utf-8'), encoding='utf-8')

    appended = append_memory_entry(workspace, f"Supermemory delta imported at {imported_at}: {len(docs)} documents. Digest: {digest_path}. Skill reference: {skill_ref}.")
    state.update({'last_import_started_at': imported_at, 'last_import_digest_path': str(digest_path), 'last_import_skill_reference_path': str(skill_ref), 'last_import_count': len(docs), 'last_import_memory_entry_appended': appended})
    save_state(state_path, state)
    return {
        'workspacePath': str(workspace), 'resolvedWorkspacePath': str(workspace), 'success': True,
        'status': f'Imported {len(docs)} Supermemory documents into Hermes memory/skill reference files.' + ('' if appended else ' Memory summary was not appended because MEMORY.md is at capacity.'),
        'exportedCount': 0, 'importedCount': len(docs), 'exportPath': str(export_path), 'digestPath': str(digest_path), 'skillReferencePath': str(skill_ref),
        'previousExportStartedAt': state.get('previous_export_started_at') or '', 'exportStartedAt': state.get('last_export_started_at') or '', 'error': None
    }


def main():
    mode, workspace = sys.argv[1], Path(sys.argv[2]).expanduser().resolve()
    try:
        result = export_delta(workspace) if mode == 'export' else import_delta(workspace)
    except Exception as exc:
        result = {'workspacePath': str(workspace), 'resolvedWorkspacePath': str(workspace), 'success': False, 'status': 'Supermemory operation failed.', 'exportedCount': 0, 'importedCount': 0, 'exportPath': '', 'digestPath': '', 'skillReferencePath': '', 'previousExportStartedAt': '', 'exportStartedAt': '', 'error': str(exc)}
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(1)
    print(json.dumps(result, ensure_ascii=False))

if __name__ == '__main__':
    main()
"""#
    }

    private func operationResult(workspacePath: String, workspaceURL: URL, success: Bool, error: String?) -> MemoryOperationResult {
        MemoryOperationResult(workspacePath: workspacePath, resolvedWorkspacePath: workspaceURL.path, success: success, error: error, memory: try? load(workspacePath: workspaceURL.path))
    }

    private func resolvedWorkspaceURL(from workspacePath: String) throws -> URL {
        let trimmedPath = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedPath = (trimmedPath as NSString).expandingTildeInPath
        let workspaceURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CompanionMemoryRegistryError.invalidWorkspace(workspacePath)
        }
        return workspaceURL
    }

    private func memoryURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("memories/MEMORY.md") }
    private func userURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("memories/USER.md") }
    private func configURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("config.yaml") }
    private func envURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent(".env") }
    private func stateDBURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("state.db") }

    private func readMemoryFile(workspaceURL: URL) -> MemoryFileInfo {
        let file = readFile(memoryURL(for: workspaceURL))
        let entries = parseMemoryEntries(file.content)
        return MemoryFileInfo(content: file.content, exists: file.exists, lastModified: file.lastModified, sizeOnDiskBytes: file.sizeOnDiskBytes, entries: entries, charCount: file.content.count, charLimit: memoryCharLimit)
    }

    private func readUserFile(workspaceURL: URL) -> MemoryFileInfo {
        let file = readFile(userURL(for: workspaceURL))
        return MemoryFileInfo(content: file.content, exists: file.exists, lastModified: file.lastModified, sizeOnDiskBytes: file.sizeOnDiskBytes, entries: nil, charCount: file.content.count, charLimit: userCharLimit)
    }

    private func readFile(_ url: URL) -> (content: String, exists: Bool, lastModified: Int?, sizeOnDiskBytes: Int64?) {
        guard FileManager.default.fileExists(atPath: url.path) else { return ("", false, nil, nil) }
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modified = (attrs?[.modificationDate] as? Date).map { Int($0.timeIntervalSince1970) }
        return (content, true, modified, sizeOnDisk(for: url))
    }

    private func sizeOnDisk(for url: URL) -> Int64? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]) {
            if let allocated = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                return Int64(allocated)
            }
            if let fileSize = values.fileSize {
                return Int64(fileSize)
            }
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs?[.size] as? NSNumber {
            return size.int64Value
        }
        return nil
    }

    private func parseMemoryEntries(_ content: String) -> [MemoryEntry] {
        guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return [] }
        return content.components(separatedBy: entryDelimiter).enumerated().compactMap { index, raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : MemoryEntry(index: index, content: trimmed)
        }
    }

    private func serialize(entries: [MemoryEntry]) -> String { entries.map(\.content).joined(separator: entryDelimiter) }

    private func readStats(workspaceURL: URL) -> MemoryStats {
        let dbPath = stateDBURL(for: workspaceURL).path
        guard FileManager.default.fileExists(atPath: dbPath) else { return MemoryStats(totalSessions: 0, totalMessages: 0) }
        return MemoryStats(totalSessions: sqliteCount(dbPath: dbPath, table: "sessions"), totalMessages: sqliteCount(dbPath: dbPath, table: "messages"))
    }

    private func sqliteCount(dbPath: String, table: String) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [dbPath, "SELECT COUNT(*) FROM \(table);"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return 0 }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return Int(String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
        } catch {
            return 0
        }
    }

    private func discoverProviders(workspaceURL: URL, activeProvider: String) -> [MemoryProviderInfo] {
        let pluginsURL = pluginsDirectory(workspaceURL: workspaceURL)
        var names = Set(Self.knownProviders.keys)
        if let dirs = try? FileManager.default.contentsOfDirectory(at: pluginsURL, includingPropertiesForKeys: nil) {
            for url in dirs where url.lastPathComponent.hasPrefix("_") == false { names.insert(url.lastPathComponent) }
        }
        return names.sorted().map { name in
            let known = Self.knownProviders[name]
            let initURL = pluginsURL.appendingPathComponent(name).appendingPathComponent("__init__.py")
            return MemoryProviderInfo(
                name: name,
                description: known?.description ?? name,
                installed: FileManager.default.fileExists(atPath: initURL.path),
                active: name == activeProvider,
                envVars: known?.envVars ?? []
            )
        }.sorted { lhs, rhs in
            if lhs.active != rhs.active { return lhs.active && !rhs.active }
            if lhs.installed != rhs.installed { return lhs.installed && !rhs.installed }
            return lhs.name < rhs.name
        }
    }

    private func pluginsDirectory(workspaceURL: URL) -> URL {
        let candidates = [
            workspaceURL.appendingPathComponent("hermes-agent/plugins/memory"),
            workspaceURL.deletingLastPathComponent().appendingPathComponent("plugins/memory"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".hermes/hermes-agent/plugins/memory")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? candidates[0]
    }

    private func readActiveProvider(workspaceURL: URL) -> String {
        guard let content = try? String(contentsOf: configURL(for: workspaceURL), encoding: .utf8) else { return "" }
        let lines = content.components(separatedBy: .newlines)
        var inMemory = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
            if line.range(of: #"^memory\s*:"#, options: .regularExpression) != nil { inMemory = true; continue }
            if inMemory && line.range(of: #"^\S"#, options: .regularExpression) != nil { inMemory = false }
            if inMemory, let value = firstMatch(in: line, pattern: #"^\s*provider\s*:\s*[\"']?([^\"'\n#]*)"#) { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return ""
    }

    private func writeMemoryProvider(workspaceURL: URL, provider: String) throws {
        let url = configURL(for: workspaceURL)
        var lines = ((try? String(contentsOf: url, encoding: .utf8)) ?? "").components(separatedBy: "\n")
        var memoryIndex: Int?
        for i in lines.indices where lines[i].range(of: #"^memory\s*:"#, options: .regularExpression) != nil { memoryIndex = i; break }
        if let memoryIndex {
            var insertAt = memoryIndex + 1
            var foundProvider = false
            var i = memoryIndex + 1
            while i < lines.count {
                if lines[i].range(of: #"^\S"#, options: .regularExpression) != nil { break }
                if lines[i].range(of: #"^\s*provider\s*:"#, options: .regularExpression) != nil {
                    lines[i] = "  provider: \"\(provider)\""
                    foundProvider = true
                    break
                }
                insertAt = i + 1
                i += 1
            }
            if !foundProvider { lines.insert("  provider: \"\(provider)\"", at: insertAt) }
        } else {
            if !lines.isEmpty && lines.last != "" { lines.append("") }
            lines.append("memory:")
            lines.append("  provider: \"\(provider)\"")
        }
        try write(lines.joined(separator: "\n"), to: url)
    }

    private func readEnv(workspaceURL: URL, allowedKeys: Set<String>) -> [String: String] {
        guard let content = try? String(contentsOf: envURL(for: workspaceURL), encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") || !trimmed.contains("=") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard allowedKeys.contains(key) else { continue }
            var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) { value = String(value.dropFirst().dropLast()) }
            result[key] = value
        }
        return result
    }

    private func writeEnvValue(workspaceURL: URL, key: String, value: String) throws {
        let url = envURL(for: workspaceURL)
        var lines = (try? String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")) ?? []
        var found = false
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.range(of: #"^#?\s*\#(key)\s*="#, options: .regularExpression) != nil {
                lines[i] = "\(key)=\(value)"
                found = true
                break
            }
        }
        if !found { lines.append("\(key)=\(value)") }
        try write(lines.joined(separator: "\n"), to: url)
    }

    private func firstMatch(in content: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[range])
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
