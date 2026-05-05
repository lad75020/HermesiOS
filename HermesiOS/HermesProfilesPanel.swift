//
//  HermesProfilesPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesProfilesPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var showCreateForm = false
    @State private var newProfileName = ""
    @State private var cloneCurrentProfile = true
    @State private var confirmDeleteProfileName: String?

    private var namedProfileCount: Int {
        companionRuntime.profiles.filter { !$0.isDefault }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Enroll this iOS device with HermesHostCompanion before managing Hermes runtime profiles on the macOS host.")
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
                        Text("Profiles mirror the desktop Hermes profile manager: list the default workspace, create named profiles, clone the current setup, switch the active profile, and delete named profiles.")
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
                            .buttonStyle(.borderedProminent)
                            .disabled(companionRuntime.isBusy)

                            Button {
                                showCreateForm.toggle()
                            } label: {
                                Label(showCreateForm ? "Hide Form" : "New Profile", systemImage: showCreateForm ? "xmark" : "plus")
                            }
                            .buttonStyle(.bordered)
                            .disabled(companionRuntime.isBusy)
                        }
                    }
                }

                if showCreateForm {
                    HermesSectionCard("New Profile") {
                        createForm
                    }
                }

                HermesSectionCard("Runtime Profiles") {
                    if companionRuntime.profiles.isEmpty {
                        ContentUnavailableView(
                            "No Profiles Loaded",
                            systemImage: "person.crop.rectangle.stack",
                            description: Text("Refresh from the macOS host to list the default profile and any named profiles under the Hermes workspace.")
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
            if companionEnrollment.identityState.isEnrolled, companionRuntime.profiles.isEmpty {
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

    private var createForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Profile name", text: $newProfileName)
                .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Toggle("Clone current/default profile", isOn: $cloneCurrentProfile)
                .tint(.igActionBlue)

            Text("Use letters, numbers, dots, dashes, or underscores. Cloning copies the current profile's config, env, soul, and skills just like `hermes profile create --clone`.")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            HStack {
                Button {
                    let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    companionRuntime.createProfile(name: name, clone: cloneCurrentProfile, settings: companionSettings, identityState: companionEnrollment.identityState)
                    newProfileName = ""
                    cloneCurrentProfile = true
                    showCreateForm = false
                } label: {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || companionRuntime.isBusy)

                Button("Reset") {
                    newProfileName = ""
                    cloneCurrentProfile = true
                }
                .buttonStyle(.bordered)
            }
        }
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
                profileMetric("Skills", "\(profile.skillCount)")
            }

            HStack(spacing: 8) {
                profileFlag(".env", enabled: profile.hasEnv)
                profileFlag("SOUL.md", enabled: profile.hasSoul)
                Spacer()
                if !profile.isActive {
                    Button {
                        companionRuntime.setActiveProfile(name: profile.name, settings: companionSettings, identityState: companionEnrollment.identityState)
                    } label: {
                        Label("Use", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .disabled(companionRuntime.isBusy)
                }
                if !profile.isDefault {
                    Button(role: .destructive) {
                        confirmDeleteProfileName = profile.name
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
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
