# Quickstart: Office & Claw3D WebView Integration

## Objective

Validate planning assumptions and manual QA scenarios for Office integration inside the existing Web tab with resilient behavior when services are down.

## Prerequisites

- Working branch is `feature/time-machine-office`.
- Project builds on a test iOS device/simulator.
- Host Companion reachable for normal baseline path (for positive case).

## Step 1 — Baseline Office action path

1. Open the app and go to the Web tab.
2. Confirm the header shows both shortcut actions (`chart.bar.xaxis` and `building.2.crop.circle`).
3. Tap the Office action.
4. Confirm navigation happens to the configured Office URL from `HermesHostEndpoints.httpURLString(host: macHost, port: officePort)`.
5. Confirm the URL field updates to the Office URL and that browser controls remain responsive.

## Step 2 — Settings status feedback

1. Open Settings.
2. Locate the Office section with status LED.
3. Confirm LED semantics are visible before launch:
   - reachable → healthy state,
   - unreachable/malformed → non-healthy state.
4. Change host/port to an alternate valid Office endpoint.
5. Return to Web tab and verify the Office shortcut target changes accordingly.

## Step 3 — Workspace restore continuity

1. In Web tab, open at least two distinct pages and switch between them.
2. Close app and relaunch.
3. Return to Web tab.
4. Confirm both workspaces are restored and the selected tab is preserved.
5. Confirm a malformed or blank entry (if intentionally injected in test) is not auto-selected for active navigation.

## Step 4 — Failure mode: Office unavailable

1. Point `officePort` to a non-listening local/remote value.
2. Wait for Office status LED to reflect failure.
3. Tap the Office shortcut.
4. Confirm:
   - the tab does not hard-fail the entire web experience,
   - non-Office pages are still navigable,
   - user-visible feedback states that Office is unavailable and suggests retry or later action.

## Step 5 — Failure mode: Claw3D bridge unavailable

1. Keep Office available but make Claw3D adapter unavailable.
2. Open an Office workflow path that would use bridge integration.
3. Confirm app indicates the bridge path is unavailable without exiting the web context.
4. Ensure browser can still open other URLs afterward.

## Step 6 — Host port hot-refresh behavior

1. Trigger companion port refresh path as in normal operation.
2. Confirm updated `officePort` and `dashboardPort` values flow into active web targets.
3. Verify existing workspaces remain stable after refresh unless user explicitly navigates.

## Step 7 — New workspace and popup flow

1. Use in-page popup links where WKWebView opens in a new window.
2. Confirm new workspace is created and selectable in header.
3. Confirm navigation state and history root updates occur in the new workspace.

## Step 8 — Accessibility smoke

1. Enable VoiceOver.
2. Verify labels for header actions (dashboard, office, back, refresh, add workspace) are announced.
3. Verify Office status LED text remains understandable.
4. Ensure status changes are observable without leaving current tab context.

## Completion criteria

- Office shortcut works in positive path.
- Workspace restore and multi-workspace switching are stable across relaunch.
- Office downtime does not block general web browsing.
- At least one path displays a recoverable, non-destructive error/retry message for Office/bridge failures.
- Accessibility labels remain meaningful in both normal and error states.
