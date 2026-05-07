
import Foundation

enum CompanionProviderRegistryError: LocalizedError {
    case invalidWorkspace(String)
    case invalidKey(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            return "The Hermes workspace path '\(path)' is invalid."
        case .invalidKey(let key):
            return "The environment key '\(key)' is not allowlisted for provider settings."
        }
    }
}

final class CompanionProviderRegistry {
    private static let providerOptions: [ProviderOption] = [
        .init(value: "auto", label: "Auto-detect"),
        .init(value: "openrouter", label: "OpenRouter"),
        .init(value: "anthropic", label: "Anthropic"),
        .init(value: "openai", label: "OpenAI"),
        .init(value: "google", label: "Google"),
        .init(value: "xai", label: "xAI"),
        .init(value: "nous", label: "Nous"),
        .init(value: "qwen", label: "Qwen"),
        .init(value: "minimax", label: "MiniMax"),
        .init(value: "custom", label: "Local / Custom")
    ]

    private static let auxiliaryModelSlots: [(key: String, label: String)] = [
        ("vision", "Vision"),
        ("compression", "Compression"),
        ("title_generation", "Title Generation"),
        ("mcp", "MCP"),
        ("curator", "Curator"),
        ("skills_hub", "Skills Hub"),
        ("approval", "Approval"),
        ("session_search", "Session Search")
    ]

    private static let sections: [ProviderEnvSection] = [
        .init(id: "llm", title: "LLM Providers", items: [
            .init(key: "OPENROUTER_API_KEY", label: "OpenRouter API Key", type: "password", hint: "Used for OpenRouter models."),
            .init(key: "OPENAI_API_KEY", label: "OpenAI API Key", type: "password", hint: "Used for OpenAI models."),
            .init(key: "ANTHROPIC_API_KEY", label: "Anthropic API Key", type: "password", hint: "Used for Claude models."),
            .init(key: "GROQ_API_KEY", label: "Groq API Key", type: "password", hint: "Used for Groq-hosted OpenAI-compatible models."),
            .init(key: "GLM_API_KEY", label: "GLM API Key", type: "password", hint: "Used for GLM/Zhipu models."),
            .init(key: "KIMI_API_KEY", label: "Kimi API Key", type: "password", hint: "Used for Kimi models."),
            .init(key: "MINIMAX_API_KEY", label: "MiniMax API Key", type: "password", hint: "Used for MiniMax global endpoints."),
            .init(key: "MINIMAX_CN_API_KEY", label: "MiniMax CN API Key", type: "password", hint: "Used for MiniMax China endpoints."),
            .init(key: "OPENCODE_ZEN_API_KEY", label: "OpenCode Zen API Key", type: "password", hint: "Used by OpenCode Zen provider."),
            .init(key: "OPENCODE_GO_API_KEY", label: "OpenCode Go API Key", type: "password", hint: "Used by OpenCode Go provider."),
            .init(key: "HF_TOKEN", label: "Hugging Face Token", type: "password", hint: "Used for Hugging Face model access."),
            .init(key: "DEEPSEEK_API_KEY", label: "DeepSeek API Key", type: "password", hint: "Used for DeepSeek endpoints."),
            .init(key: "TOGETHER_API_KEY", label: "Together API Key", type: "password", hint: "Used for Together AI endpoints."),
            .init(key: "FIREWORKS_API_KEY", label: "Fireworks API Key", type: "password", hint: "Used for Fireworks endpoints."),
            .init(key: "CEREBRAS_API_KEY", label: "Cerebras API Key", type: "password", hint: "Used for Cerebras endpoints."),
            .init(key: "MISTRAL_API_KEY", label: "Mistral API Key", type: "password", hint: "Used for Mistral endpoints."),
            .init(key: "PERPLEXITY_API_KEY", label: "Perplexity API Key", type: "password", hint: "Used for Perplexity endpoints."),
            .init(key: "CUSTOM_API_KEY", label: "Custom API Key", type: "password", hint: "Optional key for custom OpenAI-compatible endpoints."),
            .init(key: "GOOGLE_API_KEY", label: "Google API Key", type: "password", hint: "Used for Gemini models."),
            .init(key: "XAI_API_KEY", label: "xAI API Key", type: "password", hint: "Used for Grok models.")
        ]),
        .init(id: "tools", title: "Tool API Keys", items: [
            .init(key: "EXA_API_KEY", label: "Exa API Key", type: "password", hint: "Used for Exa search."),
            .init(key: "PARALLEL_API_KEY", label: "Parallel API Key", type: "password", hint: "Used for Parallel web/data tools."),
            .init(key: "TAVILY_API_KEY", label: "Tavily API Key", type: "password", hint: "Used for Tavily search."),
            .init(key: "FIRECRAWL_API_KEY", label: "Firecrawl API Key", type: "password", hint: "Used for Firecrawl scraping."),
            .init(key: "FAL_KEY", label: "FAL Key", type: "password", hint: "Used for FAL media generation."),
            .init(key: "HONCHO_API_KEY", label: "Honcho API Key", type: "password", hint: "Used for Honcho memory tools.")
        ]),
        .init(id: "browser", title: "Browser Automation", items: [
            .init(key: "BROWSERBASE_API_KEY", label: "Browserbase API Key", type: "password", hint: "Used for Browserbase sessions."),
            .init(key: "BROWSERBASE_PROJECT_ID", label: "Browserbase Project ID", type: "text", hint: "Project ID for Browserbase.")
        ]),
        .init(id: "voice", title: "Voice & STT", items: [
            .init(key: "VOICE_TOOLS_OPENAI_KEY", label: "Voice Tools OpenAI Key", type: "password", hint: "Used for OpenAI speech features.")
        ]),
        .init(id: "research", title: "Research & Training", items: [
            .init(key: "TINKER_API_KEY", label: "Tinker API Key", type: "password", hint: "Used for Tinker training tools."),
            .init(key: "WANDB_API_KEY", label: "Weights & Biases Key", type: "password", hint: "Used for W&B experiment logging.")
        ])
    ]

    func load(workspacePath: String) throws -> ProvidersConfigResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        return ProvidersConfigResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            envFilePath: envURL(for: workspaceURL).path,
            configPath: configURL(for: workspaceURL).path,
            authFilePath: authURL(for: workspaceURL).path,
            env: readEnv(workspaceURL: workspaceURL),
            modelConfig: readModelConfig(workspaceURL: workspaceURL),
            delegationModelConfig: readDelegationModelConfig(workspaceURL: workspaceURL),
            auxiliaryModelConfigs: readAuxiliaryModelConfigs(workspaceURL: workspaceURL),
            credentialPool: readCredentialPool(workspaceURL: workspaceURL),
            sections: Self.sections,
            providerOptions: Self.providerOptions
        )
    }

    func setEnv(workspacePath: String, key: String, value: String) throws -> SetProviderEnvResult {
        guard Self.sections.flatMap({ $0.items }).contains(where: { $0.key == key }) else { throw CompanionProviderRegistryError.invalidKey(key) }
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        try writeEnvValue(workspaceURL: workspaceURL, key: key, value: value)
        return SetProviderEnvResult(workspacePath: workspacePath, resolvedWorkspacePath: workspaceURL.path, key: key, value: value, envFilePath: envURL(for: workspaceURL).path)
    }

    func setModelConfig(workspacePath: String, provider: String, model: String, baseUrl: String) throws -> SetProviderModelConfigResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        try writeModelConfig(workspaceURL: workspaceURL, provider: provider, model: model, baseUrl: baseUrl)
        return SetProviderModelConfigResult(workspacePath: workspacePath, resolvedWorkspacePath: workspaceURL.path, configPath: configURL(for: workspaceURL).path, modelConfig: ProviderModelConfig(provider: provider, model: model, baseUrl: baseUrl))
    }

    func setRuntimeModelSlot(workspacePath: String, section: String, key: String, provider: String, model: String) throws -> SetRuntimeModelSlotResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let slot = try writeRuntimeModelSlot(workspaceURL: workspaceURL, section: section, key: key, provider: provider, model: model)
        return SetRuntimeModelSlotResult(workspacePath: workspacePath, resolvedWorkspacePath: workspaceURL.path, configPath: configURL(for: workspaceURL).path, slot: slot)
    }

    func setCredentialPool(workspacePath: String, provider: String, entries: [ProviderCredentialEntry]) throws -> SetCredentialPoolResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        var pool = readCredentialPool(workspaceURL: workspaceURL)
        pool[provider] = entries
        try writeCredentialPool(workspaceURL: workspaceURL, pool: pool)
        return SetCredentialPoolResult(workspacePath: workspacePath, resolvedWorkspacePath: workspaceURL.path, authFilePath: authURL(for: workspaceURL).path, credentialPool: pool)
    }

    private func resolvedWorkspaceURL(from workspacePath: String) throws -> URL {
        let trimmedPath = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedPath = (trimmedPath as NSString).expandingTildeInPath
        let workspaceURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CompanionProviderRegistryError.invalidWorkspace(workspacePath)
        }
        return workspaceURL
    }

    private func envURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent(".env") }
    private func configURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("config.yaml") }
    private func authURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("auth.json") }

    private func readEnv(workspaceURL: URL) -> [String: String] {
        guard let content = try? String(contentsOf: envURL(for: workspaceURL), encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") || !trimmed.contains("=") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) { value = String(value.dropFirst().dropLast()) }
            if !value.isEmpty { result[key] = value }
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

    private func readModelConfig(workspaceURL: URL) -> ProviderModelConfig {
        let content = (try? String(contentsOf: configURL(for: workspaceURL), encoding: .utf8)) ?? ""
        return ProviderModelConfig(
            provider: readYAMLScalar(content: content, section: "model", key: "provider") ?? readTopLevelYAMLScalar(content: content, key: "provider") ?? "auto",
            model: readYAMLScalar(content: content, section: "model", key: "default") ?? readTopLevelYAMLScalar(content: content, key: "default") ?? "",
            baseUrl: readYAMLScalar(content: content, section: "model", key: "base_url") ?? readTopLevelYAMLScalar(content: content, key: "base_url") ?? ""
        )
    }

    private func readDelegationModelConfig(workspaceURL: URL) -> RuntimeModelSlotConfig {
        let content = (try? String(contentsOf: configURL(for: workspaceURL), encoding: .utf8)) ?? ""
        return RuntimeModelSlotConfig(
            id: "delegation",
            label: "Delegation",
            section: "delegation",
            key: "delegation",
            provider: readYAMLScalar(content: content, section: "delegation", key: "provider") ?? "",
            model: readYAMLScalar(content: content, section: "delegation", key: "model") ?? ""
        )
    }

    private func readAuxiliaryModelConfigs(workspaceURL: URL) -> [RuntimeModelSlotConfig] {
        let content = (try? String(contentsOf: configURL(for: workspaceURL), encoding: .utf8)) ?? ""
        return Self.auxiliaryModelSlots.map { slot in
            RuntimeModelSlotConfig(
                id: "auxiliary.\(slot.key)",
                label: slot.label,
                section: "auxiliary",
                key: slot.key,
                provider: readYAMLScalar(content: content, section: "auxiliary", child: slot.key, key: "provider") ?? "",
                model: readYAMLScalar(content: content, section: "auxiliary", child: slot.key, key: "model") ?? ""
            )
        }
    }

    private func writeModelConfig(workspaceURL: URL, provider: String, model: String, baseUrl: String) throws {
        let url = configURL(for: workspaceURL)
        var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        content = setYAMLScalar(content: content, section: "model", key: "provider", value: provider)
        content = setYAMLScalar(content: content, section: "model", key: "default", value: model)
        content = setYAMLScalar(content: content, section: "model", key: "base_url", value: baseUrl)
        content = setYAMLScalar(content: content, section: "model", key: "streaming", rawValue: "true")
        try write(content, to: url)
    }

    private func writeRuntimeModelSlot(workspaceURL: URL, section: String, key: String, provider: String, model: String) throws -> RuntimeModelSlotConfig {
        let url = configURL(for: workspaceURL)
        var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let slot: RuntimeModelSlotConfig
        if section == "delegation" {
            content = setYAMLScalar(content: content, section: "delegation", key: "provider", value: provider)
            content = setYAMLScalar(content: content, section: "delegation", key: "model", value: model)
            slot = RuntimeModelSlotConfig(id: "delegation", label: "Delegation", section: "delegation", key: "delegation", provider: provider, model: model)
        } else {
            let label = Self.auxiliaryModelSlots.first(where: { $0.key == key })?.label ?? key
            content = setYAMLScalar(content: content, section: "auxiliary", child: key, key: "provider", value: provider)
            content = setYAMLScalar(content: content, section: "auxiliary", child: key, key: "model", value: model)
            slot = RuntimeModelSlotConfig(id: "auxiliary.\(key)", label: label, section: "auxiliary", key: key, provider: provider, model: model)
        }
        try write(content, to: url)
        return slot
    }

    private func readTopLevelYAMLScalar(content: String, key: String) -> String? {
        firstMatch(in: content, pattern: #"^\#(key):\s*[\"']?([^\"'\n#]+)[\"']?"#)
    }

    private func readYAMLScalar(content: String, section: String, child: String? = nil, key: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^\#(section):\s*(#.*)?$"#, options: .regularExpression) != nil }) else { return nil }
        let sectionIndent = indentation(of: lines[sectionIndex])
        var index = sectionIndex + 1
        if let child {
            var childIndex: Int?
            while index < lines.count {
                let line = lines[index]
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
                if indentation(of: line) == sectionIndent + 2 && line.trimmingCharacters(in: .whitespaces).range(of: #"^\#(child):\s*(#.*)?$"#, options: .regularExpression) != nil {
                    childIndex = index
                    break
                }
                index += 1
            }
            guard let childIndex else { return nil }
            let childIndent = indentation(of: lines[childIndex])
            index = childIndex + 1
            while index < lines.count {
                let line = lines[index]
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= childIndent { break }
                if indentation(of: line) == childIndent + 2, let value = scalarValue(from: line, key: key) { return value }
                index += 1
            }
            return nil
        }
        while index < lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
            if indentation(of: line) == sectionIndent + 2, let value = scalarValue(from: line, key: key) { return value }
            index += 1
        }
        return nil
    }

    private func setYAMLScalar(content: String, section: String, child: String? = nil, key: String, value: String? = nil, rawValue: String? = nil) -> String {
        var lines = content.components(separatedBy: "\n")
        if lines == [""] { lines = [] }
        let replacementValue = rawValue ?? quotedYAML(value ?? "")
        let sectionLine = "\(section):"
        let keyLine = "  \(key): \(replacementValue)"
        let childLine = child.map { "  \($0):" }
        let childKeyLine = child.map { _ in "    \(key): \(replacementValue)" }

        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^\#(section):\s*(#.*)?$"#, options: .regularExpression) != nil }) else {
            lines.append(sectionLine)
            if let childLine, let childKeyLine {
                lines.append(childLine)
                lines.append(childKeyLine)
            } else {
                lines.append(keyLine)
            }
            return lines.joined(separator: "\n") + "\n"
        }

        let sectionIndent = indentation(of: lines[sectionIndex])
        if let child, let childLine, let childKeyLine {
            var index = sectionIndex + 1
            var insertAt = index
            while index < lines.count {
                let line = lines[index]
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
                insertAt = index + 1
                if indentation(of: line) == sectionIndent + 2 && line.trimmingCharacters(in: .whitespaces).range(of: #"^\#(child):\s*(#.*)?$"#, options: .regularExpression) != nil {
                    let childIndent = indentation(of: line)
                    var childScan = index + 1
                    var childInsertAt = childScan
                    while childScan < lines.count {
                        let childScanLine = lines[childScan]
                        if !childScanLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: childScanLine) <= childIndent { break }
                        childInsertAt = childScan + 1
                        if indentation(of: childScanLine) == childIndent + 2 && scalarValue(from: childScanLine, key: key) != nil {
                            lines[childScan] = childKeyLine
                            return lines.joined(separator: "\n")
                        }
                        childScan += 1
                    }
                    lines.insert(childKeyLine, at: childInsertAt)
                    return lines.joined(separator: "\n")
                }
                index += 1
            }
            lines.insert(contentsOf: [childLine, childKeyLine], at: insertAt)
            return lines.joined(separator: "\n")
        }

        var index = sectionIndex + 1
        var insertAt = index
        while index < lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
            insertAt = index + 1
            if indentation(of: line) == sectionIndent + 2 && scalarValue(from: line, key: key) != nil {
                lines[index] = keyLine
                return lines.joined(separator: "\n")
            }
            index += 1
        }
        lines.insert(keyLine, at: insertAt)
        return lines.joined(separator: "\n")
    }

    private func scalarValue(from line: String, key: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*\#(key):\s*[\"']?([^\"'\n#]*)[\"']?"#),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private func quotedYAML(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func readCredentialPool(workspaceURL: URL) -> [String: [ProviderCredentialEntry]] {
        guard let data = try? Data(contentsOf: authURL(for: workspaceURL)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pool = object["credential_pool"] as? [String: [[String: Any]]] else { return [:] }
        var result: [String: [ProviderCredentialEntry]] = [:]
        for (provider, entries) in pool {
            result[provider] = entries.map { ProviderCredentialEntry(key: $0["key"] as? String ?? "", label: $0["label"] as? String ?? "") }
        }
        return result
    }

    private func writeCredentialPool(workspaceURL: URL, pool: [String: [ProviderCredentialEntry]]) throws {
        let url = authURL(for: workspaceURL)
        var object = ((try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) ?? [:]
        object["credential_pool"] = pool.mapValues { entries in entries.map { ["key": $0.key, "label": $0.label] } }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }

    private func firstMatch(in content: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
