# Plan: Office & Claw3D WebView Integration

## Technical Context

- Entry points:
  - `HermesiOS/ContentView.swift`
    - Derives `officeURLString` from `HermesHostEndpoints.httpURLString(host: macHost, port: officePort)`.
    - Passes `officeURLString` and `dashboardURLString` into `HermesWebBrowserView`.
    - Refreshes host ports from `HermesCompanionRuntimeSession.refreshServicePorts(...)` (including `officePort`).
    - Preloads previously saved web pages by calling `webBrowserStore.loadAllUnloadedWebPages()` in `.task {}`.
  - `HermesiOS/HermesWebBrowserView.swift`
    - Displays web workspace header with dedicated office shortcut action.
    - Manages `deckStore` selection, URL entry, back/reload, multi-workspace tabs/icons.
    - Loads dashboard/office shortcuts through `loadShortcutURL(_:)` and stores typed/loaded URLs.
  - `HermesiOS/HermesWebBrowserDeckStore`
    - Persists and restores workspaces through `UserDefaults` keys:
      - `hermes.web.open.pages`
      - `hermes.web.selected.page`
      - `hermes.web.history.roots`
      - legacy `hermes.web.url`.
    - Handles new window requests and workspace selection/persistence.
  - `HermesiOS/HermesWebBrowserWorkspace` and `HermesiOS/HermesWebBrowserStore`
    - Own page state, navigation controls, favicon fetch, and page change propagation.
  - `HermesiOS/HermesOfficeView.swift`
    - `HermesOfficeSettingsSection` continuously checks `officeURLString` with HTTP GET (status 200 check).
    - Uses `@AppStorage` for `hermesMacHostStorageKey` and `hermesOfficePortStorageKey`.
  - `HermesiOS/HermesHostEndpoints.swift`
    - Canonical host/port normalization and URL construction helpers used for office/dashboard/API endpoints.

- Existing behavior to preserve:
  - Multi-workspace tabs and session restoration across app relaunch.
  - URL normalization (`https://` fallback) and history root persistence.
  - Non-blocking service checks where possible.
  - Existing dashboard tab and settings path for office service management.

## Approach

- Keep feature scope internal to web workspace + office launch/feedback behavior.
- Reuse existing `WebBrowser` and `HermesWebBrowserDeckStore` architecture.
- Extend behavior only where requirement explicitly asks for resilient failure UX, clearer Office/bridge readiness signaling, and state consistency.
- Ensure non-Office flows remain fully usable when Office/bridge service checks fail.
- Avoid adding protocol/API surface changes beyond what is needed for in-app status presentation.

## Implementation Plan by Phase

### Phase 0 — Research and Decision Capture

- Resolve ambiguity around Office reachability and user messaging by reviewing current status check and header behavior.
- Verify how host/port refresh from companion impacts currently loaded pages and settings.
- Validate that web workspace restore semantics remain stable when tabs contain stale/malformed URLs.
- Record outcomes in `research.md` with alternatives and rationale.

### Phase 1 — Design Artifacts

- Draft `research.md`:
  - Office reachability semantics (status true/false mapping).
  - Failure-handling strategy for Office/Claw3D unavailable while keeping browser usable.
  - Host/port update and open-page restore consistency.
- Draft `data-model.md`:
  - Extend/confirm entities for `HermesOfficeSettingsSection`, `HermesWebBrowserView`, `HermesWebBrowserDeckStore`, `HermesWebBrowserWorkspace`, and `HermesWebBrowserStore`.
  - Add/confirm invariants and transitions for workspace restore, active tab, and invalid URL handling.
- Draft `quickstart.md` for implementer verification:
  - Office launch,
  - bridge unavailable state,
  - multi-workspace restore,
  - malformed/blank URL handling.
- No external contracts file is required unless an additional public API is introduced, because interaction remains internal UI flow.

### Phase 2 — Readiness and Consistency Checks

- Ensure generated artifacts contain:
  - `plan.md`
  - `research.md`
  - `data-model.md`
  - `quickstart.md`
- Check planning artifacts for unresolved placeholders such as `NEEDS CLARIFICATION`.
- Confirm implementation boundaries are bounded to:
  - `HermesOfficeView.swift`
  - `HermesWebBrowserView.swift`
  - `HermesiOS/HermesHostEndpoints.swift` as needed
  - `HermesiOS/HermesCompanionClient.swift` / `ContentView.swift` usage only as touchpoints, not as core redesign targets.

## Acceptance Conditions

- No unresolved `NEEDS CLARIFICATION` markers remain in planning artifacts.
- Planned design supports all required user scenarios:
  - office launch from web header,
  - visible and non-blocking readiness signals,
  - resilient behavior when Office or bridge is unavailable,
  - restoration of multiple web workspaces across relaunch.
- Non-functional constraints are explicit:
  - Other web browsing remains usable when Office/Claw3D fails.
  - Workspace restore does not present malformed/blank entries in navigation or quick entry flows.
- Scope control preserved: no broad runtime/API refactor beyond web workspace and settings-hosting paths.

## Constitution Check

- No project constitution file exists at `.specify/memory/constitution.md`; treat this as template-only governance.
- Apply default gating decisions:
  - Security: avoid leaking sensitive URLs or endpoint secrets in status text.
  - Reliability: fail gracefully; restore flows must continue with existing saved pages.
  - Usability: Office and dashboard entry points remain one-tap and visible.
  - Accessibility: all new status/alert messaging must be announced and understandable.
  - Scope control: keep feature local to web/workspace and Hermes Office/Claw3D integration behavior.

## Planned Gates (default gates; no project constitution file found)

- Reliability: failed Office/bridge checks must not block non-Office browsing.
- Security: do not expose sensitive host/session details in user-facing error banners.
- Usability: office shortcut and workspace controls stay stable across restore and port changes.
- Accessibility: service failure/readiness states remain readable by screen readers.
- Build/readiness: design artifacts produced before implementation begins.