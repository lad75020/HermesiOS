//
//  HermesSchedulesPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesSchedulesPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    /// The gateway-first panel retains this view only for unmigrated operations.
    var gatewayManagedControls = false

    @State private var showCreateForm = false
    @State private var editingJob: HermesCompanionScheduleCronJob?
    @State private var confirmDeleteJobID: String?
    @State private var newName = ""
    @State private var newPrompt = ""
    @State private var newDeliver = "local"
    @State private var frequency: ScheduleFrequency = .daily
    @State private var minutesInterval = "30"
    @State private var hourlyInterval = "1"
    @State private var dailyTime = "09:00"
    @State private var weeklyDay = "1"
    @State private var weeklyTime = "09:00"
    @State private var customCron = ""
    @State private var newProvider = ""
    @State private var newModel = ""
    @State private var newBaseURL = ""
    @State private var editName = ""
    @State private var editRawSchedule = ""
    @State private var editPrompt = ""
    @State private var editDeliver = "local"
    @State private var editProvider = ""
    @State private var editModel = ""
    @State private var editBaseURL = ""

    private let deliverTargets: [(String, String)] = [
        ("local", "Local"), ("origin", "Origin"), ("telegram", "Telegram"), ("discord", "Discord"),
        ("slack", "Slack"), ("whatsapp", "WhatsApp"), ("signal", "Signal"), ("matrix", "Matrix"),
        ("mattermost", "Mattermost"), ("email", "Email"), ("webhook", "Webhook"), ("sms", "SMS"),
        ("homeassistant", "Home Assistant"), ("dingtalk", "DingTalk"), ("feishu", "Feishu"), ("wecom", "WeCom")
    ]

    private var builtSchedule: String {
        switch frequency {
        case .minutes:
            return "every \(minutesInterval)m"
        case .hourly:
            return "every \(hourlyInterval)h"
        case .daily:
            let parts = dailyTime.split(separator: ":")
            let hour = parts.first.map(String.init) ?? "09"
            let minute = parts.dropFirst().first.map(String.init) ?? "00"
            return "\(minute) \(hour) * * *"
        case .weekly:
            let parts = weeklyTime.split(separator: ":")
            let hour = parts.first.map(String.init) ?? "09"
            let minute = parts.dropFirst().first.map(String.init) ?? "00"
            return "\(minute) \(hour) * * \(weeklyDay)"
        case .custom:
            return customCron.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var isScheduleValid: Bool {
        switch frequency {
        case .custom:
            return customCron.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .minutes:
            return (Int(minutesInterval) ?? 0) > 0
        case .hourly:
            return (Int(hourlyInterval) ?? 0) > 0
        default:
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Authentication Required",
                    systemImage: "person.badge.key",
                    description: Text("Authenticate with HermesHostCompanion before listing or editing scheduled jobs on the macOS host.")
                )
            } else {
                HermesStatusRow(items: [
                    .init(title: "Jobs", value: "\(companionRuntime.schedules.count)", accent: .igActionBlue),
                    .init(title: "Active", value: "\(companionRuntime.schedules.filter { $0.state == "active" }.count)", accent: .igOnlineGreen),
                    .init(title: "Paused", value: "\(companionRuntime.schedules.filter { $0.state == "paused" }.count)", accent: .igGradOrange)
                ])

                if !companionRuntime.lastErrorMessage.isEmpty {
                    Text(companionRuntime.lastErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.igDestructive)
                }

                HermesSectionCard("Schedule Controls") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(gatewayManagedControls
                             ? "Companion supports creation with model/provider overrides, full editing, and Run Now. Return to the gateway list for basic creation, pause, resume, or delete."
                             : "Create, pause, resume, trigger, and delete Hermes cron jobs stored on the macOS host.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)
                        if !companionRuntime.schedulesFilePath.isEmpty {
                            Text(companionRuntime.schedulesFilePath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.hermesSecondaryText)
                                .textSelection(.enabled)
                        }
                        HStack {
                            Button {
                                companionRuntime.refreshSchedules(settings: companionSettings, identityState: companionEnrollment.identityState)
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .hermesGlassProminentButton()

                            Button {
                                showCreateForm.toggle()
                            } label: {
                                Label(showCreateForm ? "Hide Form" : "New Task", systemImage: showCreateForm ? "xmark" : "plus")
                            }
                            .hermesGlassButton()
                        }
                    }
                }

                HermesSectionCard("Scheduled Jobs") {
                    if companionRuntime.schedules.isEmpty {
                        ContentUnavailableView(
                            "No Scheduled Jobs",
                            systemImage: "calendar.badge.plus",
                            description: Text("Create the first task or refresh from the host cron registry.")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(companionRuntime.schedules) { job in
                                scheduleCard(job)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if companionEnrollment.identityState.isEnrolled, companionRuntime.schedules.isEmpty {
                companionRuntime.refreshSchedules(settings: companionSettings, identityState: companionEnrollment.identityState)
            }
        }
        .sheet(isPresented: $showCreateForm) {
            NavigationStack {
                ScrollView {
                    createForm
                        .padding()
                }
                .navigationTitle("New Scheduled Task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCreateForm = false }
                    }
                }
            }
        }
        .sheet(item: $editingJob) { job in
            NavigationStack {
                ScrollView {
                    editForm(job)
                        .padding()
                }
                .navigationTitle("Edit Scheduled Task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingJob = nil }
                    }
                }
                .onAppear { loadEditForm(job) }
            }
        }
    }

    private var createForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Name", text: $newName)
                .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                .textInputAutocapitalization(.sentences)
            Picker("Frequency", selection: $frequency) {
                ForEach(ScheduleFrequency.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch frequency {
                case .minutes:
                    Picker("Interval", selection: $minutesInterval) {
                        ForEach(["5", "10", "15", "30", "45"], id: \.self) { value in
                            Text("Every \(value) minutes").tag(value)
                        }
                    }
                case .hourly:
                    Picker("Interval", selection: $hourlyInterval) {
                        ForEach(["1", "2", "3", "4", "6", "8", "12"], id: \.self) { value in
                            Text("Every \(value) hour\(value == "1" ? "" : "s")").tag(value)
                        }
                    }
                case .daily:
                    TextField("Execution time (HH:mm)", text: $dailyTime)
                        .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                case .weekly:
                    Picker("Weekday", selection: $weeklyDay) {
                        Text("Monday").tag("1")
                        Text("Tuesday").tag("2")
                        Text("Wednesday").tag("3")
                        Text("Thursday").tag("4")
                        Text("Friday").tag("5")
                        Text("Saturday").tag("6")
                        Text("Sunday").tag("0")
                    }
                    TextField("Execution time (HH:mm)", text: $weeklyTime)
                        .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                case .custom:
                    TextField("Cron expression, e.g. 0 9 * * *", text: $customCron)
                        .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Use 5-field cron syntax, or Hermes recurring interval expressions like every 30m / every 2h.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }
            }

            Text("Schedule: \(builtSchedule.isEmpty ? "—" : builtSchedule)")
                .font(.caption.monospaced())
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)

            TextEditor(text: $newPrompt)
                .frame(minHeight: 92)
                .scrollContentBackground(.hidden)
                .background(Color.hermesSurfaceInput)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            Text("Prompt to run when this schedule fires.")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            Picker("Deliver to", selection: $newDeliver) {
                ForEach(deliverTargets, id: \.0) { target in
                    Text(target.1).tag(target.0)
                }
            }
            .pickerStyle(.menu)

            schedulePinFields(provider: $newProvider, model: $newModel, baseURL: $newBaseURL)

            if gatewayManagedControls {
                Text("For a task using the selected profile's model and provider, use New Task in the gateway list. Companion creation requires a model or provider override.")
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)
            }

            HStack {
                Button {
                    guard !gatewayManagedControls || optionalNewValue(newProvider) != nil || optionalNewValue(newModel) != nil else { return }
                    let prompt = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    companionRuntime.createSchedule(
                        schedule: builtSchedule,
                        prompt: prompt.isEmpty ? nil : prompt,
                        name: name.isEmpty ? nil : name,
                        deliver: newDeliver == "local" ? nil : newDeliver,
                        provider: optionalNewValue(newProvider),
                        model: optionalNewValue(newModel),
                        baseUrl: optionalNewValue(newBaseURL),
                        settings: companionSettings,
                        identityState: companionEnrollment.identityState
                    )
                    resetForm()
                    showCreateForm = false
                } label: {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .hermesGlassProminentButton()
                .disabled(!isScheduleValid || (gatewayManagedControls && optionalNewValue(newProvider) == nil && optionalNewValue(newModel) == nil))

                Button("Reset") { resetForm() }
                    .hermesGlassButton()
            }
        }
    }

    private func editForm(_ job: HermesCompanionScheduleCronJob) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The card shows Hermes's friendly schedule. This editor always sends the raw scheduler expression.")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
            TextField("Name", text: $editName)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
            TextField("Raw schedule", text: $editRawSchedule)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextEditor(text: $editPrompt)
                .frame(minHeight: 92)
                .scrollContentBackground(.hidden)
                .background(Color.hermesSurfaceInput)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Picker("Deliver to", selection: $editDeliver) {
                ForEach(deliverTargets, id: \.0) { target in
                    Text(target.1).tag(target.0)
                }
            }
            .pickerStyle(.menu)
            schedulePinFields(provider: $editProvider, model: $editModel, baseURL: $editBaseURL)
            Text("Leave a field unchanged to preserve it. Clear a populated pin deliberately to send Hermes an explicit empty value.")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
            Button {
                companionRuntime.editSchedule(
                    jobID: job.id,
                    schedule: changed(editRawSchedule, from: job.rawSchedule),
                    prompt: changed(editPrompt, from: job.prompt),
                    name: changed(editName, from: job.name == "(unnamed)" ? "" : job.name),
                    deliver: changed(editDeliver, from: job.deliver.first ?? "local"),
                    provider: changed(editProvider, from: job.provider ?? ""),
                    model: changed(editModel, from: job.model ?? ""),
                    baseUrl: changed(editBaseURL, from: job.baseUrl ?? ""),
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
                editingJob = nil
            } label: {
                Label("Save Changes", systemImage: "checkmark.circle.fill")
            }
            .hermesGlassProminentButton()
            .disabled(editRawSchedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func schedulePinFields(provider: Binding<String>, model: Binding<String>, baseURL: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Provider pin (optional)", text: provider)
                .hermesRuntimeInput(background: Color.hermesSurfaceInput, border: Color.white.opacity(0.12))
            TextField("Model pin (optional)", text: model)
                .hermesRuntimeInput(background: Color.hermesSurfaceInput, border: Color.white.opacity(0.12))
            TextField("Base URL pin (optional)", text: baseURL)
                .hermesRuntimeInput(background: Color.hermesSurfaceInput, border: Color.white.opacity(0.12))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private func loadEditForm(_ job: HermesCompanionScheduleCronJob) {
        editName = job.name == "(unnamed)" ? "" : job.name
        editRawSchedule = job.rawSchedule
        editPrompt = job.prompt
        editDeliver = job.deliver.first ?? "local"
        editProvider = job.provider ?? ""
        editModel = job.model ?? ""
        editBaseURL = job.baseUrl ?? ""
    }

    private func optionalNewValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func changed(_ value: String, from original: String) -> String? {
        value == original ? nil : value
    }

    private func scheduleCard(_ job: HermesCompanionScheduleCronJob) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(.headline)
                    Text(job.schedule)
                        .font(.caption.monospaced())
                        .foregroundStyle(.hermesSecondaryText)
                        .textSelection(.enabled)
                }
                Spacer()
                Text(job.state.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor(for: job).opacity(0.18))
                    .foregroundStyle(statusColor(for: job))
                    .clipShape(Capsule())
            }

            if !job.prompt.isEmpty {
                Text(job.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.hermesSurfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Next: \(formatScheduleTime(job.nextRunAt))", systemImage: "calendar.badge.clock")
                if let lastRunAt = job.lastRunAt {
                    Label("Last: \(formatScheduleTime(lastRunAt))", systemImage: "clock.arrow.circlepath")
                }
                if let repeatInfo = job.repeatInfo, let times = repeatInfo.times {
                    Label("Runs: \(repeatInfo.completed)/\(times)", systemImage: "repeat")
                }
                if job.deliver.isEmpty == false && !(job.deliver.count == 1 && job.deliver[0] == "local") {
                    Label("Deliver: \(job.deliver.joined(separator: ", "))", systemImage: "paperplane")
                }
                if job.skills.isEmpty == false {
                    Label("Skills: \(job.skills.joined(separator: ", "))", systemImage: "square.stack.3d.up")
                }
                if let provider = job.provider, !provider.isEmpty {
                    Label("Provider: \(provider)", systemImage: "network")
                }
                if let model = job.model, !model.isEmpty {
                    Label("Model: \(model)", systemImage: "cpu")
                }
                if let baseURL = job.baseUrl, !baseURL.isEmpty {
                    Label("Base URL: \(baseURL)", systemImage: "link")
                }
            }
            .font(.caption)
            .foregroundStyle(.hermesSecondaryText)

            if let lastError = job.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.igDestructive.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack {
                if !gatewayManagedControls, job.state != "completed" {
                    Button {
                        if job.state == "paused" {
                            companionRuntime.resumeSchedule(jobID: job.id, settings: companionSettings, identityState: companionEnrollment.identityState)
                        } else {
                            companionRuntime.pauseSchedule(jobID: job.id, settings: companionSettings, identityState: companionEnrollment.identityState)
                        }
                    } label: {
                        Label(job.state == "paused" ? "Resume" : "Pause", systemImage: job.state == "paused" ? "play.fill" : "pause.fill")
                    }
                    .hermesGlassButton()
                }

                if job.state == "active" {
                    Button {
                        companionRuntime.triggerSchedule(jobID: job.id, settings: companionSettings, identityState: companionEnrollment.identityState)
                    } label: {
                        Text("Run Now")
                    }
                    .hermesGlassButton()
                }

                Button {
                    loadEditForm(job)
                    editingJob = job
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .hermesGlassButton()

                Spacer()

                if !gatewayManagedControls {
                    Button(role: .destructive) {
                        confirmDeleteJobID = job.id
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .hermesGlassButton()
                }
            }
        }
        .padding(14)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .confirmationDialog("Delete scheduled task?", isPresented: Binding(get: { confirmDeleteJobID == job.id }, set: { if !$0 { confirmDeleteJobID = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                companionRuntime.removeSchedule(jobID: job.id, settings: companionSettings, identityState: companionEnrollment.identityState)
                confirmDeleteJobID = nil
            }
            Button("Cancel", role: .cancel) { confirmDeleteJobID = nil }
        } message: {
            Text("This removes the cron job from the host Hermes scheduler.")
        }
    }

    private func statusColor(for job: HermesCompanionScheduleCronJob) -> Color {
        switch job.state {
        case "active": return .igOnlineGreen
        case "paused": return .igGradOrange
        case "completed": return .hermesSecondaryText
        default: return .igActionBlue
        }
    }

    private func formatScheduleTime(_ value: String?) -> String {
        guard let value, value.isEmpty == false else { return "—" }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return value
    }

    private func resetForm() {
        newName = ""
        newPrompt = ""
        newDeliver = "local"
        newProvider = ""
        newModel = ""
        newBaseURL = ""
        frequency = .daily
        minutesInterval = "30"
        hourlyInterval = "1"
        dailyTime = "09:00"
        weeklyDay = "1"
        weeklyTime = "09:00"
        customCron = ""
    }

    private enum ScheduleFrequency: String, CaseIterable, Identifiable {
        case minutes
        case hourly
        case daily
        case weekly
        case custom

        var id: String { rawValue }
        var label: String {
            switch self {
            case .minutes: return "Minutes"
            case .hourly: return "Hourly"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .custom: return "Custom"
            }
        }
    }
}
