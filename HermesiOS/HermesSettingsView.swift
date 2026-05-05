//
//  HermesSettingsView.swift
//  HermesiOS
//

import Observation
import PhotosUI
import SwiftUI
import Vision
import VisionKit

struct HermesSettingsView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var companionSettings: HermesCompanionSettings
    @Binding var responsesDraft: HermesRequestDraft
    @Binding var chatDraft: HermesChatDraft
    @Binding var appTheme: HermesAppTheme
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @State private var isPairingScannerPresented = false
    @State private var selectedPairingQRImage: PhotosPickerItem?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("App Theme", selection: $appTheme) {
                    ForEach(HermesAppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                Text("Choose System to follow the device appearance, or force Hermes to Light or Dark mode.")
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)
            }

            Section("Gateway") {
                TextField("Base URL", text: $apiSettings.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Bearer token", text: $apiSettings.apiKey)

                Toggle("Allow self-signed HTTPS certificates", isOn: $apiSettings.allowSelfSignedCertificates)

                settingsRow(label: "Responses URL", value: HermesAPISettings.responseURL(from: apiSettings.baseURL)?.absoluteString ?? "Invalid URL")
                settingsRow(label: "Chat URL", value: HermesAPISettings.chatCompletionsURL(from: apiSettings.baseURL)?.absoluteString ?? "Invalid URL")

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        companionRuntime.restartAPIService(
                            settings: companionSettings,
                            identityState: companionEnrollment.identityState
                        )
                    } label: {
                        Label("Restart API Server", systemImage: "arrow.clockwise.circle")
                    }
                    .hermesGlassProminentButton()
                    .disabled(companionEnrollment.identityState.isEnrolled == false || companionRuntime.isBusy)

                    Text(companionEnrollment.identityState.isEnrolled ? "Uses the enrolled Host Companion to restart the host-side Hermes API server service." : "Enroll Host Companion before restarting the API server from iOS.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)

                    if companionRuntime.connectionStatus != "Idle" {
                        settingsRow(label: "Restart Status", value: companionRuntime.connectionStatus)
                    }

                    if !companionRuntime.lastErrorMessage.isEmpty {
                        Text(companionRuntime.lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.igDestructive)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Host Companion") {
                TextField("Enrollment URL", text: $companionSettings.enrollmentURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("API URL", text: $companionSettings.apiURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Hermes workspace path", text: $companionSettings.hermesWorkspacePath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Device name", text: $companionSettings.deviceName)

                TextField("Server fingerprint", text: $companionSettings.expectedServerFingerprint, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(3, reservesSpace: true)

                TextField("Pairing ID", text: $companionSettings.pairingID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Pairing secret", text: $companionSettings.pairingSecret)

                Button("Scan Pairing QR") {
                    isPairingScannerPresented = true
                }
                .disabled(HermesPairingQRScannerView.isSupported == false)

                PhotosPicker(selection: $selectedPairingQRImage, matching: .images) {
                    Label("Pick Pairing QR Image", systemImage: "photo")
                }

                settingsRow(label: "Enrollment Status", value: companionEnrollment.connectionStatus)

                if companionEnrollment.identityState.isEnrolled {
                    settingsRow(label: "Enrolled Device", value: companionEnrollment.identityState.deviceName)
                    settingsRow(label: "Device ID", value: companionEnrollment.identityState.deviceID)
                    settingsRow(label: "Pinned Fingerprint", value: companionEnrollment.identityState.serverCertificateFingerprint)
                    settingsRow(label: "Companion Endpoint", value: companionEnrollment.identityState.serverEndpoint)
                }

                if !companionEnrollment.lastErrorMessage.isEmpty {
                    Text(companionEnrollment.lastErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.igDestructive)
                }

                HStack {
                    Button(companionEnrollment.identityState.isEnrolled ? "Re-enroll" : "Enroll Device") {
                        companionEnrollment.enroll(settings: companionSettings)
                    }
                    .hermesGlassProminentButton()
                    .disabled(
                        companionEnrollment.isEnrolling ||
                        companionSettings.enrollmentURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        companionSettings.expectedServerFingerprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        companionSettings.pairingID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        companionSettings.pairingSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    if companionEnrollment.identityState.isEnrolled {
                        Button("Clear Identity", role: .destructive) {
                            companionEnrollment.clearIdentity()
                        }
                        .hermesGlassButton()
                    }
                }
            }

            Section("/v1/responses") {
                TextField("Model", text: $responsesDraft.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Streaming enabled", isOn: $responsesDraft.stream)

                TextField("Instructions", text: $responsesDraft.instructions, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }

            Section("/v1/chat/completions") {
                TextField("Model", text: $chatDraft.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Streaming enabled", isOn: $chatDraft.stream)

                TextField("System prompt", text: $chatDraft.systemPrompt, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }

            Section("Notes") {
                Text("Responses and Chat screens are now limited to message exchange and output.")
                Text("Use this screen for endpoint, auth, model, streaming, and prompt configuration.")
                Text("Keep self-signed certificate support off unless you trust the Hermes API server.")
                Text("For the host companion, copy the server fingerprint from the macOS app, create a pairing there, then enroll this device to import its client certificate.")
                Text("Set the Hermes workspace path to the host-side `.hermes` directory you want the Skills panel to manage.")
            }
            .foregroundStyle(.hermesSecondaryText)
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Color.hermesCanvas)
        .sheet(isPresented: $isPairingScannerPresented) {
            HermesPairingQRScannerView { payload in
                applyPairingPayload(payload)
                isPairingScannerPresented = false
            }
        }
        .task(id: selectedPairingQRImage) {
            guard let selectedPairingQRImage else { return }
            do {
                guard let imageData = try await selectedPairingQRImage.loadTransferable(type: Data.self) else {
                    throw HermesCompanionClientError.invalidPairingQRCode
                }
                let payload = try HermesPairingImageDecoder.decode(from: imageData)
                applyPairingPayload(payload)
                self.selectedPairingQRImage = nil
            } catch {
                companionEnrollment.lastErrorMessage = error.localizedDescription
                self.selectedPairingQRImage = nil
            }
        }
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.hermesSecondaryText)
        }
        .font(.subheadline)
    }

    private func applyPairingPayload(_ payload: HermesCompanionPairingQRCodePayload) {
        companionSettings.enrollmentURL = payload.enrollmentURL
        companionSettings.apiURL = payload.apiURL
        companionSettings.expectedServerFingerprint = payload.serverFingerprint
        companionSettings.pairingID = payload.pairingID
        companionSettings.pairingSecret = payload.pairingSecret
    }
}

struct HermesPairingQRScannerView: View {
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    let onPayload: (HermesCompanionPairingQRCodePayload) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if Self.isSupported {
                    HermesDataScannerContainer { scannedValue in
                        do {
                            let payload = try HermesCompanionPairingPayloadDecoder.decode(scannedValue)
                            onPayload(payload)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Scanner Unavailable",
                        systemImage: "qrcode.viewfinder",
                        description: Text("QR scanning requires a real camera-backed iOS device. The simulator cannot scan pairing codes.")
                    )
                }
            }
            .navigationTitle("Scan Pairing QR")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.igDestructive)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding()
                }
            }
        }
    }
}

struct HermesDataScannerContainer: UIViewControllerRepresentable {
    let onScannedValue: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScannedValue: onScannedValue)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScannedValue: (String) -> Void
        private var hasScanned = false

        init(onScannedValue: @escaping (String) -> Void) {
            self.onScannedValue = onScannedValue
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard hasScanned == false else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item else { continue }
                guard let payload = barcode.payloadStringValue, payload.isEmpty == false else { continue }
                hasScanned = true
                dataScanner.stopScanning()
                onScannedValue(payload)
                return
            }
        }
    }
}
