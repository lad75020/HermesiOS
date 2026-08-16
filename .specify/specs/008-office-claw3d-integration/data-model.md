# Data Model: Office & Claw3D WebView Integration

## Entities

### HermesOfficeSettingsSection

- Location: `HermesiOS/HermesOfficeView.swift`
- Purpose: Show Office readiness and provide periodic HTTP health checks from configured Office URL.
- State:
  - `macHost`: stored host value from `@AppStorage`.
  - `officePort`: stored service port value from `@AppStorage`.
  - `officeReturnsHTTP200`: computed indicator for status LED.
- Behavior:
  - `officeURLString` uses `HermesHostEndpoints.httpURLString(host: port:).`
  - `runOfficeStatusLoop()` polls while task is active.
  - `checkOfficeURLReturnsHTTP200()` sends one lightweight GET with timeout and marks boolean.
- Invariants:
  - Health status is never inferred from companion state only; only from URL reachability.
  - Invalid URL formats resolve to `false`, not crash.
  - Poll loop exits cleanly when task is cancelled.

### HermesWebBrowserView

- Location: `HermesiOS/HermesWebBrowserView.swift`
- Purpose: user-facing web workspace UI and workspace switching.
- Inputs:
  - `deckStore: HermesWebBrowserDeckStore`
  - `dashboardURLString`
  - `officeURLString`
- Components:
  - Header actions: back, refresh, new workspace, URL field, dashboard shortcut, office shortcut.
  - Multi-workspace tabs and favicon list.
  - URL normalization before navigation.
- State transitions:
  - `onAppear`/`onChange(selectedWorkspace)` → `loadIfNeeded`.
  - URL entry submit → normalized URL → `load` and persistence.
  - Shortcut action (`open Office` or `open dashboard`) → navigate immediately.

### HermesWebBrowserDeckStore

- Location: `HermesiOS/HermesWebBrowserView.swift`
- Purpose: multi-workspace model and persistence adapter.
- Properties:
  - `workspaces: [HermesWebBrowserWorkspace]`
  - `selectedWorkspaceID`
  - `rootHistory: [String]`
  - `workspaces` persistence keys in `UserDefaults`.
- Methods of interest:
  - `init()`: restores workspace URLs from `hermes.web.open.pages`.
  - `loadAllUnloadedWebPages()`: preloads each workspace with valid URL.
  - `createWorkspace(...)`: adds new workspace, persists ordering.
  - `selectWorkspace(id:)`: updates active workspace and persists selection.
  - `persistURLStringIfNeeded` and `persistOpenPages()`: persistence writes.
  - `recordHistoryRoot(for:)`: collects root history for suggestions.
  - `observe(_:)`: binds page updates and new-window handling.
- Invariants:
  - Persisted pages are non-empty before writing.
  - Selection is always a valid workspace ID.
  - New window requests create a new workspace and inherit requested URL.

### HermesWebBrowserWorkspace

- Location: `HermesiOS/HermesWebBrowserView.swift`
- Purpose: per-tab state holder.
- Fields:
  - `id`, `number`, `urlString`, `store`.
- Invariants:
  - One workspace can have one active `HermesWebBrowserStore`.
  - `urlString` updates trigger persistence via workspace-level handlers.

### HermesWebBrowserStore

- Location: `HermesiOS/HermesWebBrowserView.swift`
- Purpose: direct WKWebView lifecycle wrapper.
- Inputs/outputs:
  - Inputs: URL requests.
  - Outputs: navigation state (`canGoBack`, `currentURL`, `isLoading`), favicon image.
- Callbacks:
  - `rootURLHandler` and `pageURLHandler` for host-level persistence/history.
  - `newWindowHandler` for target `_blank` style flows.
- Invariants:
  - No crash on navigation errors.
  - Page loading state always reset on completion/failure/provisional failure.
  - Favicon requests only execute for HTTP/HTTPS pages.

### Companion settings interactions

- Locations: `ContentView.swift` and `HermesSettingsView.swift`
- Key actors:
  - `companionRuntime.refreshServicePorts(...)` updates service ports in AppStorage.
  - `officePort` is AppStorage-backed and drives Office URL derivation.
- Invariants:
  - Port refresh updates `officePort` and therefore subsequent Office targets.
  - Host and port changes should flow into UI-bound URLs.

## State Transitions

### Workspace restore transition

1. App starts.
2. `ContentView` executes `webBrowserStore.loadAllUnloadedWebPages()`.
3. Each restored workspace URL is normalized.
4. Valid URLs load; invalid ones remain un-navigated without crashing.
5. Active workspace selection is restored from `hermes.web.selected.page` when possible.

### Office launch transition

1. User taps `Open Hermes Office` in web header.
2. `loadOfficeURL()` resolves URL normalization and persistence steps.
3. `HermesWebBrowserWorkspace.store.load(_:)` starts page load.
4. If page is unreachable, browser navigation state updates and workspace remains open.

### Service readiness transition

1. `HermesOfficeSettingsSection` computes `officeReturnsHTTP200`.
2. UI status LED updates continuously as companion settings/ports change.
3. Non-reachable state is reflected as warning (off) state, not fatal stop.

## Validation Rules

- `officeURLString` must be derived via shared endpoint helpers.
- Shortcuts cannot navigate when URL is blank/invalid.
- Workspace restoration must not expose blank malformed entries to active UI tabs.
- Unavailable Office/Claw3D states must leave non-Office navigation unaffected.
- `selectedWorkspaceID` must always point to existing workspace.
