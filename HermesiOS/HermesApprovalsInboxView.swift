//
//  HermesApprovalsInboxView.swift
//  HermesiOS
//

import Foundation
import Observation
import SwiftUI

struct HermesApprovalItem: Identifiable, Decodable, Equatable {
    let id: String
    let sessionKey: String
    let queuePosition: Int
    let kind: String
    let title: String
    let command: String
    let description: String
    let patternKey: String?
    let patternKeys: [String]
    let createdAt: Double?
    let surface: String?
    let scopeOptions: [String]
    let profileName: String?
    let sessionID: String?
    let commandDiff: String?
    let context: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, command, description, surface, context
        case sessionKey = "session_key"
        case queuePosition = "queue_position"
        case patternKey = "pattern_key"
        case patternKeys = "pattern_keys"
        case createdAt = "created_at"
        case scopeOptions = "scope_options"
        case profileName = "profile"
        case sessionID = "session_id"
        case commandDiff = "diff"
    }

    var displayKind: String {
        switch kind {
        case "shell_command": "Shell command"
        case "local_filesystem": "Local filesystem"
        case "tls_certificate": "TLS certificate"
        default: kind.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
        }
    }

    var allowsAlways: Bool { scopeOptions.contains("always") }

    var ageText: String {
        guard let createdAt else { return "Pending" }
        let elapsed = max(0, Date().timeIntervalSince1970 - createdAt)
        if elapsed < 60 { return "\(Int(elapsed))s ago" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))m ago" }
        if elapsed < 86_400 { return "\(Int(elapsed / 3600))h ago" }
        return "\(Int(elapsed / 86_400))d ago"
    }

    var createdDateText: String {
        guard let createdAt else { return "Unknown time" }
        return Date(timeIntervalSince1970: createdAt).formatted(date: .abbreviated, time: .standard)
    }

    var displayProfileName: String {
        let explicit = profileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !explicit.isEmpty { return explicit }
        return inferredSessionParts.profile
    }

    var displaySessionName: String {
        let explicit = sessionID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !explicit.isEmpty { return explicit }
        return inferredSessionParts.session
    }

    var displaySurface: String {
        let value = surface?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Hermes Agent" : value
    }

    var hasInspectableContext: Bool {
        !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(commandDiff?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || !(context?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || !patternKeys.isEmpty
    }

    private var inferredSessionParts: (profile: String, session: String) {
        let trimmed = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("default", "Unknown session") }

        if let profileRange = trimmed.range(of: "profile=", options: [.caseInsensitive]) {
            let afterProfile = String(trimmed[profileRange.upperBound...])
            let profile = afterProfile
                .split(whereSeparator: { "|/&? ,".contains($0) })
                .first
                .map(String.init) ?? "default"
            return (profile.isEmpty ? "default" : profile, trimmed)
        }

        let separators: [Character] = [":", "/", "|"]
        for separator in separators where trimmed.contains(separator) {
            let parts = trimmed.split(separator: separator, omittingEmptySubsequences: true).map(String.init)
            if parts.count >= 2 {
                let profileCandidate = parts.first { part in
                    let lower = part.lowercased()
                    return lower == "default" || lower.hasPrefix("profile") || lower.contains(".hermes")
                }
                let profile = profileCandidate?.replacingOccurrences(of: "profile=", with: "") ?? "default"
                return (profile.isEmpty ? "default" : profile, parts.last ?? trimmed)
            }
        }

        return ("default", trimmed)
    }
}

struct HermesApprovalsResponse: Decodable {
    let approvals: [HermesApprovalItem]
    let count: Int
}

struct HermesApprovalResolveBody: Encodable {
    let choice: String
    let resolveAll: Bool
    let sessionKey: String

    enum CodingKeys: String, CodingKey {
        case choice
        case resolveAll = "resolve_all"
        case sessionKey = "session_key"
    }
}

@MainActor
@Observable
final class HermesApprovalsInboxStore {
    var approvals: [HermesApprovalItem] = []
    var status = "Ready"
    var lastErrorMessage = ""
    var isLoading = false
    var resolvingIDs: Set<String> = []
    var lastUpdated: Date?
    var autoRefresh = true

    var pendingCount: Int { approvals.count }
    var hasPendingApprovals: Bool { pendingCount > 0 }

    func refresh(apiSettings: HermesAPISettings) async {
        guard !isLoading else { return }
        isLoading = true
        status = "Refreshing approvals"
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let response = try await fetchApprovals(apiSettings: apiSettings)
            approvals = response.approvals.sorted { lhs, rhs in
                if lhs.sessionKey == rhs.sessionKey { return lhs.queuePosition < rhs.queuePosition }
                return (lhs.createdAt ?? 0) < (rhs.createdAt ?? 0)
            }
            lastUpdated = Date()
            status = approvals.isEmpty ? "No pending approvals" : "\(approvals.count) pending approval\(approvals.count == 1 ? "" : "s")"
        } catch {
            approvals = []
            lastErrorMessage = error.localizedDescription
            status = "Approvals refresh failed"
        }
    }

    func resolve(_ approval: HermesApprovalItem, choice: String, apiSettings: HermesAPISettings) async {
        guard !resolvingIDs.contains(approval.id) else { return }
        resolvingIDs.insert(approval.id)
        status = "Resolving approval"
        lastErrorMessage = ""
        defer { resolvingIDs.remove(approval.id) }

        do {
            try await resolveApproval(apiSettings: apiSettings, approval: approval, choice: choice)
            status = choice == "deny" ? "Approval denied" : "Approval approved"
            await refresh(apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
            status = "Resolve failed"
        }
    }

    func runAutoRefreshLoop(apiSettings: HermesAPISettings) async {
        await refresh(apiSettings: apiSettings)
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(5)) } catch { break }
            if Task.isCancelled { break }
            guard autoRefresh else { continue }
            await refresh(apiSettings: apiSettings)
        }
    }

    private func fetchApprovals(apiSettings: HermesAPISettings) async throws -> HermesApprovalsResponse {
        guard let url = HermesAPISettings.approvalsURL(from: apiSettings.baseURL) else { throw HermesResponsesError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if apiSettings.hasAuthorizationToken {
            try HermesEndpointSecurity.validateSensitiveURL(url)
            request.setHermesAuthorization(from: apiSettings)
        }
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        try validateJSONResponse(response)
        return try JSONDecoder().decode(HermesApprovalsResponse.self, from: data)
    }

    private func resolveApproval(apiSettings: HermesAPISettings, approval: HermesApprovalItem, choice: String) async throws {
        guard let url = HermesAPISettings.approvalResolveURL(from: apiSettings.baseURL) else { throw HermesResponsesError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if apiSettings.hasAuthorizationToken {
            try HermesEndpointSecurity.validateSensitiveURL(url)
            request.setHermesAuthorization(from: apiSettings)
        }
        request.httpBody = try JSONEncoder().encode(HermesApprovalResolveBody(choice: choice, resolveAll: false, sessionKey: approval.sessionKey))
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (_, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
    }

    private func validateJSONResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { throw HermesResponsesError.invalidResponse }
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard contentType.localizedCaseInsensitiveContains("application/json") else {
            throw HermesApprovalsInboxError.unexpectedResponseFormat
        }
    }
}

enum HermesApprovalsInboxError: LocalizedError {
    case unexpectedResponseFormat

    var errorDescription: String? {
        switch self {
        case .unexpectedResponseFormat:
            "The Hermes approvals endpoint did not return JSON. Restart Hermes Agent so the approvals API is available."
        }
    }
}

struct HermesApprovalsInboxView: View {
    @Bindable var store: HermesApprovalsInboxStore
    let apiSettings: HermesAPISettings
    let connectedHostName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statusRow
                errorBanner
                content
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Approvals Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await store.refresh(apiSettings: apiSettings)
        }
    }

    private var header: some View {
        HermesHeroCard(
            title: "Approvals Inbox",
            detail: "Approve, deny, or allow dangerous-command prompts for all Hermes sessions, profiles, apps, and TUI runs connected to this agent.",
            systemImage: "checkmark.shield"
        )
    }

    private var statusRow: some View {
        HermesStatusRow(
            items: [
                .init(title: "Pending", value: "\(store.pendingCount)", accent: store.hasPendingApprovals ? .igGradOrange : .igOnlineGreen),
                .init(title: "Agent", value: connectedHostName, accent: .igActionBlue, marqueeCharacterLimit: 24),
                .init(title: "Updated", value: store.lastUpdated?.formatted(date: .omitted, time: .standard) ?? "Never", accent: .igGradPurple)
            ]
        )
    }

    @ViewBuilder
    private var errorBanner: some View {
        if !store.lastErrorMessage.isEmpty {
            Label(store.lastErrorMessage, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.igDestructive)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hermesLiquidGlass(cornerRadius: 18, tint: Color.igDestructive.opacity(0.10), interactive: false)
        }
    }

    @ViewBuilder
    private var content: some View {
        HermesSectionCard(store.approvals.isEmpty ? "Queue" : "Pending queue") {
            HStack(spacing: 12) {
                Label(store.status, systemImage: store.hasPendingApprovals ? "tray.full" : "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.hasPendingApprovals ? .igGradOrange : .igOnlineGreen)
                Spacer()
                Toggle("Auto", isOn: Binding(
                    get: { store.autoRefresh },
                    set: { store.autoRefresh = $0 }
                ))
                .labelsHidden()
                .accessibilityLabel("Auto refresh approvals")
                Button {
                    Task { await store.refresh(apiSettings: apiSettings) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .hermesGlassButton()
                .disabled(store.isLoading)
            }

            if store.approvals.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(store.approvals) { approval in
                        HermesApprovalCard(
                            approval: approval,
                            isResolving: store.resolvingIDs.contains(approval.id),
                            onResolve: { choice in
                                Task { await store.resolve(approval, choice: choice, apiSettings: apiSettings) }
                            }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.hermesSecondaryText)
            Text("No approvals waiting")
                .font(.headline)
            Text("When a Hermes run pauses for a dangerous command, the request appears here with session/profile context and approval controls.")
                .font(.callout)
                .foregroundStyle(.hermesSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}

private struct HermesApprovalCard: View {
    let approval: HermesApprovalItem
    let isResolving: Bool
    let onResolve: (String) -> Void
    @State private var isContextExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: approval.kind == "shell_command" ? "terminal" : "exclamationmark.triangle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.igGradOrange)
                    .frame(width: 34, height: 34)
                    .hermesLiquidGlass(cornerRadius: 12, tint: Color.igGradOrange.opacity(0.18), interactive: false)

                VStack(alignment: .leading, spacing: 5) {
                    Text(approval.title)
                        .font(.headline)
                    Text("\(approval.displayKind) • Queue #\(approval.queuePosition) • \(approval.ageText)")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }
                Spacer(minLength: 8)
                Text(approval.displaySurface)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.igActionBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.igActionBlue.opacity(0.10)))
            }

            if !approval.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(approval.description, systemImage: "exclamationmark.shield")
                    .font(.callout)
                    .foregroundStyle(.igGradOrange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            metadataGrid

            if approval.hasInspectableContext {
                DisclosureGroup(isExpanded: $isContextExpanded) {
                    inspectableContext
                } label: {
                    Label("Command diff / context", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(.igActionBlue)
            }

            approvalActions
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 22, tint: Color.igGradOrange.opacity(0.07), interactive: true)
    }

    private var metadataGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            approvalMetadataRow(title: "Profile", value: approval.displayProfileName, systemImage: "person.crop.circle.badge.checkmark")
            approvalMetadataRow(title: "Session", value: approval.displaySessionName, systemImage: "rectangle.connected.to.line.below")
            approvalMetadataRow(title: "Requested", value: approval.createdDateText, systemImage: "clock")
        }
    }

    private func approvalMetadataRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.hermesSecondaryText)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.hermesSecondaryText)
                .frame(width: 72, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var inspectableContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !approval.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                labeledCodeBlock(title: "Command", value: approval.command)
            }
            if let commandDiff = approval.commandDiff?.trimmingCharacters(in: .whitespacesAndNewlines), !commandDiff.isEmpty {
                labeledCodeBlock(title: "Diff", value: commandDiff)
            }
            if let context = approval.context?.trimmingCharacters(in: .whitespacesAndNewlines), !context.isEmpty {
                labeledCodeBlock(title: "Context", value: context)
            }
            if !approval.patternKeys.isEmpty {
                labeledCodeBlock(title: "Matched approval keys", value: approval.patternKeys.joined(separator: "\n"))
            }
            if !approval.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                labeledCodeBlock(title: "Risk description", value: approval.description)
            }
        }
        .padding(.top, 10)
    }

    private func labeledCodeBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.hermesSecondaryText)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.hermesSurfaceInput.opacity(0.84))
                )
        }
    }

    private var approvalActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { actionButtons }
            VStack(spacing: 8) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        actionButton("Approve", systemImage: "checkmark.circle", tint: .igOnlineGreen, choice: "once")
        actionButton("Session", systemImage: "checkmark.seal", tint: .igActionBlue, choice: "session")
        actionButton("Always", systemImage: "infinity.circle", tint: .igGradPurple, choice: "always")
            .disabled(!approval.allowsAlways || isResolving)
        actionButton("Deny", systemImage: "xmark.octagon", tint: .igDestructive, choice: "deny")
    }

    private func actionButton(_ title: String, systemImage: String, tint: Color, choice: String) -> some View {
        Button {
            onResolve(choice)
        } label: {
            if isResolving {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
        }
        .hermesGlassProminentButton()
        .tint(tint)
        .disabled(isResolving)
    }
}
