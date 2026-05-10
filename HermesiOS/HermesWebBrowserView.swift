//
//  HermesWebBrowserView.swift
//  HermesiOS
//

import Combine
import SwiftUI
import WebKit

struct HermesWebBrowserView: View {
    @ObservedObject var deckStore: HermesWebBrowserDeckStore
    let dashboardURLString: String
    @FocusState private var isURLFieldFocused: Bool

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

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("https://example.com", text: activeURLString)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .focused($isURLFieldFocused)
                            .hermesRuntimeInput()
                            .onSubmit(loadEnteredURL)
                            .accessibilityLabel("Web URL")

                        if activeWorkspace.store.isLoading {
                            ProgressView()
                                .controlSize(.regular)
                                .frame(width: 28, height: 28)
                                .accessibilityLabel("Page loading")
                        }
                    }

                    if isURLFieldFocused, activeHistorySuggestions.isEmpty == false {
                        historySuggestions
                    }
                }
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
                loadDashboardURL()
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .font(.headline.weight(.bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .hermesLiquidGlass(cornerRadius: 12, tint: .igActionBlue.opacity(0.16), interactive: true)
            .accessibilityLabel("Open Hermes dashboard")

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

    private var activeHistorySuggestions: [String] {
        deckStore.historySuggestions(matching: activeWorkspace.urlString)
    }

    private var historySuggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(activeHistorySuggestions, id: \.self) { suggestion in
                Button {
                    loadHistorySuggestion(suggestion)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(suggestion)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion != activeHistorySuggestions.last {
                    Divider().opacity(0.35)
                }
            }
        }
        .background(Color.hermesSurfaceInput.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.hermesDivider.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 8)
    }

    private func loadEnteredURL() {
        guard let url = normalizedURL(from: activeWorkspace.urlString) else { return }
        activeWorkspace.urlString = url.absoluteString
        deckStore.persistURLStringIfNeeded(for: activeWorkspace)
        deckStore.recordHistoryRoot(for: url)
        isURLFieldFocused = false
        activeWorkspace.store.load(url)
    }

    private func loadHistorySuggestion(_ suggestion: String) {
        guard let url = normalizedURL(from: suggestion) else { return }
        activeWorkspace.urlString = url.absoluteString
        deckStore.persistURLStringIfNeeded(for: activeWorkspace)
        deckStore.recordHistoryRoot(for: url)
        isURLFieldFocused = false
        activeWorkspace.store.load(url)
    }

    private func loadDashboardURL() {
        guard let url = normalizedURL(from: dashboardURLString) else { return }
        deckStore.recordHistoryRoot(for: url)
        let workspace = deckStore.createWorkspace(urlString: url.absoluteString)
        workspace.store.load(url)
    }

    private func loadIfNeeded(_ workspace: HermesWebBrowserWorkspace) {
        guard workspace.store.currentURL == nil else { return }
        guard let url = normalizedURL(from: workspace.urlString) else { return }
        workspace.urlString = url.absoluteString
        deckStore.persistURLStringIfNeeded(for: workspace)
        deckStore.recordHistoryRoot(for: url)
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
    @Published private(set) var rootHistory: [String]
    private var workspaceCancellables: [HermesWebBrowserWorkspace.ID: AnyCancellable] = [:]
    private static let historyDefaultsKey = "hermes.web.history.roots"
    private static let openPagesDefaultsKey = "hermes.web.open.pages"
    private static let selectedPageDefaultsKey = "hermes.web.selected.page"
    private static let maxHistoryCount = 20

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
        let legacyURLString = UserDefaults.standard.string(forKey: "hermes.web.url") ?? "https://"
        let restoredURLStrings = Self.restoredURLStrings(fallback: legacyURLString)
        let restoredWorkspaces = restoredURLStrings.enumerated().map { index, urlString in
            HermesWebBrowserWorkspace(number: index + 1, urlString: urlString)
        }
        self.workspaces = restoredWorkspaces
        let selectedNumber = UserDefaults.standard.integer(forKey: Self.selectedPageDefaultsKey)
        self.selectedWorkspaceID = restoredWorkspaces.first(where: { $0.number == selectedNumber })?.id ?? restoredWorkspaces[0].id
        self.rootHistory = UserDefaults.standard.stringArray(forKey: Self.historyDefaultsKey) ?? []
        restoredWorkspaces.forEach { observe($0) }
    }

    @discardableResult
    func createWorkspace(urlString: String = "https://") -> HermesWebBrowserWorkspace {
        if canCreateWorkspace {
            let nextNumber = (1...4).first { number in
                !workspaces.contains { $0.number == number }
            } ?? (workspaces.count + 1)
            let workspace = HermesWebBrowserWorkspace(number: nextNumber, urlString: urlString)
            observe(workspace)
            workspaces.append(workspace)
            workspaces.sort { $0.number < $1.number }
            selectedWorkspaceID = workspace.id
            persistOpenPages()
            return workspace
        }

        let workspace = activeWorkspace
        workspace.urlString = urlString
        persistURLStringIfNeeded(for: workspace)
        persistOpenPages()
        return workspace
    }

    func selectWorkspace(id: HermesWebBrowserWorkspace.ID) {
        guard workspaces.contains(where: { $0.id == id }) else { return }
        selectedWorkspaceID = id
        persistOpenPages()
    }

    func persistURLStringIfNeeded(for workspace: HermesWebBrowserWorkspace) {
        guard workspace.number == 1 else {
            persistOpenPages()
            return
        }
        UserDefaults.standard.set(workspace.urlString, forKey: "hermes.web.url")
        persistOpenPages()
    }

    func historySuggestions(matching text: String) -> [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "", options: [.caseInsensitive, .anchored])
            .replacingOccurrences(of: "http://", with: "", options: [.caseInsensitive, .anchored])
            .lowercased()

        guard query.isEmpty == false else {
            return Array(rootHistory.prefix(5))
        }

        return rootHistory
            .filter { root in
                let comparable = root
                    .replacingOccurrences(of: "https://", with: "", options: [.caseInsensitive, .anchored])
                    .replacingOccurrences(of: "http://", with: "", options: [.caseInsensitive, .anchored])
                    .lowercased()
                return comparable.contains(query) && comparable != query
            }
            .prefix(5)
            .map { $0 }
    }

    func recordHistoryRoot(for url: URL) {
        guard let root = Self.rootString(from: url) else { return }
        rootHistory.removeAll { $0.caseInsensitiveCompare(root) == .orderedSame }
        rootHistory.insert(root, at: 0)
        if rootHistory.count > Self.maxHistoryCount {
            rootHistory = Array(rootHistory.prefix(Self.maxHistoryCount))
        }
        UserDefaults.standard.set(rootHistory, forKey: Self.historyDefaultsKey)
    }

    private func persistOpenPages() {
        let urlStrings = workspaces
            .sorted { $0.number < $1.number }
            .map { $0.urlString }
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        UserDefaults.standard.set(urlStrings, forKey: Self.openPagesDefaultsKey)
        UserDefaults.standard.set(activeWorkspace.number, forKey: Self.selectedPageDefaultsKey)
    }

    private func persistNavigatedURL(_ url: URL, for workspace: HermesWebBrowserWorkspace) {
        guard let urlString = Self.pageString(from: url) else { return }
        guard workspace.urlString != urlString else {
            persistOpenPages()
            return
        }
        workspace.urlString = urlString
        persistURLStringIfNeeded(for: workspace)
    }

    private static func restoredURLStrings(fallback: String) -> [String] {
        let saved = UserDefaults.standard.stringArray(forKey: openPagesDefaultsKey) ?? []
        let cleaned = saved
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        let urls = cleaned.isEmpty ? [fallback] : cleaned
        return Array(urls.prefix(4))
    }

    private static func pageString(from url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        return url.absoluteString
    }

    private static func rootString(from url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), let host = url.host else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = url.port
        return components.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func observe(_ workspace: HermesWebBrowserWorkspace) {
        workspace.store.rootURLHandler = { [weak self] url in
            self?.recordHistoryRoot(for: url)
        }
        workspace.store.pageURLHandler = { [weak self, weak workspace] url in
            guard let workspace else { return }
            self?.persistNavigatedURL(url, for: workspace)
        }
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
    @Published private(set) var isLoading = false
    var rootURLHandler: ((URL) -> Void)?
    var pageURLHandler: ((URL) -> Void)?

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
        isLoading = true
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        webView.load(request)
        refreshNavigationState()
    }

    func goBack() {
        guard webView.canGoBack else { return }
        isLoading = true
        webView.goBack()
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        isLoading = true
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        refreshNavigationState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        refreshNavigationState()
    }

    private func refreshNavigationState() {
        canGoBack = webView.canGoBack
        currentURL = webView.url ?? currentURL
        if let currentURL {
            rootURLHandler?(currentURL)
            pageURLHandler?(currentURL)
        }
    }
}

private struct HermesWebView: UIViewRepresentable {
    let store: HermesWebBrowserStore

    func makeUIView(context: Context) -> WKWebView {
        store.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
