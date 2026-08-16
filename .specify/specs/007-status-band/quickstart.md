# Quickstart: Status Band

## Objective

Validate that status service visibility and active work indicators behave correctly in the Hermes app status band and that the component degrades safely when inputs are unavailable.

## Prerequisites

- Working on branch `feature/time-machine-status-band`.
- App launches normally with existing API/companion settings.
- Buildable project state.

## Step 1 — Baseline status visibility

1. Open the app with a populated host configuration.
2. Navigate to the main workspace where the sidebar is visible.
3. Confirm the top status band displays three indicators labeled `API`, `Mac`, and `DASH` (labels visible where configured).
4. Verify each indicator is visually distinct and readable in both light and dark themes.

## Step 2 — API reachability semantics

1. Set API base URL to an unreachable endpoint.
2. Wait for status loop to run (or trigger app activation).
3. Confirm API LED becomes down (red) while other channels preserve their previous values.
4. Restore a reachable API host and confirm the LED returns to up (green) state after refresh.

## Step 3 — Companion status semantics

1. Start with companion not enrolled.
2. Confirm companion LED does not report up while enrollment is missing.
3. Enroll companion and wait for next probe.
4. Confirm companion LED transitions from down to up when `/hello` returns valid server identity.

## Step 4 — Dashboard status and active work cues

1. Confirm dashboard LED follows dashboard URL reachability.
2. Trigger a dashboard-dependent workflow (history search / workspace activity).
3. Verify the DASH LED shows active working cue while dashboard-related activity is ongoing, then returns to static up/down state after completion.
4. Repeat for API and Mac channels by exercising network/chat and companion-related paths.
5. Expected active timing:
   - Active state should be present during the request/scope work.
   - Status LED returns to static up/down immediately after request completion or cancellation.

## Step 5 — Unavailable values and graceful fallback

1. Force malformed/blank dashboard URL.
2. Confirm dashboard check resolves to down and does not block UI or crash rendering.
3. Force temporary network failure for one service and verify only that service reflects down.
4. Confirm status band remains visible and app remains navigable.
5. API-only outage matrix check:
   - Set API base URL to bad host.
   - Keep companion/dashboard healthy.
   - Verify only API transitions to down.
6. Dashboard-only outage matrix check:
   - Force valid API and companion, blank dashboard URL.
   - Verify only DASH transitions to down.

## Step 6 — Navigation interaction cues

1. Complete and fail operations in main sections.
2. Confirm completion/failure cues in navigation remain visible alongside the status band.
3. Confirm no single cue suppresses the others (status color and navigation unread/failure states remain distinguishable).
4. Simultaneous stress check:
   - Trigger a status transition and completion/failure update in close succession.
   - Verify both remain visible after the sequence.

## Step 7 — Visual and accessibility spot checks

1. Turn on Accessibility VoiceOver.
2. Verify each LED announces service name and state.
3. Confirm active indication is understandable as an ongoing probe rather than a state value only.
4. Confirm low-contrast and high-contrast themes preserve readability for static and active states.

## Completion criteria

- All three service LEDs render in all layouts and remain readable.
- At least one probe-driven active cue is observable for each relevant service during live work.
- Degraded/invalid data does not break UI and shows safe, explicit down states.
- Unread/completion/failure section signals still surface near navigation paths during normal flows.

## Evidence log

### Completed evidence

- Add manual evidence after running each step above on a target or simulator and record:
  - timestamp
  - device/layout (`compact` or `regular`)
  - observed status values (API/Mac/DASH)
  - whether active cue appeared per channel

