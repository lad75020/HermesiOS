# Research: Office & Claw3D WebView Integration

## Decision: Use the existing office URL check as the readiness signal source

**Decision**
Keep `HermesOfficeSettingsSection` as the canonical readiness signal by checking
`HermesHostEndpoints.httpURLString(host: macHost, port: officePort)` and validating
HTTP status success.

**Rationale**
This already reflects host/port changes through `@AppStorage`, updates continuously,
and avoids duplicating network probe logic in the web tab code.

**Alternatives considered**
- Probe Office via `HEAD` only and treat TLS failures differently.
- Replace polling with push/event-driven companion status only.
- Introduce a new dedicated `HermesOfficeReachability` service object.

**Outcome**
Reuse `HermesOfficeSettingsSection` for readiness and expose additional context in
the web experience only where needed for user messaging.

## Decision: Keep multi-workspace persistence format, adding validation before load

**Decision**
Preserve existing `hermes.web.open.pages`, `hermes.web.selected.page`, and
`hermes.web.history.roots` keys, but gate workspace activation with URL validation and
normalization.

**Rationale**
Existing persistence keys already hold stable behavior and compatibility; changing
the schema would risk regressions and stale restore data for users already on this
feature branch.

**Alternatives considered**
- Add a new migration/versioned persistence model.
- Hard-reset all web history on port/host change.
- Persist only dashboard/office URLs in a dedicated table.

**Outcome**
Keep current storage keys and enforce clean load behavior in the deck/store boundary.

## Decision: Represent Office/Claw3D unavailable state as recoverable web-level UX only

**Decision**
Do not block browser navigation when Office/bridge is unavailable; show a recovery
message path for office-specific navigation while keeping browser controls and other
workspaces fully functional.

**Rationale**
The feature explicitly requires normal browsing to remain usable if Office/bridge fails.
Blocking the web tab would create a broad failure mode and reduce usability.

**Alternatives considered**
- Disable all web shortcuts when Office is down.
- Replace normal navigation with a global error screen.
- Force user to restart app after service recovery.

**Outcome**
Use a scoped error/retry affordance at the Office launch path and keep general web
navigation intact.

## Decision: Keep host normalization through existing endpoint helpers

**Decision**
Continue to use `HermesHostEndpoints` and companion-updated `officePort` values for
deriving target URLs.

**Rationale**
A single place already normalizes host and port and enforces current security constraints
for transport.

**Alternatives considered**
- Build one-off URL strings in multiple views.
- Manually parse host/port in each caller.
- Introduce a new endpoint domain object.

**Outcome**
Use existing helper functions and update dependencies only where plan requires tighter
consistency.

## Decision: Handle malformed entries as ignorable/repairable, not fatal

**Decision**
Do not treat malformed stored/new workspace URLs as fatal errors; sanitize/normalize on
entry and skip invalid entries from navigation-critical paths.

**Rationale**
This satisfies "auto-suggested history roots and tab restoration must not expose malformed or blank entries"
while preserving existing session data and minimizing user disruption.

**Alternatives considered**
- Clear all persisted workspace URLs on first parse failure.
- Keep malformed entries visible for manual cleanup.
- Prevent persistence when validation fails at every write.

**Outcome**
Reject only invalid values at activation time, preserve other sessions, and prevent malformed
values from being shown as live navigation targets.

## Open points to validate during implementation

- Verify that `officeURLString` changes (e.g. companion port refresh) do not cause stale
  selected workspace to navigate automatically unless explicitly triggered by user action.
- Confirm that Claw3D adapter path failures are surfaced as workflow-level guidance (not only network transport failures).
- Confirm restoration behavior when one or more saved URLs are malformed or blank.
