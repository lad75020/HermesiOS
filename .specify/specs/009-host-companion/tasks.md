# Tasks: Host Companion Service

## Phase 1: Setup
- [ ] T001 Validate `.specify/feature.json` points to `./.specify/specs/009-host-companion` and verify `git branch --show-current` is `feature/time-machine-host-companion`.
- [ ] T002 [P] Confirm required artifacts exist: `./.specify/specs/009-host-companion/spec.md`, `./.specify/specs/009-host-companion/plan.md`, `./.specify/specs/009-host-companion/research.md`, `./.specify/specs/009-host-companion/data-model.md`, and `./.specify/specs/009-host-companion/quickstart.md`.
- [ ] T003 Check if `./.specify/extensions.yml` exists and report mandatory pre-hooks if any.
- [ ] T004 Verify there are no unresolved planning markers such as unresolved clarifications or placeholder text in `./.specify/specs/009-host-companion/spec.md`, `./.specify/specs/009-host-companion/research.md`, and `./.specify/specs/009-host-companion/data-model.md`.
- [ ] T005 Confirm implementation artifacts referenced by the plan exist or are explicitly deferred in `./.specify/specs/009-host-companion/plan.md`.

## Phase 2: Foundational
- [ ] T006 [P] Build a single operation-catalog matrix from `./HermesHostCompanion/CompanionProtocol.swift` and `./HermesHostCompanion/CompanionServer.swift` by route handler name.
- [ ] T007 Confirm `./HermesiOS/HermesCompanionClient.swift` dispatches companion envelopes through `HermesCompanionSessionFactory.request` for each operation in scope.
- [ ] T008 Verify `./HermesHostCompanion/CompanionServer.swift` keeps request handling resilient so every malformed frame returns `invalid_request` without closing the socket.
- [ ] T009 Verify `./HermesHostCompanion/CompanionServer.swift` maps startup/listener errors into `.failed` with `lastErrorMessage` and clear endpoint recovery path.
- [ ] T010 Confirm secret handling behavior in `./HermesHostCompanion/CompanionServer.swift` and `./HermesiOS/HermesCompanionClient.swift` avoids plaintext logs for device credentials.
- [ ] T011 Validate onboarding + approval state persistence helpers in `./HermesHostCompanion/CompanionServer.swift` and `./HermesiOS/HermesCompanionClient.swift` for stale/duplicate records.
- [ ] T012 Audit service-port and companion endpoint persistence in `./HermesHostCompanion/HermesHostCompanionApp.swift`, `./HermesiOS/HermesHostEndpoints.swift`, and `./HermesiOS/HermesSettingsView.swift`.

## Phase 3: User Story 1 — Trust connection path and server lifecycle
- [ ] T013 [US1] Verify host startup sequence and lifecycle states (`stopped`, `starting`, `running`, `failed`) in `./HermesHostCompanion/CompanionServer.swift` and `./HermesHostCompanion/HermesHostCompanionApp.swift`.
- [ ] T014 [US1] Verify listener host/port sanitization and advertised websocket URL generation in `./HermesHostCompanion/CompanionProtocol.swift` and `./HermesHostCompanion/CompanionServer.swift`.
- [ ] T015 [US1] Confirm server exposes stable `hello` payload capabilities from `./HermesHostCompanion/CompanionProtocol.swift` and matching route handlers in `./HermesHostCompanion/CompanionServer.swift`.
- [ ] T016 [US1] Verify unsupported/unknown operations return typed protocol errors via `./HermesHostCompanion/CompanionServer.swift` instead of silent no-op.
- [ ] T017 [US1] Verify companion status and last error fields are surfaced in host UI state from `./HermesHostCompanion/HermesHostCompanionApp.swift`.

## Phase 4: User Story 2 — Onboard and approve trusted devices
- [ ] T018 [US2] Verify pairing code generation, rotation, and expiry behavior in `./HermesHostCompanion/CompanionServer.swift`.
- [ ] T019 [US2] Verify `enroll_device` path parses onboarding payload and persists `CompanionAuthorizedDeviceRecord` in `./HermesHostCompanion/CompanionServer.swift`.
- [ ] T020 [US2] Verify `check_device_approval` returns `pending`, `approved`, and `revoked` transitions in `./HermesHostCompanion/CompanionServer.swift`.
- [ ] T021 [US2] Verify UI-facing device list and approval actions consume `CompanionAuthorizedDeviceRecord` data in `./HermesHostCompanion/HermesHostCompanionApp.swift`.
- [ ] T022 [US2] Verify iOS enrollment parsing and identity state updates in `./HermesiOS/HermesCompanionClient.swift`.
- [ ] T023 [US2] Verify rejected/expired onboarding codes produce clear, deterministic error results in `./HermesHostCompanion/CompanionServer.swift` and `./HermesiOS/HermesCompanionClient.swift`.

## Phase 5: User Story 3 — Enforce approval before privileged actions
- [ ] T024 [US3] Verify auth gate in `./HermesHostCompanion/CompanionServer.swift` allows only `enroll_device` and `check_device_approval` without enrollment.
- [ ] T025 [US3] Ensure every protected route checks `authenticate(...)` and secret fingerprint match in `./HermesHostCompanion/CompanionServer.swift`.
- [ ] T026 [US3] Verify unauthorized actions return `device_not_approved` in `./HermesHostCompanion/CompanionServer.swift` and do not mutate any state.
- [ ] T027 [US3] Add/verify explicit error code map for `device_not_approved`, `invalid_request`, and `unknown_operation` in `./HermesHostCompanion/CompanionProtocol.swift`.
- [ ] T028 [US3] Verify iOS runtime session keeps privileged calls gated by `identityState.isEnrolled` in `./HermesiOS/HermesCompanionClient.swift` and `./HermesiOS/HermesCompanionPanel.swift`.

## Phase 6: User Story 4 — Browse and read targets safely
- [ ] T029 [US4] Verify target list and read operations return profile/workspace-aware entries in `./HermesHostCompanion/CompanionTargetRegistry.swift`.
- [ ] T030 [US4] Validate path normalization and metadata mapping in `./HermesHostCompanion/CompanionTargetRegistry.swift`.
- [ ] T031 [US4] Verify iOS target list/read presentation consumes stable payload fields in `./HermesiOS/HermesCompanionClient.swift` and `./HermesiOS/HermesCompanionPanel.swift`.
- [ ] T032 [US4] Ensure unknown targets produce typed validation errors in `./HermesHostCompanion/CompanionTargetRegistry.swift`.

## Phase 7: User Story 5 — Validate and edit targets with revision safety
- [ ] T033 [US5] Verify target validation returns actionable diagnostics and preserves payloads when invalid in `./HermesHostCompanion/CompanionTargetRegistry.swift`.
- [ ] T034 [US5] Confirm `write_target` requires exact `expectedRevision` and rejects mismatches in `./HermesHostCompanion/CompanionTargetRegistry.swift`.
- [ ] T035 [US5] Verify backup creation and backup metadata updates happen before target commit in `./HermesHostCompanion/CompanionTargetRegistry.swift`.
- [ ] T036 [US5] Verify `write_target` updates revision and returns new revision in `./HermesHostCompanion/CompanionTargetRegistry.swift`.
- [ ] T037 [US5] Verify backup list/read/restore flow in `./HermesHostCompanion/CompanionTargetRegistry.swift` and `./HermesiOS/HermesCompanionClient.swift`.
- [ ] T038 [US5] Verify stale reads and duplicate write races are surfaced with clear errors in `./HermesHostCompanion/CompanionTargetRegistry.swift` and `./HermesiOS/HermesCompanionPanel.swift`.

## Phase 8: User Story 6 — Browse host files and download content reliably
- [ ] T039 [US6] Verify directory browse returns normalized path + metadata in `./HermesHostCompanion/CompanionFileDownloadRegistry.swift`.
- [ ] T040 [US6] Verify `download_file` returns single-shot payload with stable byte count and MIME metadata in `./HermesHostCompanion/CompanionFileDownloadRegistry.swift`.
- [ ] T041 [US6] Verify chunked download flow (`download_file_info`, `download_file_chunk`) with `offset` and `isComplete` in `./HermesHostCompanion/CompanionFileDownloadRegistry.swift`.
- [ ] T042 [US6] Ensure large-file pagination continues after partial chunking without regressions in `./HermesHostCompanion/CompanionFileDownloadRegistry.swift` and `./HermesiOS/HermesCompanionClient.swift`.
- [ ] T043 [US6] Verify path-denied/error states are surfaced as typed file errors and do not crash session in `./HermesHostCompanion/CompanionFileDownloadRegistry.swift`.

## Phase 9: User Story 7 — Service/runtime management under companion trust
- [ ] T044 [US7] Verify service status and control routes in `./HermesHostCompanion/CompanionServiceRegistry.swift`.
- [ ] T045 [US7] Verify restart/start/stop return updated state and output in `./HermesHostCompanion/CompanionServiceRegistry.swift` and `./HermesiOS/HermesCompanionPanel.swift`.
- [ ] T046 [US7] Verify Tailnet serve status + toggle routes in `./HermesHostCompanion/CompanionTailscaleServeRegistry.swift`.
- [ ] T047 [US7] Verify service-port state and companion network config reads/writes in `./HermesHostCompanion/HermesHostCompanionApp.swift` and `./HermesiOS/HermesSettingsPersistence.swift`.
- [ ] T048 [US7] Verify provider/model/profile/toolset/memory/runtime management list/read/update routes in `./HermesHostCompanion/CompanionProviderRegistry.swift`, `./HermesHostCompanion/CompanionModelRegistry.swift`, `./HermesHostCompanion/CompanionProfileRegistry.swift`, `./HermesHostCompanion/CompanionToolsetRegistry.swift`, and `./HermesHostCompanion/CompanionMemoryRegistry.swift`.
- [ ] T049 [US7] Verify logs/gateway/knowledge and install operation read flows in `./HermesHostCompanion/CompanionLogRegistry.swift`, `./HermesHostCompanion/CompanionGatewayRegistry.swift`, `./HermesHostCompanion/CompanionKnowledgeEraserRegistry.swift`, and `./HermesHostCompanion/CompanionGitRegistry.swift`.
- [ ] T050 [US7] Verify scheduled, profile, and MCP operations are authenticated and non-destructive in `./HermesHostCompanion/CompanionScheduleRegistry.swift`, `./HermesHostCompanion/CompanionMCPRegistry.swift`, and `./HermesHostCompanion/CompanionProfileRegistry.swift`.
- [ ] T051 [US7] Verify unsupported runtime operation payloads return typed errors in `./HermesHostCompanion/CompanionServer.swift` and `./HermesiOS/HermesCompanionClient.swift`.

## Phase 10: Polish & Cross-Cutting Concerns
- [ ] T052 Update runtime panel error and status surfaces for new typed errors in `./HermesiOS/HermesiOS/HermesCompanionPanel.swift`.
- [ ] T053 Verify deterministic request id + request-response correlation for representative flows in `./HermesHostCompanion/CompanionProtocol.swift` and `./HermesiOS/HermesCompanionClient.swift`.
- [ ] T054 Verify lifecycle and security events are logged consistently in `./HermesHostCompanion/CompanionServer.swift` and `./HermesHostCompanion/HermesHostCompanionApp.swift`.
- [ ] T055 [P] Run `./Volumes/WDBlack4TB/.hermes/skills/local/speckit-tasks/scripts/validate_tasks.py` and fix any validation issues in `./.specify/specs/009-host-companion/tasks.md`.
- [ ] T056 [P] Re-run and update acceptance criteria in `./.specify/specs/009-host-companion/quickstart.md` after host companion implementation passes key flows.
- [ ] T057 [P] Record blockers and any remaining risks in `./.specify/specs/009-host-companion/checklists/requirements.md` if behavior could not be fully validated.

## Dependencies
- T001, T002, T003, and T004 gate all implementation tasks.
- T006, T007, and T008 run before story execution to lock protocol and routing assumptions.
- US1 tasks T013-T017 require host lifecycle and protocol setup from T006-T012.
- US2 tasks T018-T023 require successful auth-store state and pairing baseline from T011 and T018.
- US3 tasks T024-T028 rely on US1/US2 auth decisions from T020-T023.
- US4, US5, and US6 tasks require auth gating from US3 and route validation in T024-T027.
- US7 tasks T044-T051 require all foundational routing and auth checks from T006-T012 and T024-T028.
- Polish tasks T052-T057 run after story implementation.

## Independent test criteria
- US1: companion server moves through lifecycle states correctly and returns stable `listenerDescription`, `hello` payload, and readable startup errors in `./HermesHostCompanion/CompanionServer.swift`.
- US2: pairing and approval flows accept a valid onboarding code, persist pending state, and show approved state in both mac and iOS clients after host approval in `./HermesHostCompanion/CompanionServer.swift` and `./HermesiOS/HermesCompanionClient.swift`.
- US3: any protected operation without approval returns an authorization error and does not perform write mutations in `./HermesHostCompanion/CompanionServer.swift`.
- US4: target list/read APIs return normalized, profile-aware payloads and clear missing-target errors in `./HermesHostCompanion/CompanionTargetRegistry.swift`.
- US5: stale write attempts fail with `revisionMismatch` and successful writes create/attach backups with new revision in `./HermesHostCompanion/CompanionTargetRegistry.swift`.
- US6: directory browsing and large download chunking complete with correct offset/isComplete metadata without dropped sessions in `./HermesHostCompanion/CompanionFileDownloadRegistry.swift`.
- US7: service and runtime-management operations return typed success/error responses and update UI-facing state in `./HermesiOS/HermesCompanionPanel.swift`.

## Parallel execution examples
- T002 and T003 can run in parallel.
- T006, T007, and T008 can be done in parallel to lock protocol and routing assumptions.
- T024 and T030 can run in parallel while auth and target-read fixes are isolated.
- T033, T034, and T035 can run in parallel for target mutation safety once route baseline is stable.
- T039 and T044 can run independently (filesystem vs service lifecycle).

## Implementation strategy
- Complete setup checks first, then establish the authorization and protocol foundations.
- Implement User Story 1 and User Story 2 before all privileged write/edit flows.
- Complete target editing/validation before file and service-management flows to avoid compounding trust-state regressions.
- End with polish tasks: validation script, quickstart updates, and risk logging.
