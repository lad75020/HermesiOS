# Research: Status Band

## Decision: Keep current polling loop with adaptive refresh timing

**Decision**
- Keep `runStatusLoop` with `apiRecoveryRefreshInterval = 2s` and `normalRefreshInterval = 60s`, while leaving the immediate refresh on scene-activation.

**Rationale**
- Existing behavior already throttles healthy-state requests and recovers faster when API status is down, which reduces user-visible blind spots without overloading services.

**Alternatives considered**
- Poll at a fixed interval (e.g., always 5s or always 60s).
- Disable recovery acceleration entirely.

**Outcome**
- Keep adaptive intervals.

## Decision: Treat probe success as HTTP response in 200..<500 range

**Decision**
- Preserve current success interpretation (`200..<500`) for API and dashboard probes.

**Rationale**
- This treats server-side validation and auth-related client responses as "reachable," which is useful for health visibility when service is alive but may return non-200 non-auth responses.

**Alternatives considered**
- Restrict to 2xx only.
- Require body-level payload checks for all services.

**Outcome**
- Keep current status definition to avoid false negatives in auth-gated setups.

## Decision: Keep active animation limited to active+healthy indicators

**Decision**
- Use flashing animation only when `isActive && status == .up`; otherwise show non-flashing state color.

**Rationale**
- Requirement states active work cue should be visible during probes while preserving clear unhealthy indication.

**Alternatives considered**
- Flash on active regardless of up/down.
- Replace up/down animation with separate spinner indicator.

**Outcome**
- Keep current approach to preserve continuity with existing design language.

## Decision: Keep companion status disabled when not enrolled

**Decision**
- Preserve existing guard requiring `identityState.isEnrolled` before performing companion hello check.

**Rationale**
- Avoids unnecessary request attempts and avoids surfacing false positives when host identity is absent.

**Alternatives considered**
- Probe companion unconditionally with fallback URL handling.
- Reuse API reachability as companion proxy state.

**Outcome**
- Keep guarded behavior.

## Open points to validate during implementation

- Confirm dashboard URL construction path is always derived from `ContentView` with robust fallback values.
- Confirm active-channel booleans (`apiChannelActive`, `companionChannelActive`, `dashboardChannelActive`) remain aligned with actual in-flight work.
- Confirm animated LEDs maintain readability on high-contrast accessibility themes.