//
//  HermesMemoryPanel.swift
//  HermesiOS
//

import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum HermesMemoryTab: String, CaseIterable, Identifiable {
    case entries = "Agent Memory"
    case profile = "User Profile"
    case providers = "Providers"

    var id: String { rawValue }
}

struct HermesMemoryPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var selectedTab: HermesMemoryTab = .entries
    @State private var showAddEntry = false
    @State private var newEntry = ""
    @State private var editingIndex: Int?
    @State private var editContent = ""
    @State private var confirmDeleteIndex: Int?
    @State private var userDraft = ""
    @State private var userSaved = false
    @State private var savedEnvKey: String?
    @State private var visibleKeys: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Authentication Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to authenticate this iOS device before editing Hermes memory files and provider configuration on the macOS host.")
                )
            } else {
                HermesSectionCard("Memory Overview") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Mirrors the desktop Memory screen: reads and writes `memories/MEMORY.md`, `memories/USER.md`, memory provider config, and memory provider env keys through HermesHostCompanion.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        HermesStatusRow(
                            items: [
                                .init(title: "Sessions", value: "\(companionRuntime.memoryConfig?.stats.totalSessions ?? 0)", accent: .igActionBlue),
                                .init(title: "Messages", value: "\(companionRuntime.memoryConfig?.stats.totalMessages ?? 0)", accent: .igGradPurple),
                                .init(title: "Memories", value: "\(companionRuntime.memoryEntries.count)", accent: .igOnlineGreen)
                            ]
                        )

                        memoryCapacityBar(label: "Agent Memory", used: companionRuntime.memoryConfig?.memory.charCount ?? 0, limit: companionRuntime.memoryConfig?.memory.charLimit ?? 2_200)
                        memoryCapacityBar(label: "User Profile", used: companionRuntime.memoryConfig?.user.charCount ?? 0, limit: companionRuntime.memoryConfig?.user.charLimit ?? 1_375)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        memoryFileSummaryRow(label: "Memory File", value: companionRuntime.memoryFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/memories/MEMORY.md" : companionRuntime.memoryFilePath, sizeOnDiskBytes: companionRuntime.memoryConfig?.memory.sizeOnDiskBytes)
                        memoryFileSummaryRow(label: "User File", value: companionRuntime.memoryUserFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/memories/USER.md" : companionRuntime.memoryUserFilePath, sizeOnDiskBytes: companionRuntime.memoryConfig?.user.sizeOnDiskBytes)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        Button("Refresh Memory") {
                            companionRuntime.refreshMemoryConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Picker("Memory tab", selection: $selectedTab) {
                    ForEach(HermesMemoryTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .entries:
                    memoryEntriesSection
                case .profile:
                    userProfileSection
                case .providers:
                    memoryProvidersSection
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshMemoryConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshMemoryConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .onChange(of: companionRuntime.memoryUserContent) { _, newValue in
            userDraft = newValue
        }
        .onAppear {
            userDraft = companionRuntime.memoryUserContent
        }
    }

    private var memoryEntriesSection: some View {
        HermesSectionCard("Agent Memory") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(companionRuntime.memoryEntries.count) entries")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(showAddEntry ? "Cancel" : "Add Memory") {
                        showAddEntry.toggle()
                        if showAddEntry == false { newEntry = "" }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if showAddEntry {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: $newEntry)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 92)
                            .padding(8)
                            .background(Color.hermesSurfaceInput)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        HStack {
                            Text("\(newEntry.count) chars")
                                .font(.caption)
                                .foregroundStyle(.hermesSecondaryText)
                            Spacer()
                            Button("Save") {
                                let trimmed = newEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard trimmed.isEmpty == false else { return }
                                companionRuntime.addMemoryEntry(content: trimmed, settings: companionSettings, identityState: companionEnrollment.identityState)
                                newEntry = ""
                                showAddEntry = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(12)
                    .background(Color.hermesSurfaceInput.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if companionRuntime.memoryEntries.isEmpty {
                    ContentUnavailableView(
                        "No Memories Yet",
                        systemImage: "brain",
                        description: Text("Add stable facts or workflow notes that Hermes should keep across sessions.")
                    )
                } else {
                    ForEach(companionRuntime.memoryEntries) { entry in
                        memoryEntryRow(entry)
                    }
                }
            }
        }
    }

    private var userProfileSection: some View {
        HermesSectionCard("User Profile") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit the user-level profile exactly as desktop Memory writes `USER.md`.")
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)

                TextEditor(text: $userDraft)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(Color.hermesSurfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack {
                    Text("\(userDraft.count) / \(companionRuntime.memoryConfig?.user.charLimit ?? 1_375) chars")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                    Spacer()
                    if userSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.igOnlineGreen)
                    }
                    Button("Save Profile") {
                        companionRuntime.writeUserProfile(content: userDraft, settings: companionSettings, identityState: companionEnrollment.identityState)
                        userSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { userSaved = false }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userDraft.count > (companionRuntime.memoryConfig?.user.charLimit ?? 1_375))
                }
            }
        }
    }

    private var memoryProvidersSection: some View {
        HermesSectionCard("Memory Providers") {
            VStack(alignment: .leading, spacing: 14) {
                Text(companionRuntime.memoryProvider.isEmpty ? "No external memory provider is active. Hermes will use local memory files." : "Active provider: \(companionRuntime.memoryProvider)")
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)

                memoryFileSummaryRow(label: "Config", value: companionRuntime.memoryConfigPath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/config.yaml" : companionRuntime.memoryConfigPath, sizeOnDiskBytes: companionRuntime.memoryConfig?.configSizeOnDiskBytes)
                memoryFileSummaryRow(label: "Env File", value: companionRuntime.memoryEnvFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/.env" : companionRuntime.memoryEnvFilePath, sizeOnDiskBytes: companionRuntime.memoryConfig?.envSizeOnDiskBytes)

                if companionRuntime.memoryProviders.isEmpty {
                    Text("Refresh memory to discover memory providers from the host Hermes installation.")
                        .font(.subheadline)
                        .foregroundStyle(.hermesSecondaryText)
                } else {
                    ForEach(companionRuntime.memoryProviders) { provider in
                        memoryProviderCard(provider)
                    }
                }
            }
        }
    }

    private func memoryEntryRow(_ entry: HermesCompanionMemoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if editingIndex == entry.index {
                TextEditor(text: $editContent)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 92)
                    .padding(8)
                    .background(Color.hermesSurfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack {
                    Text("\(editContent.count) chars")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                    Spacer()
                    Button("Cancel") {
                        editingIndex = nil
                        editContent = ""
                    }
                    .buttonStyle(.bordered)
                    Button("Save") {
                        companionRuntime.updateMemoryEntry(index: entry.index, content: editContent.trimmingCharacters(in: .whitespacesAndNewlines), settings: companionSettings, identityState: companionEnrollment.identityState)
                        editingIndex = nil
                        editContent = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text(entry.content)
                    .font(.subheadline)
                    .textSelection(.enabled)
                HStack {
                    Button("Edit") {
                        editingIndex = entry.index
                        editContent = entry.content
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if confirmDeleteIndex == entry.index {
                        Button("Cancel") { confirmDeleteIndex = nil }
                            .buttonStyle(.bordered)
                        Button("Delete", role: .destructive) {
                            companionRuntime.removeMemoryEntry(index: entry.index, settings: companionSettings, identityState: companionEnrollment.identityState)
                            confirmDeleteIndex = nil
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(role: .destructive) { confirmDeleteIndex = entry.index } label: { Image(systemName: "trash") }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func memoryProviderCard(_ provider: HermesCompanionMemoryProviderInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(provider.name)
                            .font(.headline)
                        if provider.active {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.igOnlineGreen)
                        }
                        if provider.installed == false {
                            Text("Not installed")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.hermesSecondaryText)
                        }
                    }
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }
                Spacer()
                if provider.active {
                    Button("Deactivate") {
                        companionRuntime.setMemoryProvider("", settings: companionSettings, identityState: companionEnrollment.identityState)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Activate") {
                        companionRuntime.setMemoryProvider(provider.name, settings: companionSettings, identityState: companionEnrollment.identityState)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if provider.envVars.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(provider.envVars, id: \.self) { key in
                        memoryEnvField(key)
                    }
                }
            }
        }
        .padding(14)
        .background(provider.active ? Color.igActionBlue.opacity(0.10) : Color.hermesSurfaceInput)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(provider.active ? Color.igActionBlue.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func memoryEnvField(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                if savedEnvKey == key {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.igOnlineGreen)
                }
            }
            HStack(spacing: 8) {
                let binding = Binding<String>(
                    get: { companionRuntime.memoryEnv[key] ?? "" },
                    set: { companionRuntime.memoryEnv[key] = $0 }
                )
                if key.localizedCaseInsensitiveContains("KEY") && visibleKeys.contains(key) == false {
                    SecureField(key, text: binding)
                        .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField(key, text: binding)
                        .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if key.localizedCaseInsensitiveContains("KEY") {
                    Button(visibleKeys.contains(key) ? "Hide" : "Show") {
                        if visibleKeys.contains(key) { visibleKeys.remove(key) } else { visibleKeys.insert(key) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            Button("Save \(key)") {
                companionRuntime.setMemoryEnvValue(key: key, value: companionRuntime.memoryEnv[key] ?? "", settings: companionSettings, identityState: companionEnrollment.identityState)
                savedEnvKey = key
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedEnvKey = nil }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.hermesCanvas.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func memoryCapacityBar(label: String, used: Int, limit: Int) -> some View {
        let percentage = limit > 0 ? min(1.0, Double(used) / Double(limit)) : 0
        let tint: Color = percentage > 0.9 ? .igDestructive : (percentage > 0.7 ? .igGradOrange : .igOnlineGreen)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                Spacer()
                Text("\(used) / \(limit) chars")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.hermesSecondaryText)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.hermesSurfaceInput)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * percentage)
                    }
            }
            .frame(height: 8)
        }
    }

    private func memoryFileSummaryRow(label: String, value: String, sizeOnDiskBytes: Int64?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(value)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.hermesSecondaryText)
                    .textSelection(.enabled)
                Text("Size on disk: \(formattedDiskSize(sizeOnDiskBytes))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.hermesSecondaryText)
            }
        }
        .font(.subheadline)
    }

    private func formattedDiskSize(_ byteCount: Int64?) -> String {
        guard let byteCount else { return "not found" }
        return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    private func companionSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}
