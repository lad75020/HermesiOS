# Data Model: Status Band

## Entities

### HermesServiceReachability

- Location: `HermesiOS/HermesStatusBand.swift`
- Type: enum
- Values
  - `up`
  - `down`
- Derived behavior
  - `color` maps to green for `up`, destructive red for `down`.
  - `accessibilityLabel` maps to `"up"` / `"down"`.
- Invariants
  - Only two domain states are represented (`up`, `down`) to keep navigation feedback deterministic.

### HermesStatusMonitor

- Location: `HermesiOS/HermesStatusBand.swift`
- Type: `@Observable` class (`@MainActor`)
- Fields
  - `apiServerStatus: HermesServiceReachability`
  - `companionStatus: HermesServiceReachability`
  - `dashboardStatus: HermesServiceReachability`
  - `isAPIProbeActive: Bool`
  - `isCompanionProbeActive: Bool`
  - `isDashboardProbeActive: Bool`
- Constants
  - `normalRefreshInterval: Duration = 60s`
  - `apiRecoveryRefreshInterval: Duration = 2s`
- Methods
  - `runStatusLoop(apiSettings:companionSettings:dashboardURLString:identityState:)`
    - Repeats `refresh` while task is not cancelled.
    - Uses `apiRecoveryRefreshInterval` when API status is down, otherwise `normalRefreshInterval`.
  - `refresh(apiSettings:companionSettings:dashboardURLString:identityState:)`
    - Launches per-service checks concurrently and updates statuses atomically.
  - `checkAPIServer(settings:)`
    - Builds normalized URL from `settings.baseURL + /models` and performs GET.
  - `checkCompanion(settings:identityState:)`
    - Performs hello request only when `identityState.isEnrolled`.
  - `checkDashboard(baseURLString:apiSettings:)`
    - Performs GET against dashboard URL using API session context.
  - `statusURL(from:)`
    - Trims and normalizes host path.
- Invariants
  - `refresh` always sets all three statuses on each call.
  - Probe flags are true only while their corresponding network operation is in-flight.
  - Failure path always resolves to `false` status (`.down`) for that service.

### HermesStatusLED

- Location: `HermesiOS/HermesStatusBand.swift`
- Type: `View`
- Inputs
  - `label`, `tooltip`, `status`, `isActive`
  - optional `inactiveColor`, `activeFlashOffColor`
- Behavior
  - If active and up, uses `TimelineView` flash with `flashingColor(for:)`.
  - Otherwise renders a static color.
  - Accessibility label includes tooltip + state (`up/down/active`).
- Invariants
  - Flashing never represents `down` status; failed states stay static red.

### HermesStatusBand

- Location: `HermesiOS/HermesStatusBand.swift`
- Type: `View`
- Inputs
  - `statusMonitor: HermesStatusMonitor`
  - `showsLabels: Bool`
  - `apiChannelActive: Bool`, `companionChannelActive: Bool`, `dashboardChannelActive: Bool`
- Output behavior
  - Renders three `HermesStatusLED` entries in order: API, Mac, DASH.
  - Combines explicit active flags with monitor probe flags for each channel.
- Invariants
  - Rendering path remains constant-time, bounded by fixed three channels.

### Call-site relationships

- `ContentView`
  - Owns monitor and session state.
  - Calculates channel activity and passes it into UI navigation.
- `WorkspaceSidebar`
  - Hosts the band when sidebar is shown.
  - Supports compact and standard layouts via parent layouts.

## State transitions

- API / companion / dashboard statuses:
  - Start: unspecified initial state.
  - Refresh in progress: flags set true per service.
  - Refresh complete: each status becomes `up` or `down`.

- Probe activity transitions (per service):
  - `false -> true` when check starts.
  - `true -> false` with `defer` after network call returns.

- Polling loop:
  - loop starts on task activation in `ContentView`.
  - if API down: fast retry window (`2s`).
  - else: normal interval (`60s`).

## Validation Rules

- Monitor run must never block UI rendering; values update asynchronously.
- No probe attempt should attempt companion hello when identity state is not enrolled.
- Invalid URLs must result in `dashboardStatus == .down` or `apiServerStatus == .down` without crash.
- Unknown/empty values are represented as down state and visual fallback (red) rather than hidden UI.
- Accessibility labels must remain stable across light/dark themes and active animation.
- Any animation change should not suppress unread/completion/failure navigation cues elsewhere in sidebar.