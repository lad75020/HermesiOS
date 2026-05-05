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
    var isAPIProbeActive = false
    var isCompanionProbeActive = false

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
        isAPIProbeActive = true
        defer { isAPIProbeActive = false }

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
        isCompanionProbeActive = true
        defer { isCompanionProbeActive = false }

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
    var apiChannelActive = false
    var companionChannelActive = false
    @Namespace private var ledNamespace

    var body: some View {
        HermesGlassEffectContainer(spacing: 14) {
            HStack(spacing: 10) {
                HermesStatusLED(
                    label: "API",
                    status: statusMonitor.apiServerStatus,
                    isActive: apiChannelActive || statusMonitor.isAPIProbeActive
                )
                .hermesGlassEffectID("led.api", in: ledNamespace)

                HermesStatusLED(
                    label: "Mac",
                    status: statusMonitor.companionStatus,
                    isActive: companionChannelActive || statusMonitor.isCompanionProbeActive
                )
                .hermesGlassEffectID("led.mac", in: ledNamespace)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.hermesDivider.opacity(0.22))
                .frame(height: 0.5)
        }
    }
}

private struct HermesStatusLED: View {
    let label: String
    let status: HermesServiceReachability
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            let flashOn = Int(timeline.date.timeIntervalSinceReferenceDate * 9) % 2 == 0
            let activeColor = flashOn ? Color.igOnlineGreen : Color.igOnlineGreen.opacity(0.38)
            let ledColor = isActive ? activeColor : status.color

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(ledColor)
                    .frame(width: 3, height: 14)
                    .shadow(color: ledColor.opacity(isActive ? 0.45 : 0.22), radius: isActive ? 4 : 2)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .hermesLiquidGlass(cornerRadius: 12, tint: ledColor.opacity(0.08), interactive: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) status \(isActive ? "active" : status.accessibilityLabel)")
    }
}
