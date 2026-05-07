//
//  HermesOfficeView.swift
//  HermesiOS
//

import Combine
import SwiftUI
import WebKit

private let defaultHermesOfficeURL = "http://localhost:9116"
private let hermesOfficeURLStorageKey = "hermes.office.url"

struct HermesOfficeView: View {
    @AppStorage(hermesOfficeURLStorageKey) private var officeURLString = defaultHermesOfficeURL
    @State private var reloadID = UUID()
    @StateObject private var webViewStore = HermesOfficeWebViewStore()

    private var officeURL: URL? {
        let trimmedURL = officeURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmedURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            HermesTabHeader("Office", systemImage: "building.2.crop.circle")
                .padding(.horizontal)
                .padding(.top)

            if let officeURL {
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
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reloadID = UUID()
                } label: {
                    Label("Reload Office", systemImage: "arrow.clockwise")
                }
                .disabled(officeURL == nil)
            }
        }
    }
}

struct HermesOfficeSettingsSection: View {
    @AppStorage(hermesOfficeURLStorageKey) private var officeURLString = defaultHermesOfficeURL

    var body: some View {
        Section("Office") {
            TextField("URL, e.g. http://localhost:9116", text: $officeURLString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .hermesRuntimeInput()

            Text("The Office tab opens this URL in an embedded WebView. Use http://localhost:9116 for the iOS Simulator on the Mac, or a reachable HTTPS/Tailscale URL when running on a physical device.")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
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
