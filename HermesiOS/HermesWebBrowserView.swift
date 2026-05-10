//
//  HermesWebBrowserView.swift
//  HermesiOS
//

import Combine
import SwiftUI
import WebKit

struct HermesWebBrowserView: View {
    @ObservedObject var store: HermesWebBrowserStore
    @AppStorage("hermes.web.url") private var urlString = "https://"

    var body: some View {
        VStack(spacing: 0) {
            HermesTabHeader("Web", systemImage: "globe")
                .padding(.horizontal)
                .padding(.top)

            HStack(spacing: 10) {
                Button {
                    store.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.headline.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .hermesLiquidGlass(cornerRadius: 12, tint: store.canGoBack ? .igActionBlue.opacity(0.14) : .hermesSurfaceInput.opacity(0.45), interactive: store.canGoBack)
                .disabled(!store.canGoBack)
                .accessibilityLabel("Back")

                TextField("https://example.com", text: $urlString)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .hermesRuntimeInput()
                    .onSubmit(loadEnteredURL)
                    .accessibilityLabel("Web URL")
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HermesWebView(store: store)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.hermesDivider.opacity(0.45), lineWidth: 1)
                }
                .padding([.horizontal, .bottom])
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if store.currentURL == nil {
                loadEnteredURL()
            }
        }
    }

    private func loadEnteredURL() {
        guard let url = normalizedURL(from: urlString) else { return }
        urlString = url.absoluteString
        store.load(url)
    }

    private func normalizedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }
}

@MainActor
final class HermesWebBrowserStore: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var canGoBack = false
    @Published private(set) var currentURL: URL?

    let webView: WKWebView

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.backgroundColor = UIColor(Color.hermesCanvas)
        webView.backgroundColor = UIColor(Color.hermesCanvas)
        webView.allowsBackForwardNavigationGestures = true
        self.webView = webView
        super.init()
        webView.navigationDelegate = self
        refreshNavigationState()
    }

    func load(_ url: URL) {
        currentURL = url
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        webView.load(request)
        refreshNavigationState()
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        refreshNavigationState()
    }

    private func refreshNavigationState() {
        canGoBack = webView.canGoBack
        currentURL = webView.url ?? currentURL
    }
}

private struct HermesWebView: UIViewRepresentable {
    let store: HermesWebBrowserStore

    func makeUIView(context: Context) -> WKWebView {
        store.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
