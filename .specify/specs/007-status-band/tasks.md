# Tasks: Status Band

## Phase 1: Setup
- [X] T001 Validate `.specify/feature.json` points to `./.specify/specs/007-status-band` and verify `git branch --show-current` is `feature/time-machine-status-band`.
- [X] T002 [P] Confirm required artifacts exist: `./.specify/specs/007-status-band/spec.md`, `./.specify/specs/007-status-band/plan.md`, `./.specify/specs/007-status-band/research.md`, `./.specify/specs/007-status-band/data-model.md`, `./.specify/specs/007-status-band/quickstart.md`.
- [X] T003 Update `.specify/specs/007-status-band/quickstart.md` if any planning/clarification gaps are still unresolved before implementation.
- [X] T004 Verify no `.specify/extensions.yml` hook file is present; if present, confirm no mandatory pre-tasks hook is blocking execution in `./.specify/extensions.yml`.

## Phase 2: Foundational
- [X] T005 Audit the existing status orchestration lifecycle in `./HermesiOS/HermesiOS/ContentView.swift` and identify where `statusMonitor.runStatusLoop(...)` and `statusMonitor.refresh(...)` are started and retriggered.
- [X] T006 [P] Review model relationships in `./HermesiOS/HermesiOS/HermesStatusBand.swift` and `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift` to ensure `HermesStatusMonitor`, `HermesStatusBand`, and channel activity booleans form a single source of truth.
- [X] T007 [P] Capture current baseline behavior in `./.specify/specs/007-status-band/quickstart.md` for visibility, active cues, failure overlays, and accessibility.
- [X] T008 Confirm the status data path from `HermesAPISettings`, `HermesCompanionSettings`, and `dashboardPort` reads into `./HermesiOS/HermesiOS/ContentView.swift` and ends in the status UI call in `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift`.
- [X] T009 Create a focused implementation checklist in `./.specify/specs/007-status-band/checklists/implementation-notes.md` for scope and non-goals before coding.

## Phase 3: User Story 1 — I can see whether all three services are reachable from the top status band
- [X] T010 [US1] Verify/implement three fixed indicators and labels in `./HermesiOS/HermesiOS/HermesStatusBand.swift` for API, Mac, and DASH.
- [X] T011 [US1] Confirm `HermesServiceReachability` colors in `./HermesiOS/HermesiOS/HermesStatusBand.swift` keep API/Mac/DASH distinction and remain visible in both themes.
- [X] T012 [US1] Ensure `ContentView` continuously feeds `dashboardURLString` and status settings into `statusMonitor.refresh(...)` via `./HermesiOS/HermesiOS/ContentView.swift` so band values reflect current host settings.
- [X] T013 [US1] Ensure `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift` keeps labels hidden by default in narrow layouts only if required by design and does not alter status semantics.
- [X] T014 [US1] [P] Verify top-level layout in `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift` keeps the band visible and readable across compact and regular sidebar presentations.
- [X] T015 [US1] Validate that status band rendering is non-blocking and constant-time per refresh cycle in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.

## Phase 4: User Story 2 — I can spot when a service is temporarily unreachable
- [X] T016 [US2] Verify or implement `HermesStatusMonitor.checkAPIServer(settings:)` fallback behavior in `./HermesiOS/HermesiOS/HermesStatusBand.swift` so invalid/malformed API URLs return `.down`.
- [X] T017 [US2] Verify or implement `HermesStatusMonitor.checkCompanion(settings:identityState:)` to require enrollment before probing in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- [X] T018 [US2] Verify or implement `HermesStatusMonitor.checkDashboard(baseURLString:apiSettings:)` so blank/invalid dashboard URL resolves to `.down` without crashing in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- [X] T019 [US2] [P] Add a quick negative-path verification script step in `./.specify/specs/007-status-band/quickstart.md` for API-only and dashboard-only outages.
- [X] T020 [US2] Verify `statusMonitor.refresh(...)` sets all three statuses from each probe pass so partial failures do not block unrelated indicators in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.

## Phase 5: User Story 3 — I can see which channel is actively working during probes
- [X] T021 [US3] Validate `apiChannelActive`, `companionChannelActive`, and `dashboardChannelActive` in `./HermesiOS/HermesiOS/ContentView.swift` are derived from real in-flight activity flags.
- [X] T022 [US3] Verify `HermesStatusLED` combines explicit activity flags with probe state (`statusMonitor.isAPIProbeActive`, `isCompanionProbeActive`, `isDashboardProbeActive`) in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- [X] T023 [US3] [P] Confirm active animation is only used for `status == .up` in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- [X] T024 [US3] Add active-work coverage to one API and one dashboard path in `./.specify/specs/007-status-band/quickstart.md` and record expected animation timing.
- [X] T025 [US3] Verify active flags are cleared on cancellation and do not remain stuck after task cancel in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.

## Phase 6: User Story 4 — I can notice completion/failure cues alongside status and navigation signals
- [X] T026 [US4] Verify `shouldShowPhoneConnectionIssueOverlay` remains independent from sidebar warning indicators in `./HermesiOS/HermesiOS/ContentView.swift`.
- [X] T027 [US4] Verify completion/failure state updates to sidebar rows in `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift` are not suppressed by status band rendering updates.
- [X] T028 [US4] [P] Confirm `WorkspaceSidebar` still shows read/unread and failure badges when status monitor is rapidly toggling in `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift`.
- [X] T029 [US4] Verify history/chat/response completion paths clear status indicators only through their own sources and not through service status transitions in `./HermesiOS/HermesiOS/ContentView.swift`.
- [X] T030 [US4] Add explicit cross-check steps in `./.specify/specs/007-status-band/quickstart.md` for simultaneous status/failure scenarios.

## Phase 7: User Story 5 — I can understand state quickly, including accessibility and graceful fallback
- [X] T031 [US5] Validate accessibility labels in `./HermesiOS/HermesiOS/HermesStatusBand.swift` announce service name and active/up/down state clearly.
- [X] T032 [US5] Verify contrast and readability of LED and labels in both light/dark for each service state in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- [X] T033 [US5] Verify unknown/empty/undefined statuses are represented as `.down` with safe UI fallback and no hidden LED in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- [X] T034 [US5] Add an explicit fallback-path check for malformed values in `./.specify/specs/007-status-band/quickstart.md` covering startup with blank endpoints and no companion enrollment.
- [X] T035 [US5] [P] Verify `HermesStatusBand` preserves animation and readability with sidebar compact mode in `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift`.

## Phase 8: Polish & Cross-Cutting
- [ ] T036 Update `./.specify/specs/007-status-band/quickstart.md` with final smoke-test evidence links and exact verification results for each story.
- [X] T037 [P] Update `./.specify/specs/007-status-band/checklists/requirements.md` if implementation introduces new edge cases.
- [X] T038 Review `./.specify/specs/007-status-band/checklists/requirements.md` and confirm no remaining blockers.
- [X] T039 Run the task-list validator from `./.hermes/skills/local/speckit-tasks/scripts/validate_tasks.py` against `./.specify/specs/007-status-band/tasks.md` and reconcile any count or phase-label mismatches.

## Dependencies
- T001 and T002 precede all other tasks.
- T005 through T009 gate User Story 1 implementation tasks.
- T010 and T011 precede the active-cue story (`T012`-`T025`).
- T020 must be true before completion criteria reporting in US2 tasks.
- T021, T022, and T025 gate User Story 3 activity verification.
- T026 through T030 are independent of US1/US2 implementation details and validate cross-cutting signal behavior.
- Polish tasks should run only after first pass implementation for all user stories.

## Independent test criteria
- US1: launch `./.specify/specs/007-status-band/quickstart.md` scenario 1 and confirm three distinct LEDs for API/Mac/DASH are visible in `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift`.
- US2: execute unreachable API/dashboard simulation in `./.specify/specs/007-status-band/quickstart.md` and confirm down state is shown while other services remain unchanged in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- US3: trigger API, companion, and dashboard work flows in `./.specify/specs/007-status-band/quickstart.md` and confirm matching active cues in `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift` and `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- US4: complete and fail one action in responses/chat/history and confirm status and completion/failure indicators remain simultaneously visible in `./HermesiOS/HermesiOS/ContentView.swift` and `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift`.
- US5: run accessibility and malformed-value checks from `./.specify/specs/007-status-band/quickstart.md` and confirm no regressions in `./HermesiOS/HermesiOS/HermesStatusBand.swift`.

## Parallel execution examples
- T005, T006, and T008 can run while T010, T011, and T021 progress.
- T013 and T014 can be executed independently of core network probe changes.
- T017, T018, and T020 can be done in parallel after probe baseline is stabilized.
- T019 and T024 can be prepared independently for test-path evidence capture.
- T027 and T028 can run concurrently with T029 when verifying cross-cutting cues.

## Implementation strategy
- Start with setup/foundational tasks, then execute User Story 1 and 2 to stabilize baseline status and failure semantics.
- Complete User Story 3 and User Story 4 activity/failure integration next, then finalize accessibility and fallback behavior in User Story 5.
- Finish with polish tasks and validator checks before moving to `/speckit-implement`.