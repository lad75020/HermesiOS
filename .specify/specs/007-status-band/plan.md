# Plan: Status Band

## Technical Context

- The status system is implemented primarily in `HermesiOS/HermesStatusBand.swift`:
  - `HermesServiceReachability` models per-service connectivity (`up`, `down`).
  - `HermesStatusMonitor` tracks raw status and active-probe flags for API, companion, and dashboard checks.
  - `HermesStatusBand` renders three service LEDs (`API`, `Mac`, `DASH`) and accepts external activity signals.
  - `HermesStatusLED` handles static vs. active flashing visuals and accessibility labels.
- Status monitoring orchestration runs in `ContentView.swift`:
  - `statusMonitor` is owned as `@State`.
  - `.task(id: statusLoopKey)` starts `statusMonitor.runStatusLoop(...)` when the app is active and not on splash.
  - `.onChange(of: scenePhase)` triggers immediate `statusMonitor.refresh(...)` when returning to active.
- Active work channels are derived in `ContentView.swift` (`apiChannelActive`, `companionChannelActive`, `dashboardChannelActive`) from session/runtime activity and passed into `WorkspaceSidebar`.
- `WorkspaceSidebar` includes the band in the left rail at top-of-list, so it should remain visible and responsive across desktop and iPad modes where the sidebar is shown.
- Existing behavior dependencies are:
  - API endpoint settings (`HermesAPISettings`, plus `HermesHostEndpoints`).
  - Companion session/identity state (`HermesCompanionEnrollmentSession`, `HermesCompanionSettings`).
  - Dashboard session state (`HermesDashboardHistorySearchSession`).

## Approach

- Verify and tighten the status-band behaviors directly in the current component implementation.
- Keep implementation scoped to `HermesiOS/HermesStatusBand.swift` and minimal call sites in `ContentView.swift`/`HermesiOS/HermesWorkspaceNavigation.swift`.
- Make clarifications explicit before implementation tasks so no unresolved placeholders remain.
- Ensure accessibility and visual states remain non-intrusive and readable in both light/dark themes.
- Confirm status band state cannot mask critical session error indicators; both service status and per-section completion/failure indicators in navigation must remain visible.

## Implementation Plan by Phase

### Phase 0 — Research and Decision Capture

- Resolve clarifications for probe endpoints and activity semantics against existing behavior.
- Record design decisions in `research.md`, including alternatives considered and rationale.
- Confirm behavior when monitor inputs are missing/invalid (empty host, invalid URL, un-enrolled companion).

### Phase 1 — Design Artifacts

- Draft `research.md`:
  - Service-check semantics and allowed success statuses.
  - Probe failure handling and retry policy.
  - Accessibility semantics for LEDs under active and failure states.
- Draft `data-model.md` with:
  - `HermesServiceReachability` values and invariants.
  - `HermesStatusMonitor` lifecycle fields and transition rules.
  - UI mapping into `HermesStatusBand` and `HermesStatusLED`.
- Draft `quickstart.md` with manual validation steps for both idle and active probe states.
- Verify no external API contract is added, since this is an internal UI status surface.

### Phase 2 — Readiness and Consistency Checks

- Validate all generated artifacts for unresolved `NEEDS CLARIFICATION` markers:
  - `plan.md`
  - `research.md`
  - `data-model.md`
  - `quickstart.md`
- Confirm the new plan content is aligned with current code usage in:
  - `HermesiOS/HermesStatusBand.swift`
  - `HermesiOS/ContentView.swift`
  - `HermesiOS/HermesWorkspaceNavigation.swift`
- Re-check that no broad scope items (beyond status-band UI + monitor wiring) are introduced.

## Acceptance Conditions

- The following files exist under `.specify/specs/007-status-band/`:
  - `plan.md`
  - `research.md`
  - `data-model.md`
  - `quickstart.md`
- No unresolved `NEEDS CLARIFICATION` markers in the artifacts above.
- Plan explicitly documents how active work cues map to service LEDs and how errors remain visually distinct.
- Accessibility labels and fallback behavior are defined for missing/unknown service status.
- Scope is limited to status-band feature surfaces and monitor plumbing only.

## Planned Gates (default gates; no project constitution file found)

- Security: no sensitive credential material appears in status outputs or visible labels.
- Reliability: probe failures must not block main navigation rendering.
- Usability: service health and active work state are distinguishable at a glance.
- Accessibility: screen reader can state service name and state (up/down/active).
- Scope control: do not broaden into chat/runtime feature changes in this phase.
- Build/readiness: artifacts prepared before implementation can begin.