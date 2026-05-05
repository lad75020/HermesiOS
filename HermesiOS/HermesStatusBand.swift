//
//  HermesStatusBand.swift
//  HermesiOS
//

import Foundation
import Observation
import SwiftUI

enum HermesServiceReachability: String {
    case up
    case down

    var color: Color {
        switch self {
        case .up:
            .igOnlineGreen
        case .down:
            .igDestructive
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .up:
            "up"
        case .down:
            "down"
        }
    }
}

@MainActor
@Observable
final class HermesStatusMonitor {
    var apiServerStatus: HermesServiceReachability = .down
    var companionStatus: HermesServiceReachability = .down

    private let refreshInterval: Duration = .seconds(10)

    func runStatusLoop(
        apiSettings: HermesAPISettings,
        companionSettings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) async {
        while !Task.isCancelled {
            await refresh(
                apiSettings: apiSettings,
                companionSettings: companionSettings,
                identityState: identityState
            )

            do {
                try await Task.sleep(for: refreshInterval)
            } catch {
                return
            }
        }
    }

    func refresh(
        apiSettings: HermesAPISettings,
        companionSettings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) async {
        async let apiIsUp = checkAPIServer(settings: apiSettings)
        async let companionIsUp = checkCompanion(settings: companionSettings, identityState: identityState)

        apiServerStatus = await apiIsUp ? .up : .down
        companionStatus = await companionIsUp ? .up : .down
    }

    private func checkAPIServer(settings: HermesAPISettings) async -> Bool {
        guard let url = statusURL(from: settings.baseURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3
        if settings.apiKey.isEmpty == false {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await HermesNetworkSessionFactory.session(for: settings).data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<500).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    private func checkCompanion(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async -> Bool {
        guard identityState.isEnrolled else { return false }
        do {
            let result: HermesCompanionHelloResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "hello",
                payload: Optional<String>.none
            )
            return result.serverName.isEmpty == false
        } catch {
            return false
        }
    }

    private func statusURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let normalized = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        return URL(string: normalized + "/models") ?? URL(string: normalized)
    }
}

struct HermesStatusBand: View {
    @Bindable var statusMonitor: HermesStatusMonitor

    var body: some View {
        HStack(spacing: 12) {
            HermesStatusLED(label: "API", status: statusMonitor.apiServerStatus)
            HermesStatusLED(label: "Mac", status: statusMonitor.companionStatus)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.hermesDivider.opacity(0.6))
                .frame(height: 0.5)
        }
    }
}

private struct HermesStatusLED: View {
    let label: String
    let status: HermesServiceReachability

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 9, height: 9)
                .shadow(color: status.color.opacity(0.45), radius: 3)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.hermesSecondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) status \(status.accessibilityLabel)")
    }
}
