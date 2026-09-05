import SwiftUI

/// A fresh creation draft, never populated from truncated gateway job summaries.
struct HermesGatewayScheduleCreationForm: View {
    let profileName: String
    let submit: (HermesTUICronDraft) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var draft = HermesTUICronDraft()
    @State private var submission: Task<Void, Never>?
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected Profile") {
                    Text(profileName)
                    Label("TUI Gateway", systemImage: "terminal")
                    Text("Uses this profile's configured model and provider. No Host Companion connection is needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Task") {
                    TextField("Name (optional)", text: $draft.name)
                    TextField("Schedule", text: $draft.schedule)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Examples: 0 9 * * * for daily at 09:00, or every 30m. Times use the host's scheduling timezone. The gateway validates the expression.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $draft.prompt)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Scheduled task prompt")
                    Text("Prompt to run when the schedule fires.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Execution") {
                    TextField("Delivery target", text: $draft.deliver)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("local saves output on the host. You can enter another configured Hermes delivery target.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Run limit (optional)", text: $draft.repeatLimit)
                        .keyboardType(.numberPad)
                    Text("Leave empty for the schedule's default, use 0 to repeat indefinitely, or a positive number to limit runs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Carry context between runs", isOn: $draft.continuity)
                }
                Section {
                    if let message = draft.validationMessage {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                    if !errorMessage.isEmpty {
                        Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
                    }
                    if submission != nil { ProgressView("Creating scheduled task") }
                    Button("Create Task", systemImage: "plus.circle.fill") { create() }
                        .disabled(submission != nil || draft.validationMessage != nil)
                }
            }
            .disabled(submission != nil)
            .navigationTitle("New Scheduled Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(submission != nil)
                }
            }
            .interactiveDismissDisabled(submission != nil)
            .onDisappear { submission?.cancel() }
        }
    }

    private func create() {
        guard submission == nil, draft.validationMessage == nil else { return }
        let submittedDraft = draft
        errorMessage = ""
        submission = Task {
            defer { submission = nil }
            let failure = await submit(submittedDraft)
            guard !Task.isCancelled else { return }
            if let failure {
                errorMessage = failure
            } else {
                dismiss()
            }
        }
    }
}
