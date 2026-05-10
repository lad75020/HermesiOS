//
//  HermesWebBrowserView.swift
//  HermesiOS
//

import Combine
import SwiftUI
import WebKit

struct HermesWebBrowserView: View {
    @ObservedObject var deckStore: HermesWebBrowserDeckStore

    private var activeWorkspace: HermesWebBrowserWorkspace {
        deckStore.activeWorkspace
    }

    var body: some View {
        VStack(spacing: 0) {
            webHeader
                .padding(.horizontal)
                .padding(.top)

            HStack(spacing: 10) {
                Button {
                    activeWorkspace.store.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.headline.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .hermesLiquidGlass(cornerRadius: 12, tint: activeWorkspace.store.canGoBack ? .igActionBlue.opacity(0.14) : .hermesSurfaceInput.opacity(0.45), interactive: activeWorkspace.store.canGoBack)
                .disabled(!activeWorkspace.store.canGoBack)
                .accessibilityLabel("Back")

                TextField("https://example.com", text: activeURLString)
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

            HermesWebView(store: activeWorkspace.store)
                .id(activeWorkspace.id)
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
            loadIfNeeded(activeWorkspace)
        }
        .onChange(of: deckStore.selectedWorkspaceID) { _, _ in
            loadIfNeeded(activeWorkspace)
        }
    }

    private var webHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            Text("Web")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Button {
                deckStore.createWorkspace()
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .hermesLiquidGlass(cornerRadius: 12, tint: deckStore.canCreateWorkspace ? .igActionBlue.opacity(0.16) : .hermesSurfaceInput.opacity(0.45), interactive: deckStore.canCreateWorkspace)
            .disabled(!deckStore.canCreateWorkspace)
            .accessibilityLabel("Open another web view")

            if deckStore.workspaces.count > 1 {
                ForEach(deckStore.workspaces) { workspace in
                    Button {
                        deckStore.selectWorkspace(id: workspace.id)
                    } label: {
                        Text("\(workspace.number)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .frame(minWidth: 32, minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(deckStore.selectedWorkspaceID == workspace.id ? .white : .primary)
                    .hermesLiquidGlass(
                        cornerRadius: 12,
                        tint: deckStore.selectedWorkspaceID == workspace.id ? .igActionBlue.opacity(0.9) : .white.opacity(0.06),
                        interactive: true
                    )
                    .accessibilityLabel("Web view \(workspace.number)")
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var activeURLString: Binding<String> {
        Binding(
            get: { activeWorkspace.urlString },
            set: { newValue in
                activeWorkspace.urlString = newValue
                deckStore.persistURLStringIfNeeded(for: activeWorkspace)
            }
        )
    }

    private func loadEnteredURL() {
        guard let url = normalizedURL(from: activeWorkspace.urlString) else { return }
        activeWorkspace.urlString = url.absoluteString
        deckStore.persistURLStringIfNeeded(for: activeWorkspace)
        activeWorkspace.store.load(url)
    }

    private func loadIfNeeded(_ workspace: HermesWebBrowserWorkspace) {
        guard workspace.store.currentURL == nil else { return }
        guard let url = normalizedURL(from: workspace.urlString) else { return }
        workspace.urlString = url.absoluteString
        deckStore.persistURLStringIfNeeded(for: workspace)
        workspace.store.load(url)
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
final class HermesWebBrowserDeckStore: ObservableObject {
    @Published private(set) var workspaces: [HermesWebBrowserWorkspace]
    @Published var selectedWorkspaceID: HermesWebBrowserWorkspace.ID
    private var workspaceCancellables: [HermesWebBrowserWorkspace.ID: AnyCancellable] = [:]

    var activeWorkspace: HermesWebBrowserWorkspace {
        if let workspace = workspaces.first(where: { $0.id == selectedWorkspaceID }) {
            return workspace
        }
        return workspaces[0]
    }

    var canCreateWorkspace: Bool {
        workspaces.count < 4
    }

    init() {
        let initialURLString = UserDefaults.standard.string(forKey: "hermes.web.url") ?? "https://"
        let workspace = HermesWebBrowserWorkspace(number: 1, urlString: initialURLString)
        self.workspaces = [workspace]
        self.selectedWorkspaceID = workspace.id
        observe(workspace)
    }

    func createWorkspace() {
        guard canCreateWorkspace else { return }
        let nextNumber = (1...4).first { number in
            !workspaces.contains { $0.number == number }
        } ?? (workspaces.count + 1)
        let workspace = HermesWebBrowserWorkspace(number: nextNumber)
        observe(workspace)
        workspaces.append(workspace)
        workspaces.sort { $0.number < $1.number }
        selectedWorkspaceID = workspace.id
    }

    func selectWorkspace(id: HermesWebBrowserWorkspace.ID) {
        guard workspaces.contains(where: { $0.id == id }) else { return }
        selectedWorkspaceID = id
    }

    func persistURLStringIfNeeded(for workspace: HermesWebBrowserWorkspace) {
        guard workspace.number == 1 else { return }
        UserDefaults.standard.set(workspace.urlString, forKey: "hermes.web.url")
    }

    private func observe(_ workspace: HermesWebBrowserWorkspace) {
        workspaceCancellables[workspace.id] = workspace.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

@MainActor
final class HermesWebBrowserWorkspace: ObservableObject, Identifiable {
    let id = UUID()
    let number: Int
    @Published var urlString: String
    let store: HermesWebBrowserStore
    private var storeCancellable: AnyCancellable?

    init(number: Int, urlString: String = "https://") {
        self.number = number
        self.urlString = urlString
        self.store = HermesWebBrowserStore()
        self.storeCancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
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
