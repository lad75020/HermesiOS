# Tasks: Office & Claw3D WebView Integration

## Phase 1: Setup
- [ ] T001 Validate `.specify/feature.json` points to `./.specify/specs/008-office-claw3d-integration` and verify `git branch --show-current` is `feature/time-machine-office`.
- [ ] T002 [P] Confirm required artifacts exist: `./.specify/specs/008-office-claw3d-integration/spec.md`, `./.specify/specs/008-office-claw3d-integration/plan.md`, `./.specify/specs/008-office-claw3d-integration/research.md`, `./.specify/specs/008-office-claw3d-integration/data-model.md`, `./.specify/specs/008-office-claw3d-integration/quickstart.md`.
- [ ] T003 Confirm no mandatory pre-tasks hook is blocking execution in `./.specify/extensions.yml` (or document that no hook file is present).
- [ ] T004 Update quickstart and notes with any setup ambiguities found before implementation in `./.specify/specs/008-office-claw3d-integration/quickstart.md`.
- [ ] T005 Verify there are no unresolved placeholders or temporary planning markers in `./.specify/specs/008-office-claw3d-integration/spec.md`.
- [ ] T006 Confirm design artifacts and requirement assumptions are sufficient in `./.specify/specs/008-office-claw3d-integration/research.md` and `./.specify/specs/008-office-claw3d-integration/data-model.md`.

## Phase 2: Foundational
- [ ] T007 Audit `./HermesiOS/HermesiOS/ContentView.swift` and `./HermesiOS/HermesiOS/HermesiOSApp.swift` for all web-workspace handoff points (web tab entry, status loops, and AppStorage keys).
- [ ] T008 [P] Audit `./HermesiOS/HermesiOS/HermesHostEndpoints.swift` usage from `ContentView.swift`, `HermesWebBrowserView.swift`, and `HermesOfficeView.swift` to confirm a single host/port source.
- [ ] T009 Inspect persistence keys used by `./HermesiOS/HermesiOS/HermesWebBrowserView.swift` (`hermes.web.open.pages`, `hermes.web.selected.page`, `hermes.web.history.roots`, `hermes.web.url`) and confirm backward-compatibility strategy in `./.specify/specs/008-office-claw3d-integration/plan.md`.
- [ ] T010 Verify `HermesOfficeSettingsSection` is rendered from `./HermesiOS/HermesiOS/HermesSettingsView.swift` under the Office section and remains non-blocking in `./HermesiOS/HermesiOS/HermesOfficeView.swift`.
- [ ] T011 Record the baseline behavior for office launch, status readiness visibility, and malformed URL handling in `./.specify/specs/008-office-claw3d-integration/quickstart.md`.
- [ ] T012 [P] Confirm `./HermesiOS/HermesiOS/HermesWebBrowserDeckStore` restores a valid `selectedWorkspaceID` when the saved active ID is stale in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T013 Confirm status semantics and endpoint derivation for office and dashboard share explicit helper methods in `./HermesiOS/HermesiOS/HermesHostEndpoints.swift`.

## Phase 3: User Story 1 — Launch Office quickly from the Web tab
- [ ] T014 [US1] Verify `HermesWebBrowserView` shows the dedicated Office shortcut action and label from the header in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T015 [US1] Verify `loadOfficeURL()` navigates the active workspace to `officeURLString` using shared normalization rules in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T016 [US1] Ensure Office button navigation updates `activeWorkspace.urlString` and persistence in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T017 [US1] [P] Verify `./HermesiOS/HermesiOS/HermesHostEndpoints.swift` can produce Office URL via `httpURLString(host:port:)` for both host-only and host:port inputs.
- [ ] T018 [US1] Add an explicit accessibility label for Office launch feedback state in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.

## Phase 4: User Story 2 — Show Office readiness clearly before using it
- [ ] T019 [US2] Validate `HermesOfficeSettingsSection` polls Office reachability from `./HermesiOS/HermesiOS/HermesOfficeView.swift` and reports non-blocking status.
- [ ] T020 [US2] Review and refine status labeling in `./HermesiOS/HermesiOS/HermesOfficeView.swift` to ensure clear actionable text for reachable/unreachable office targets.
- [ ] T021 [US2] Ensure `HermesiOS/HermesiOS/HermesSettingsView.swift` keeps the Office section updated with current mac host/port context.
- [ ] T022 [US2] [P] Ensure Office status updates propagate after host/port changes driven from `./HermesiOS/HermesiOS/ContentView.swift` and `./HermesiOS/HermesiOS/HermesSettingsView.swift`.
- [ ] T023 [US2] Add manual verification steps for status transitions in `./.specify/specs/008-office-claw3d-integration/quickstart.md`.

## Phase 5: User Story 3 — Preserve and restore web workspaces across relaunch
- [ ] T024 [US3] Verify `HermesWebBrowserDeckStore.init()` restores workspaces from `hermes.web.open.pages` in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T025 [US3] Inspect and harden `HermesWebBrowserDeckStore.persistOpenPages()` so blank URLs are never persisted in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T026 [US3] Implement URL validation in `HermesiOS/HermesiOS/HermesWebBrowserView.swift` so malformed/blank restored entries are skipped and not selected for active loading.
- [ ] T027 [US3] Ensure `loadAllUnloadedWebPages()` only restores tabs with valid `http/https` URLs in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T028 [US3] Verify selected-tab persistence uses a valid existing workspace in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift` and `./HermesiOS/HermesiOS/ContentView.swift`.
- [ ] T029 [US3] Ensure workspace URLs from history root suggestions are normalized before persistence in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T030 [US3] [P] Validate restore behavior when stale URLs include scheme-less or empty values using a focused regression check in `./.specify/specs/008-office-claw3d-integration/quickstart.md`.

## Phase 6: User Story 4 — Keep browsing usable when Office/bridge is unavailable
- [ ] T031 [US4] Verify current web-tab behavior when Office target is unreachable does not clear other tabs or disable global navigation in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T032 [US4] Add scoped failure messaging for Office shortcut paths so the tab remains available for other URLs in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T033 [US4] Add a retry path from Office failure messaging to re-attempt Office launch in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T034 [US4] Add a non-blocking error affordance for Claw3D workflow unavailability when office path indicates adapter not ready in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T035 [US4] [P] Update `./.specify/specs/008-office-claw3d-integration/quickstart.md` with failure-mode expectations for Office down and Claw3D adapter unavailable.

## Phase 7: User Story 5 — Switch between dashboard and office quickly from the same controls
- [ ] T036 [US5] Verify dashboard shortcut remains available and independent from Office shortcut in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T037 [US5] Ensure switching dashboard/office updates the active workspace and URL field consistently in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- [ ] T038 [US5] Confirm host/port changes trigger correct destination updates for both buttons in `./HermesiOS/HermesiOS/ContentView.swift` and `./HermesiOS/HermesiOS/HermesHostEndpoints.swift`.
- [ ] T039 [US5] Add a regression check for mixed service selection in `./.specify/specs/008-office-claw3d-integration/quickstart.md`.

## Phase 8: Polish & Cross-Cutting Concerns
- [ ] T040 Add a concise implementation note summary to `./.specify/specs/008-office-claw3d-integration/checklists/requirements.md` and remove newly introduced blockers.
- [ ] T041 Update `./.specify/specs/008-office-claw3d-integration/implementation-notes.md` (or create it) with any service-readiness or workspace restore caveats.
- [ ] T042 [P] Verify accessibility labels for new warning/retry states in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift` and `./HermesiOS/HermesiOS/HermesOfficeView.swift`.
- [ ] T043 [P] Run `./Volumes/WDBlack4TB/.hermes/skills/local/speckit-tasks/scripts/validate_tasks.py ././.specify/specs/008-office-claw3d-integration/tasks.md` and fix any format/count mismatches.
- [ ] T044 Re-run quickstart acceptance flows and summarize results in `./.specify/specs/008-office-claw3d-integration/quickstart.md`.

## Dependencies
- T001 and T002 precede all implementation tasks.
- T007 through T013 gate user-story execution for reliable foundation.
- US1 tasks T014-T018 require endpoint derivation audit from T008/T013.
- US2 task T020 depends on status baseline from T010/T019.
- US3 tasks T024-T030 require restored-workspace baseline from T009.
- US4 tasks T031-T035 should not run before US1 shortcut wiring and US2 status wiring are stable.
- US5 tasks T036-T039 require stable destination derivation from `HermesHostEndpoints` and shortcut plumbing.
- Polish tasks T040-T044 run only after story implementation is first-pass complete.

## Independent test criteria
- US1: pressing the Office button in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift` opens the configured Office URL and keeps the URL bar synchronized.
- US2: `./HermesiOS/HermesiOS/HermesOfficeView.swift` shows a clear reachable/unreachable Office state before launching Office links from the web tab.
- US3: after relaunch, `./HermesiOS/HermesiOS/HermesWebBrowserView.swift` restores multiple workspaces and re-selects a valid active tab without loading malformed entries.
- US4: unreachable Office or bridge availability failures show recoverable guidance while other web browsing remains functional in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`.
- US5: dashboard and office shortcuts can be used back-to-back and continue to respect the current host and port values from `./HermesiOS/HermesiOS/ContentView.swift`.

## Parallel execution examples
- T002 and T007 can run in parallel.
- T009, T011, and T021 can run in parallel for baseline documentation and status validation.
- T024 through T027 can run independently if workspace restore is isolated from shortcut and status work.
- T038 and T040 can run while retry-state updates are implemented.

## Implementation strategy
- Start with setup and foundation tasks to freeze cross-file contracts.
- Implement US1 and US2 first so core office navigation and readiness visibility are available.
- Implement US3 and US5 around restore and destination controls before adding scoped failure messaging in US4.
- Finish with polish checks, accessibility coverage, and final validation.