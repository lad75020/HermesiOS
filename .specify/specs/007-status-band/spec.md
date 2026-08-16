# Specification: Status Band

Feature ID: `status-band`

## Summary

The Status Band feature gives users a fast visual overview of app and host health at the top of the workspace navigation so they can judge connectivity and background activity without opening deeper screens.

## User Stories

- As a user, I can see whether the Hermes API, Mac Companion, and Dashboard are currently reachable from the top status band.
- As a user, I can spot when one of those services is temporarily unreachable before starting a new request.
- As a user, I can see which channel is currently working (API, Mac Companion, or Dashboard) while a connectivity probe is running.
- As a user, I can tell when a section is actively processing work so I can choose whether to continue waiting, switch away, or retry.
- As a user, I can notice completion and warning states in navigation so important result or failure updates are easy to find.

## User Scenarios & Testing

### Scenario 1: Immediate connectivity visibility
1. User opens the app with any connection profile selected.
2. User looks at the top status band and sees three indicators for API, Mac, and Dashboard.
3. User confirms the indicator colors match the current actual reachability for each service.

### Scenario 2: Active work indication
1. User triggers a request path that uses one of the service endpoints.
2. The corresponding status band indicator begins a visible active animation while the request is being evaluated.
3. After probe completion, the animation stops and the indicator returns to its static healthy/unhealthy color.

### Scenario 3: Unread and failure cues across sections
1. User runs actions that complete successfully or fail in workspace sections.
2. User checks the top area and status-related cues for completed/failure states in the same interaction area where service status is shown.
3. User opens the affected section and confirms the unread/completion cues are cleared or reflected consistently.

## Functional Requirements

- The status band shall always show three separate service indicators labeled API, Mac, and DASH.
- Each indicator shall show a clear up/down state using distinct visual states that match the existing design language.
- The band shall support transient active probing state per service and visually animate only active + healthy indicators.
- The component shall expose input flags to indicate active work for API, companion, and dashboard probes.
- The component shall keep a strong contrast non-intrusive style so it remains readable on both light and dark themes.
- The component shall expose accessibility labels that describe the service and state (up, down, active).
- The component shall continue to render correctly when unread/completion/failure visual states are surfaced around nearby navigation content.
- The component should degrade gracefully when status values are delayed or unavailable, without blocking the rest of the UI.

## Success Criteria

- At app start, all users can identify API, Mac, and Dashboard status in one glance within one interaction step.
- During a connectivity probe, users can perceive which service is actively being checked, with active animation replacing static state for that service.
- When a service is reachable, its status remains visibly distinct from unavailable services for 100% of observed refresh cycles.
- At least 95% of manual smoke-test runs can verify that service status and active work cues remain visible after changing tabs.
- In complete or failed task states, users can identify attention changes without opening a section and can proceed to the relevant workspace path in the same flow.

## Files in Scope

- `HermesiOS/HermesStatusBand.swift`

## Assumptions

- Service reachability values are sampled by an existing background monitor and passed into this view.
- Completion/failure/unread visual cues already exist in navigation components and are coordinated with parent views.
- Users tolerate subtle animated indicators for active probing as a lightweight non-blocking activity signal.

## Edge Cases

- Service endpoint values are blank, malformed, or temporarily unreachable.
- All three services are down simultaneously.
- One service transitions quickly between down and up while another remains active.
- Accessibility mode is enabled and all labels are read in a clear order.
- App appears before first successful probe and status values are still unknown.

## Key Entities

- `HermesStatusMonitor`: holds per-service status (`up`/`down`) and active probe flags.
- `HermesStatusBand`: renders condensed status indicators for API, Mac, and Dashboard.