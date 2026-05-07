//
//  HermesObservabilityPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesObservabilityPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var lineCountText = "200"

    private var canUseCompanion: Bool {
        companionEnrollment.identityState.isEnrolled
    }

    private var displayedLogText: String {
        if companionRuntime.observabilityLogContent.isEmpty {
            return canUseCompanion ? "Press Refresh to load Hermes logs." : "Authenticate the macOS Host Companion to read Hermes logs."
        }
        return companionRuntime.observabilityLogContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hermes logs")
                        .font(.headline)
                    Text(companionRuntime.observabilityLogPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.hermesSecondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    applyLineCountText()
                    companionRuntime.refreshHermesLog(
                        settings: companionSettings,
                        identityState: companionEnrollment.identityState
                    )
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(canUseCompanion == false || companionRuntime.isBusy)
            }

            Picker("Log", selection: Binding(
                get: { companionRuntime.observabilityLogKind },
                set: { newLog in
                    companionRuntime.setHermesObservabilityLog(
                        newLog,
                        settings: companionSettings,
                        identityState: companionEnrollment.identityState
                    )
                }
            )) {
                ForEach(HermesCompanionLogKind.allCases) { log in
                    Text(log.label).tag(log)
                }
            }
            .pickerStyle(.segmented)
            .disabled(canUseCompanion == false || companionRuntime.isBusy)

            VStack(alignment: .leading, spacing: 6) {
                Text("Final lines to load")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                TextField("200", text: $lineCountText)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .hermesRuntimeInput()
                    .onSubmit { applyLineCountText() }
                    .onChange(of: lineCountText) { _, _ in
                        applyLineCountText(allowPartial: true)
                    }
                Text("Allowed range: 10–10000. Default: 200.")
                    .font(.caption2)
                    .foregroundStyle(.hermesSecondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Displaying \(companionRuntime.observabilityLogKind.label)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)
                    Spacer()
                    if companionRuntime.observabilityLoadedLineCount > 0 {
                        Text("\(companionRuntime.observabilityLoadedLineCount) lines")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.hermesSecondaryText)
                    }
                }

                ScrollView([.vertical, .horizontal]) {
                    Text(displayedLogText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 168, maxHeight: 168)
                .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.hermesDivider.opacity(0.7), lineWidth: 1)
                )
            }

            if let updatedAt = companionRuntime.observabilityUpdatedAt {
                Text("Last refreshed: \(updatedAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.hermesSecondaryText)
            }

            if companionRuntime.lastErrorMessage.isEmpty == false {
                Text(companionRuntime.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.igDestructive)
            }
        }
        .task {
            lineCountText = String(companionRuntime.observabilityLineCount)
            if canUseCompanion && companionRuntime.observabilityLogContent.isEmpty {
                companionRuntime.refreshHermesLog(
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
            }
        }
    }

    private func applyLineCountText(allowPartial: Bool = false) {
        let digits = lineCountText.filter(\.isNumber)
        if digits != lineCountText {
            lineCountText = digits
        }
        guard let value = Int(digits) else {
            if allowPartial { return }
            companionRuntime.setHermesObservabilityLineCount(200)
            lineCountText = "200"
            return
        }
        let clamped = min(max(value, 10), 10_000)
        companionRuntime.setHermesObservabilityLineCount(clamped)
        if allowPartial == false || value != clamped {
            lineCountText = String(clamped)
        }
    }
}
