# Tasks: Settings & Configuration

## Phase 1: Setup
- [ ] T001 Validate `.specify/feature.json` points to `specs/006-settings` and compare with current branch `feature/time-machine-settings`.
- [ ] T002 [P] Confirm required artifacts exist: `./.specify/specs/006-settings/spec.md`, `./.specify/specs/006-settings/plan.md`, `./.specify/specs/006-settings/research.md`, `./.specify/specs/006-settings/data-model.md`, `./.specify/specs/006-settings/quickstart.md`.
- [ ] T003 Document unresolved planning gaps (if any) in `./.specify/specs/006-settings/research.md` before implementation begins.
- [ ] T004 Confirm no blocking hook directives exist in `./.specify/extensions.yml` (or note none found).

## Phase 2: Foundational
- [ ] T005 Audit persistence boundaries for settings and secure values in `./HermesiOS/HermesSettingsPersistence.swift` and `./HermesiOS/HermesHostEndpoints.swift`.
- [ ] T006 [P] Review cross-screen derived URL usage to avoid divergence in `./HermesiOS/ContentView.swift` and `./HermesiOS/HermesSettingsView.swift`.
- [ ] T007 Confirm secret storage strategy remains Keychain-first for token and companion secret in `./HermesiOS/HermesiOSApp.swift` and `./HermesiOS/HermesSettingsPersistence.swift`.
- [ ] T008 Run a baseline smoke check from `./HermesiOS/HermesiOSApp.swift` startup path to ensure no startup regressions from settings wiring changes.

## Phase 3: User Story 1 — API base URL and key editing
- [ ] T009 [US1] [P] Confirm API settings load/save flow in `./HermesiOS/HermesSettingsPersistence.swift` and `./HermesiOS/ContentView.swift` for `HermesAPISettings`.
- [ ] T010 [US1] Implement/verify API base URL normalization in `./HermesiOS/HermesHostEndpoints.swift` for host-only inputs, explicit host:port, and `/v1` defaults.
- [ ] T011 [US1] [P] Validate Hermes API URL construction and endpoint suffix handling in `./HermesiOS/HermesResponsesAPI.swift`.
- [ ] T012 [US1] Expose and bind the API key field to `apiSettings.apiKey` in `./HermesiOS/HermesSettingsView.swift` using existing normalization behavior.
- [ ] T013 [US1] Preserve bearer token handling in redacted form when persisting in `./HermesiOS/HermesSettingsPersistence.swift` and ensure no raw token leaks in summaries.
- [ ] T014 [US1] Confirm API base URL edit immediately updates dependent tabs through `./HermesiOS/ContentView.swift` and `./HermesiOS/HermesChatConsoleView.swift`.

## Phase 4: User Story 2 — Companion endpoint and trust policy
- [ ] T015 [US2] Verify transport warning/error behavior for insecure HTTP/WS API and companion endpoints in `./HermesiOS/HermesHostEndpoints.swift` and `./HermesiOS/HermesSettingsView.swift`.
- [ ] T016 [US2] Ensure warning state is surfaced for both companion and API sections with explicit redaction/feedback text in `./HermesiOS/HermesSettingsView.swift`.
- [ ] T017 [US2] [P] Add/update endpoint normalization for companion websocket URLs in `./HermesiOS/HermesHostEndpoints.swift` to keep protocol/scheme transitions safe.
- [ ] T018 [US2] Validate self-signed policy state through `./HermesiOS/HermesResponsesAPI.swift` and `./HermesiOS/HermesSettingsView.swift` for local/.ts.net exceptions.
- [ ] T019 [US2] Confirm plaintext checks never block local encrypted flows after valid localhost/tailnet host resolution in `./HermesiOS/HermesHostEndpoints.swift`.

## Phase 5: User Story 3 — Saved hosts and active host switching
- [ ] T020 [US3] Audit saved host model updates in `./HermesiOS/HermesCompanionClient.swift` and `./HermesiOS/HermesSettingsPersistence.swift` for `HermesCompanionSavedConnection` and `HermesCompanionIdentityState`.
- [ ] T021 [US3] Implement/verify host list rendering, active host selection, check-approval, and forget actions in `./HermesiOS/HermesSettingsView.swift` and `./HermesiOS/HermesiOSApp.swift`.
- [ ] T022 [US3] [P] Ensure host switching updates runtime and settings state via `syncActiveCompanionConnectionToSettings()` in `./HermesiOS/HermesSettingsView.swift`.
- [ ] T023 [US3] Validate `HermesCompanionEnrollmentSession.activeConnectionID` and `HermesSettingsPersistence.saveActiveCompanionConnectionID` consistency in `./HermesiOS/HermesCompanionClient.swift`.
- [ ] T024 [US3] Verify per-connection device secret mapping and cleanup paths in `./HermesiOS/HermesSettingsPersistence.swift`.
- [ ] T025 [US3] Add manual verification steps in `./.specify/specs/006-settings/quickstart.md` for switching/forgetting saved hosts and approval refresh.

## Phase 6: User Story 4 — Service ports and selection behavior
- [ ] T026 [US4] Validate auto-fetched service ports in `./HermesiOS/ContentView.swift` and `./HermesiOS/HermesCompanionRuntimeSession`-driven API in `./HermesiOS/HermesCompanionClient.swift`.
- [ ] T027 [US4] Update settings-driven service port UI and selection in `./HermesiOS/HermesSettingsView.swift` including `tailscaleServePorts` derivation.
- [ ] T028 [US4] [P] Verify dashboard/tailscale/office ports persist through `@AppStorage` keys in `./HermesiOS/HermesHostEndpoints.swift` and `./HermesiOS/HermesSettingsView.swift`.
- [ ] T029 [US4] Implement safe fallback/legacy migration from deprecated URL keys in `./HermesiOS/HermesSettingsView.swift` (`legacyDashboardURL`, `legacyOfficeURL`).
- [ ] T030 [US4] Confirm companion port edits and status refresh path in `./HermesiOS/HermesSettingsView.swift` and `./HermesiOS/HermesCompanionClient.swift`.

## Phase 7: User Story 5 — Theme persistence
- [ ] T031 [US5] Confirm `HermesAppTheme` enum and `appTheme` AppStorage path in `./HermesiOS/HermesAppTheme.swift` and `./HermesiOS/ContentView.swift`.
- [ ] T032 [US5] Ensure settings theme picker updates and persists immediately in `./HermesiOS/HermesiOSApp.swift` and `./HermesiOS/HermesSettingsView.swift`.
- [ ] T033 [US5] Validate theme propagation after restart across top-level navigation and status UI in `./HermesiOS/HermesStatusBand.swift` and `./HermesiOS/HermesWorkspaceNavigation.swift`.

## Phase 8: User Story 6 — Workspace path persistence
- [ ] T034 [US6] Verify workspace path editing, display, and persistence in `./HermesiOS/HermesSettingsView.swift` and `./HermesiOS/HermesSettingsPersistence.swift`.
- [ ] T035 [US6] Confirm runtime panels and model/profiles panels consume workspace path from `companionSettings.hermesWorkspacePath` in `./HermesiOS/HermesModelsPanel.swift` and `./HermesiOS/HermesSkillsPanel.swift`.
- [ ] T036 [US6] Ensure onboarding payload hydration updates workspace path in `./HermesiOS/HermesSettingsView.swift` without overwriting user edits unexpectedly.
- [ ] T037 [US6] Validate companion calls receiving workspace path use the same canonical path source from `./HermesiOS/HermesCompanionClient.swift` requests.

## Phase 7: User Story 7 — Resilience and persistence across launch
- [ ] T038 [US7] Verify complete settings restore path on app launch in `./HermesiOS/ContentView.swift` and `./HermesiOS/HermesSettingsPersistence.swift`.
- [ ] T039 [US7] Add/verify invalid input handling for malformed host/port values in `./HermesiOS/HermesHostEndpoints.swift` and `./HermesiOS/HermesSettingsView.swift`.
- [ ] T040 [US7] [P] Verify stale active host / revoked pairing states are handled gracefully in `./HermesiOS/HermesCompanionClient.swift` and status surfaces.
- [ ] T041 [US7] Confirm restart state and session continuity for selected host/runtime tab in `./HermesiOS/ContentView.swift`.
- [ ] T042 [US7] Add manual acceptance checks for persistence and recovery in `./.specify/specs/006-settings/quickstart.md`.

## Phase 10: Polish & Cross-Cutting Concerns
- [ ] T043 [P] Update `./.specify/specs/006-settings/implementation-notes.md` with final completion evidence and any implementation caveats.
- [ ] T044 Update `./.specify/specs/006-settings/checklists/requirements.md` if new blockers or clarifications were introduced and remove stale placeholders.
- [ ] T045 Run the task-list validator with `./.specify/specs/006-settings/tasks.md` summary counts and regenerate any missing checklist rows in `./.specify/specs/006-settings/tasks.md`.
- [ ] T046 [P] Run the quickstart acceptance paths and attach a summary in `./.specify/specs/006-settings/quickstart.md`.

## Dependencies
- T009 and T010 precede all User Story 1 tasks.
- T015 requires the security checks validated in T010.
- T020 through T024 gate host switching behavior in User Story 3.
- T026 through T030 depend on T019 for safe endpoint handling.
- T031 through T033 are independent of network-facing tasks and can run in parallel with T034 and T037.
- User Story 7 tasks T038-T042 depend on completion of US1 through US6 data wiring.

## Independent test criteria
- US1: update `HermesiOS/HermesSettingsView.swift` and verify the API tab immediately reaches an API endpoint derived from edited host and token.
- US2: intentionally configure plaintext host in `HermesiOS/HermesSettingsView.swift` and verify warning text appears.
- US3: save two Host Companion entries in `HermesiOS/HermesSettingsPersistence.swift` and switch between them in `HermesiOS/HermesSettingsView.swift`.
- US4: set malformed ports in `HermesiOS/HermesSettingsView.swift` and confirm fallback behavior and service URL recovery.
- US5: persist theme via `HermesiOS/HermesAppTheme.swift` and verify `preferredColorScheme` follows it after relaunch.
- US6: update workspace path in `HermesiOS/HermesSettingsView.swift` and confirm companion call payloads include the same path.
- US7: relaunch after settings changes and validate API, companion, ports, and theme restore via `HermesiOS/ContentView.swift`.

## Parallel execution examples
- T005, T006, T007 can be done independently and merged before core story implementation.
- T009, T011, T014 can run in parallel if backend/API paths are isolated.
- T020, T024, T037 can be handled independently from UI work if state handling and persistence are partitioned.

## Implementation strategy
- Implement in priority order by story, keeping setup/foundation tasks first and leaving User Story 7 verification for last.
- Start with normalization/safety (US1/US2), then host/session state (US3), then ports/theme/workspace, and finish with persistence resilience (US7).
- Keep each story independently testable against the quickstart script in `./.specify/specs/006-settings/quickstart.md`.
