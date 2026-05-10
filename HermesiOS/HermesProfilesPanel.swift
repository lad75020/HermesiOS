//
//  HermesProfilesPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI

private struct HermesProfileFormDraft: Equatable {
    var name = ""
    var provider = ""
    var model = ""
    var baseUrl = ""
    var createEnv = false
    var createSoul = false
    var cloneSkills = false
}

struct HermesProfilesPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var showCreateForm = false
    @State private var createDraft = HermesProfileFormDraft()
    @State private var editingProfileName: String?
    @State private var editDraft = HermesProfileFormDraft()
    @State private var confirmDeleteProfileName: String?

    private var namedProfileCount: Int {
        companionRuntime.profiles.filter { !$0.isDefault }.count
    }

    private var defaultProfile: HermesCompanionProfileInfo? {
        companionRuntime.profiles.first(where: { $0.isDefault })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Authentication Required",
                    systemImage: "person.badge.key",
                    description: Text("Authenticate with HermesHostCompanion before managing Hermes runtime profiles on the macOS host.")
                )
            } else {
                HermesStatusRow(items: [
                    .init(title: "Profiles", value: "\(companionRuntime.profiles.count)", accent: .igActionBlue),
                    .init(title: "Named", value: "\(namedProfileCount)", accent: .igOnlineGreen),
                    .init(title: "Active", value: companionRuntime.activeProfileName, accent: .igGradOrange)
                ])

                if !companionRuntime.lastErrorMessage.isEmpty {
                    Text(companionRuntime.lastErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.igDestructive)
                }

                HermesSectionCard("Profile Controls") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profiles are read from the Hermes workspace and its profiles/ folder. Create and edit profile model settings from the default profile values, then refresh from the macOS host whenever the filesystem changes.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        if !companionRuntime.profilesDirectoryPath.isEmpty {
                            Text(companionRuntime.profilesDirectoryPath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.hermesSecondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        HStack {
                            Button {
                                companionRuntime.refreshProfiles(settings: companionSettings, identityState: companionEnrollment.identityState)
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .hermesGlassProminentButton()
                            .disabled(companionRuntime.isBusy)

                            Button {
                                createDraft = draftFromDefault()
                                editingProfileName = nil
                                showCreateForm.toggle()
                            } label: {
                                Label(showCreateForm ? "Hide Form" : "Create", systemImage: showCreateForm ? "xmark" : "plus")
                            }
                            .hermesGlassButton()
                            .disabled(companionRuntime.isBusy)
                        }
                    }
                }

                if showCreateForm {
                    HermesSectionCard("Create Profile") {
                        profileForm(
                            draft: $createDraft,
                            mode: .create,
                            originalName: nil,
                            submitTitle: "Create",
                            submitIcon: "plus.circle.fill"
                        )
                    }
                }

                if let editingProfileName {
                    HermesSectionCard("Edit Profile") {
                        profileForm(
                            draft: $editDraft,
                            mode: .edit(isDefault: editingProfileName == "default"),
                            originalName: editingProfileName,
                            submitTitle: "Save",
                            submitIcon: "square.and.pencil"
                        )
                    }
                }

                HermesSectionCard("Runtime Profiles") {
                    if companionRuntime.profiles.isEmpty {
                        ContentUnavailableView(
                            "No Profiles Loaded",
                            systemImage: "person.crop.rectangle.stack",
                            description: Text("Refresh from the macOS host to list the default profile and every named directory under the Hermes profiles folder.")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(companionRuntime.profiles) { profile in
                                profileCard(profile)
                            }
                        }
                    }
                }

                if !companionRuntime.profileOperationOutput.isEmpty {
                    HermesSectionCard("Last Profile Command") {
                        Text(companionRuntime.profileOperationOutput)
                            .font(.caption.monospaced())
                            .foregroundStyle(.hermesSecondaryText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .onAppear {
            if companionEnrollment.identityState.isEnrolled {
                companionRuntime.refreshProfiles(settings: companionSettings, identityState: companionEnrollment.identityState)
            }
        }
        .confirmationDialog(
            "Delete profile?",
            isPresented: Binding(
                get: { confirmDeleteProfileName != nil },
                set: { isPresented in if !isPresented { confirmDeleteProfileName = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let profileName = confirmDeleteProfileName {
                Button("Delete \(profileName)", role: .destructive) {
                    companionRuntime.deleteProfile(name: profileName, settings: companionSettings, identityState: companionEnrollment.identityState)
                    confirmDeleteProfileName = nil
                }
            }
            Button("Cancel", role: .cancel) { confirmDeleteProfileName = nil }
        }
    }

    private enum FormMode: Equatable {
        case create
        case edit(isDefault: Bool)

        var isEditingDefault: Bool {
            if case .edit(let isDefault) = self { return isDefault }
            return false
        }
    }

    private func profileForm(draft: Binding<HermesProfileFormDraft>, mode: FormMode, originalName: String?, submitTitle: String, submitIcon: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Profile name", text: draft.name)
                .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(mode.isEditingDefault)

            HStack(spacing: 10) {
                TextField("Provider", text: draft.provider)
                    .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.22))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Model", text: draft.model)
                    .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.22))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            TextField("Base URL (optional)", text: draft.baseUrl)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.06), border: Color.igActionBlue.opacity(0.18))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack(spacing: 16) {
                Toggle(".env file", isOn: draft.createEnv)
                    .tint(.igActionBlue)
                Toggle("SOUL.md", isOn: draft.createSoul)
                    .tint(.igActionBlue)
            }

            if case .create = mode {
                Toggle("Clone default skills folder", isOn: draft.cloneSkills)
                    .tint(.igActionBlue)
            }

            Text("The form is seeded from the default profile. Creating a profile copies the default config as a template, writes the provider/model/base URL fields, and optionally creates or copies .env, SOUL.md, and the default skills folder. Editing uses the same persistent fields; the default profile name cannot be changed.")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            HStack {
                Button {
                    let trimmed = normalized(draft.wrappedValue)
                    switch mode {
                    case .create:
                        companionRuntime.createProfile(
                            name: trimmed.name,
                            provider: trimmed.provider,
                            model: trimmed.model,
                            baseUrl: trimmed.baseUrl,
                            createEnv: trimmed.createEnv,
                            createSoul: trimmed.createSoul,
                            cloneSkills: trimmed.cloneSkills,
                            settings: companionSettings,
                            identityState: companionEnrollment.identityState
                        )
                        createDraft = draftFromDefault()
                        showCreateForm = false
                    case .edit:
                        companionRuntime.editProfile(
                            originalName: originalName ?? trimmed.name,
                            name: trimmed.name,
                            provider: trimmed.provider,
                            model: trimmed.model,
                            baseUrl: trimmed.baseUrl,
                            createEnv: trimmed.createEnv,
                            createSoul: trimmed.createSoul,
                            settings: companionSettings,
                            identityState: companionEnrollment.identityState
                        )
                        editingProfileName = nil
                    }
                } label: {
                    Label(submitTitle, systemImage: submitIcon)
                }
                .hermesGlassProminentButton()
                .disabled(draft.wrappedValue.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || companionRuntime.isBusy)

                Button("Reset") {
                    switch mode {
                    case .create:
                        createDraft = draftFromDefault()
                    case .edit:
                        if let originalName, let profile = companionRuntime.profiles.first(where: { $0.name == originalName }) {
                            editDraft = draftForProfile(profile)
                        }
                    }
                }
                .hermesGlassButton()

                Button("Cancel") {
                    switch mode {
                    case .create:
                        showCreateForm = false
                    case .edit:
                        editingProfileName = nil
                    }
                }
                .hermesGlassButton()
            }
        }
    }

    private func normalized(_ draft: HermesProfileFormDraft) -> HermesProfileFormDraft {
        HermesProfileFormDraft(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            provider: draft.provider.trimmingCharacters(in: .whitespacesAndNewlines),
            model: draft.model.trimmingCharacters(in: .whitespacesAndNewlines),
            baseUrl: draft.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines),
            createEnv: draft.createEnv,
            createSoul: draft.createSoul,
            cloneSkills: draft.cloneSkills
        )
    }

    private func draftFromDefault() -> HermesProfileFormDraft {
        guard let defaultProfile else { return HermesProfileFormDraft(provider: "auto") }
        var draft = draftForProfile(defaultProfile)
        draft.name = ""
        draft.cloneSkills = defaultProfile.skillCount > 0
        return draft
    }

    private func draftForProfile(_ profile: HermesCompanionProfileInfo) -> HermesProfileFormDraft {
        HermesProfileFormDraft(
            name: profile.name,
            provider: profile.provider.isEmpty ? "auto" : profile.provider,
            model: profile.model,
            baseUrl: profile.baseUrl,
            createEnv: profile.hasEnv,
            createSoul: profile.hasSoul,
            cloneSkills: false
        )
    }

    private func profileCard(_ profile: HermesCompanionProfileInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if profile.isDefault {
                            profileBadge("Default", color: .igActionBlue)
                        }
                        if profile.isActive {
                            profileBadge("Active", color: .igOnlineGreen)
                        }
                        if profile.gatewayRunning {
                            profileBadge("Gateway", color: .igGradOrange)
                        }
                    }
                    Text(profile.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.hermesSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()
                Image(systemName: profile.isActive ? "checkmark.seal.fill" : "person.crop.rectangle")
                    .font(.title3)
                    .foregroundStyle(profile.isActive ? Color.igOnlineGreen : Color.hermesSecondaryText)
            }

            HStack(spacing: 8) {
                profileMetric("Provider", profile.provider.isEmpty ? "—" : profile.provider)
                profileMetric("Model", profile.model.isEmpty ? "—" : profile.model)
                profileMetric("Base URL", profile.baseUrl.isEmpty ? "—" : profile.baseUrl)
                profileMetric("Skills", "\(profile.skillCount)")
            }

            HStack(spacing: 8) {
                profileFlag("config.yaml", enabled: profile.hasConfig)
                profileFlag(".env", enabled: profile.hasEnv)
                profileFlag("SOUL.md", enabled: profile.hasSoul)
                Spacer()
                Button {
                    editDraft = draftForProfile(profile)
                    editingProfileName = profile.name
                    showCreateForm = false
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .hermesGlassButton()
                .disabled(companionRuntime.isBusy)

                if !profile.isActive {
                    Button {
                        companionRuntime.setActiveProfile(name: profile.name, settings: companionSettings, identityState: companionEnrollment.identityState)
                    } label: {
                        Label("Use", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .hermesGlassButton()
                    .disabled(companionRuntime.isBusy)
                }
                if !profile.isDefault {
                    Button(role: .destructive) {
                        confirmDeleteProfileName = profile.name
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .hermesGlassButton()
                    .disabled(companionRuntime.isBusy)
                }
            }
        }
        .padding(14)
        .hermesLiquidGlass(cornerRadius: 18, tint: profile.isActive ? Color.igOnlineGreen.opacity(0.08) : Color.white.opacity(0.05), interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(profile.isActive ? Color.igOnlineGreen.opacity(0.28) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func profileMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.hermesSecondaryText)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .hermesLiquidGlass(cornerRadius: 12, tint: Color.igActionBlue.opacity(0.06), interactive: false)
    }

    private func profileBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .hermesLiquidGlass(cornerRadius: 10, tint: color.opacity(0.08), interactive: false)
    }

    private func profileFlag(_ label: String, enabled: Bool) -> some View {
        Label(label, systemImage: enabled ? "checkmark.circle.fill" : "minus.circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(enabled ? Color.igOnlineGreen : Color.hermesSecondaryText)
    }
}
