//
//  HermesModelsPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesModelsPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @State private var newModelName = ""
    @State private var newModelProvider = ""
    @State private var newModelID = ""
    @State private var newModelBaseURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to enroll this iOS device before editing Hermes saved models.")
                )
            } else {
                HermesSectionCard("Saved Models") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("This panel mirrors the desktop models registry and edits the live `models.json` inventory in the configured Hermes workspace.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Models File", value: companionRuntime.modelsFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/models.json" : companionRuntime.modelsFilePath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        HermesSectionCard("Add Model") {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Display name", text: $newModelName)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                TextField("Provider", text: $newModelProvider)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField("Model ID", text: $newModelID)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField("Base URL", text: $newModelBaseURL)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                Button("Add Model") {
                                    companionRuntime.addHermesModel(
                                        name: newModelName.trimmingCharacters(in: .whitespacesAndNewlines),
                                        provider: newModelProvider.trimmingCharacters(in: .whitespacesAndNewlines),
                                        model: newModelID.trimmingCharacters(in: .whitespacesAndNewlines),
                                        baseURL: newModelBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                    newModelName = ""
                                    newModelProvider = ""
                                    newModelID = ""
                                    newModelBaseURL = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    newModelProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    newModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                )
                            }
                        }

                        if companionRuntime.hermesModels.isEmpty {
                            Text("Loading models will seed the default desktop model list if `models.json` does not already exist.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(companionRuntime.hermesModels) { model in
                                    HermesSavedModelEditorCard(
                                        model: model,
                                        onSave: { name, provider, modelID, baseURL in
                                            companionRuntime.updateHermesModel(
                                                id: model.id,
                                                name: name,
                                                provider: provider,
                                                model: modelID,
                                                baseURL: baseURL,
                                                settings: companionSettings,
                                                identityState: companionEnrollment.identityState
                                            )
                                        },
                                        onRemove: {
                                            companionRuntime.removeHermesModel(
                                                id: model.id,
                                                settings: companionSettings,
                                                identityState: companionEnrollment.identityState
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesModels(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesModels(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
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


struct HermesSavedModelEditorCard: View {
    let model: HermesCompanionSavedModel
    let onSave: (String, String, String, String) -> Void
    let onRemove: () -> Void
    @State private var name: String
    @State private var provider: String
    @State private var modelID: String
    @State private var baseURL: String

    init(
        model: HermesCompanionSavedModel,
        onSave: @escaping (String, String, String, String) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.model = model
        self.onSave = onSave
        self.onRemove = onRemove
        _name = State(initialValue: model.name)
        _provider = State(initialValue: model.provider)
        _modelID = State(initialValue: model.model)
        _baseURL = State(initialValue: model.baseURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.createdAtDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            TextField("Display name", text: $name)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
            TextField("Provider", text: $provider)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Model ID", text: $modelID)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Base URL", text: $baseURL)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                Button("Save") {
                    onSave(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        provider.trimmingCharacters(in: .whitespacesAndNewlines),
                        modelID.trimmingCharacters(in: .whitespacesAndNewlines),
                        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Button("Remove", role: .destructive) {
                    onRemove()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
