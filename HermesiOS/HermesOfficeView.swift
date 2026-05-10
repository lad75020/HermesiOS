//
//  HermesOfficeView.swift
//  HermesiOS
//

import Combine
import SwiftUI
import WebKit

let defaultHermesOfficeURL = HermesHostEndpoints.httpURLString(host: defaultHermesMacHost, port: defaultHermesOfficePort)
let hermesOfficeWebViewEnabledStorageKey = "hermes.office.webView.enabled"

struct HermesOfficeView: View {
    @AppStorage(hermesMacHostStorageKey) private var macHost = defaultHermesMacHost
    @AppStorage(hermesOfficePortStorageKey) private var officePort = defaultHermesOfficePort
    @AppStorage(hermesOfficeWebViewEnabledStorageKey) private var isOfficeWebViewEnabled = true
    @ObservedObject var webViewStore: HermesOfficeWebViewStore
    @Binding var reloadID: UUID

    private var officeURLString: String {
        HermesHostEndpoints.httpURLString(host: macHost, port: officePort)
    }

    private var officeURL: URL? {
        URL(string: officeURLString)
    }

    var body: some View {
        VStack(spacing: 0) {
            officeHeader
                .padding(.horizontal)
                .padding(.top)

            if !isOfficeWebViewEnabled {
                ContentUnavailableView(
                    "Claw3D WebView is Off",
                    systemImage: "power",
                    description: Text("Turn it on from the Office tab header when you want to load Hermes Office / Claw3D.")
                )
                .foregroundStyle(.hermesSecondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let officeURL {
                HermesOfficeWebView(store: webViewStore, url: officeURL, reloadID: reloadID)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.hermesDivider.opacity(0.45), lineWidth: 1)
                    }
                    .padding()
            } else {
                ContentUnavailableView(
                    "Invalid Office URL",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Open Settings and enter a valid Hermes Office URL, for example \(defaultHermesOfficeURL).")
                )
                .foregroundStyle(.hermesSecondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reloadID = UUID()
                } label: {
                    Label("Reload Office", systemImage: "arrow.clockwise")
                }
                .disabled(!isOfficeWebViewEnabled || officeURL == nil)
            }
        }
        .onChange(of: isOfficeWebViewEnabled) { _, newValue in
            if newValue {
                reloadID = UUID()
            } else {
                webViewStore.turnOff()
            }
        }
    }

    private var officeHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            Text("Office (beta)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Toggle("Claw3D WebView", isOn: $isOfficeWebViewEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel("Claw3D WebView")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

struct HermesOfficeSettingsSection: View {
    @AppStorage(hermesMacHostStorageKey) private var macHost = defaultHermesMacHost
    @AppStorage(hermesOfficePortStorageKey) private var officePort = defaultHermesOfficePort
    @State private var officeReturnsHTTP200 = false

    private var officeURLString: String {
        HermesHostEndpoints.httpURLString(host: macHost, port: officePort)
    }

    var body: some View {
        Section("Office") {
            HStack(alignment: .center, spacing: 10) {
                HermesSettingsStatusLED(
                    isOn: officeReturnsHTTP200,
                    label: officeReturnsHTTP200 ? "Office URL returns HTTP 200" : "Office URL does not return HTTP 200"
                )

                TextField("TCP port, e.g. 9116", text: $officePort)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .hermesRuntimeInput()
            }

            Text("Office URL: \(officeURLString)")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
        }
        .task(id: officeURLString) {
            await runOfficeStatusLoop()
        }
    }

    private func runOfficeStatusLoop() async {
        while !Task.isCancelled {
            officeReturnsHTTP200 = await checkOfficeURLReturnsHTTP200()
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
        }
    }

    private func checkOfficeURLReturnsHTTP200() async -> Bool {
        let trimmedURL = officeURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 2)
        request.httpMethod = "GET"

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

@MainActor
final class HermesOfficeWebViewStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let webView: WKWebView

    private var lastURL: URL?
    private var lastReloadID: UUID?

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.backgroundColor = UIColor(Color.hermesCanvas)
        webView.backgroundColor = UIColor(Color.hermesCanvas)
        webView.allowsBackForwardNavigationGestures = true
        self.webView = webView
    }

    func loadIfNeeded(url: URL, reloadID: UUID) {
        guard lastURL != url || lastReloadID != reloadID else { return }
        lastURL = url
        lastReloadID = reloadID
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        webView.load(request)
    }

    func preload(urlString: String, reloadID: UUID) {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL) else { return }
        loadIfNeeded(url: url, reloadID: reloadID)
    }

    func turnOff() {
        lastURL = nil
        lastReloadID = nil
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }
}

private struct HermesOfficeWebView: UIViewRepresentable {
    let store: HermesOfficeWebViewStore
    let url: URL
    let reloadID: UUID

    func makeUIView(context: Context) -> WKWebView {
        store.loadIfNeeded(url: url, reloadID: reloadID)
        return store.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        store.loadIfNeeded(url: url, reloadID: reloadID)
    }
}
