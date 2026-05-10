import SwiftUI

struct HermesKnowledgeEraserPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    private var isDisabled: Bool {
        companionEnrollment.identityState.isEnrolled == false || companionRuntime.isBusy
    }

    private var selectedCount: Int {
        companionRuntime.knowledgeEraserSelectedItemIDs.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Two-step cleanup for memories, user profile blocks, and skill files. Scan first, review every candidate, then archive and erase only checked items.")
                .font(.subheadline)
                .foregroundStyle(.hermesSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Topic to erase")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                TextField("Describe the topic, project, person, or workflow to forget", text: $companionRuntime.knowledgeEraserTopic, axis: .vertical)
                    .lineLimit(2...4)
                    .hermesRuntimeInput()
                    .disabled(isDisabled)
            }

            HStack(spacing: 12) {
                Button {
                    companionRuntime.scanKnowledgeEraser(
                        topic: companionRuntime.knowledgeEraserTopic,
                        settings: companionSettings,
                        identityState: companionEnrollment.identityState
                    )
                } label: {
                    Label("Find Items", systemImage: "magnifyingglass")
                }
                .hermesGlassProminentButton()
                .disabled(isDisabled || companionRuntime.knowledgeEraserTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    companionRuntime.eraseSelectedKnowledgeItems(
                        settings: companionSettings,
                        identityState: companionEnrollment.identityState
                    )
                } label: {
                    Label("Erase & Achive", systemImage: "archivebox.fill")
                }
                .hermesGlassButton()
                .tint(.igDestructive)
                .disabled(isDisabled || selectedCount == 0)
            }

            if companionEnrollment.identityState.isEnrolled == false {
                Text("Authenticate the Mac companion before scanning host Hermes files.")
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
            }

            if companionRuntime.knowledgeEraserOperationOutput.isEmpty == false {
                Text(companionRuntime.knowledgeEraserOperationOutput)
                    .font(.caption.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hermesLiquidGlass(cornerRadius: 14, tint: .white.opacity(0.04))
            }

            if companionRuntime.knowledgeEraserItems.isEmpty == false {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Review candidates")
                            .font(.headline)
                        Spacer()
                        Text("\(selectedCount)/\(companionRuntime.knowledgeEraserItems.count) selected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.hermesSecondaryText)
                    }

                    ForEach(companionRuntime.knowledgeEraserItems) { item in
                        KnowledgeEraserItemRow(
                            item: item,
                            isSelected: Binding(
                                get: { companionRuntime.knowledgeEraserSelectedItemIDs.contains(item.id) },
                                set: { isSelected in
                                    if isSelected {
                                        companionRuntime.knowledgeEraserSelectedItemIDs.insert(item.id)
                                    } else {
                                        companionRuntime.knowledgeEraserSelectedItemIDs.remove(item.id)
                                    }
                                }
                            )
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct KnowledgeEraserItemRow: View {
    let item: HermesCompanionKnowledgeEraserItem
    @Binding var isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $isSelected)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.kind.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.igActionBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.igActionBlue.opacity(0.12))
                        .clipShape(Capsule())
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("\(Int(item.confidence * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.hermesSecondaryText)
                }

                Text(item.preview)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(item.path) · \(item.location)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 16, tint: isSelected ? Color.igDestructive.opacity(0.08) : Color.white.opacity(0.03))
    }
}
