# Specification: Office & Claw3D WebView Integration

Feature ID: `office-claw3d-integration`

## Summary

This feature makes the existing Web tab a reliable place to use Hermes Office and the Claw3D bridge from within HermesiOS, with clear status visibility, smooth workspace behavior, and resilient handling when Office or bridge services are unavailable.

## User Stories

- As a user, I can launch the Hermes Office web experience from the in-app Web tab quickly.
- As a user, I can tell at a glance whether Hermes Office is reachable and whether my bridge workflow should be expected to work.
- As a user, I can continue browsing and return to previous pages across app relaunches without losing my active web context.
- As a user, when Claw3D adapter or Office services are unavailable, I can see an understandable message and still use other HermesiOS features.
- As a user, I can switch quickly between dashboard and office destinations from the same web view controls.

## User Scenarios & Testing

### Scenario 1: Open Office from the Web tab
1. User opens the Web workspace.
2. User taps the dedicated office action.
3. Office loads from the configured Office URL and displays the Hermes Office home screen.

### Scenario 2: Use Office + Claw3D integration flow
1. User navigates to a Claw3D-capable workflow in Office.
2. The workflow attempts to use the Hermes bridge endpoint.
3. User can complete the task when the bridge is running; otherwise a clear in-app fallback message is shown.

### Scenario 3: Keep workspaces stable after relaunch
1. User opens one or more web pages, including an Office or dashboard page.
2. User closes and reopens the app.
3. Those pages and selected workspace context are restored in the Web tab.

### Scenario 4: Handle unavailable services without breaking the Web tab
1. User opens the Office destination while the Office service or Claw3D adapter is down.
2. The app communicates that Office/bridge connectivity is not currently available.
3. The Web tab remains usable for other URLs while Office remains retryable.

### Scenario 5: Validate status feedback during normal and failed states
1. User checks the status area linked to Office in settings.
2. The status updates correctly when Office starts responding and when it stops responding.
3. The user trusts the signal to decide whether to proceed with Office workflows.

## Functional Requirements

- The Web workspace shall expose a visible action to load the configured Office URL from the same Web tab.
- The Office status indicator in the dedicated Office section shall reflect Office reachability from the currently used host and port.
- The Web workspace shall preserve multiple page tabs/workspaces and restore them across app relaunches.
- Workspace restore behavior shall keep the currently selected tab and URLs in a consistent state.
- Users shall be able to continue editing, normalizing, and navigating URLs from the Web toolbar regardless of Office status.
- The first load of Office/Claw3D-related URLs shall be non-blocking to the rest of the app.
- If Office URL validation fails, the tab shall fail gracefully with a retry-oriented message and explicit next step.
- If Claw3D bridge communication is unavailable, the user experience shall explain that the bridge path is not ready and allow the user to continue browsing.
- Auto-suggested history roots and tab restoration must not expose malformed or blank entries to the Web tab.
- Office and dashboard destinations in the Web header controls shall remain consistent with the configured host/ports.

## Success Criteria

- 100% of manual smoke tests open Office from the Web tab with one tap and return successfully when Office is up.
- Office status is visible before launch and after startup, and users can interpret readiness in under 5 seconds in normal conditions.
- On relaunch, previously opened Office and dashboard pages are restored with the same selected tab when available.
- In failure cases (Office down, bridge down, bad host), the app provides actionable feedback and keeps all non-Office web browsing functional.
- At least 95% of manual reload/retry flows on failed Office/bridge sessions remain stable with no app crashes.

## Files in Scope

- `HermesiOS/HermesOfficeView.swift`
- `HermesiOS/HermesWebBrowserView.swift`

## Assumptions

- Hermes Office and the Claw3D bridge are configured with compatible host/ports provided by Host Companion service settings.
- HermesOffice and bridge availability can legitimately fluctuate while the app is running (for example, adapter restart).
- Existing web workspace behaviors (tabs, history persistence, URL normalization) remain available and should be preserved.
- Users access Office through the existing iOS App web tab workflow; no separate dedicated Office screen is introduced.

## Edge Cases

- Office URL or bridge endpoint is temporarily malformed.
- Office service is reachable but the bridge path is down or returning an error.
- The app starts from a blank or stale saved workspace state.
- Host Companion updates service ports while the Web tab is open.
- Device resumes from background with cached web pages and stale network credentials.
- Multiple workspaces are open while one workspace navigates to Office and another to a different destination.

## Key Entities

- `HermesOfficeSettingsSection`: surface Office reachability and readiness states tied to the current host/port.
- `HermesWebBrowserView`: web entry point, shortcut controls, and multi-workspace browser behavior.
- `HermesWebBrowserDeckStore` / `HermesWebBrowserWorkspace`: persisted web workspace list and per-workspace URLs.
- `HermesWebBrowserStore`: page state, current URL, and workspace activity lifecycle for the in-app browser.