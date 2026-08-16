# Specification: Host Companion Service

Feature ID: `host-companion`

## Summary

The Host Companion Service is the secure macOS control surface that lets the iOS app perform validated host operations from a trusted pairing. It exposes a stable connection path, requires device enrollment before privileged actions, and returns consistent, recoverable outcomes for host operations.

## User Stories

- As a user, I can connect to and verify a trusted host companion session from my iOS app.
- As a user, I can onboard a new iOS client by scanning a pairing code and wait for approval without exposing secrets.
- As a user, I can confirm whether my device is approved before attempting host-side actions.
- As a user, I can list and read available host targets with clear identity and freshness information.
- As a user, I can validate and edit target definitions safely with revision-aware protections.
- As a user, I can view and restore target backups when accidental changes are detected.
- As a user, I can browse files and download content in a way that works with large files and keeps the app responsive.
- As a user, I can inspect and control named host services (status/start/stop/restart) for day-to-day operations.
- As a user, I can manage host runtime settings (models, providers, profiles, memory, toolsets, MCP, schedules, skills, gateway config) while companion enrollment is active.

## User Scenarios & Testing

### Scenario 1: Enroll a new iOS device
1. User opens the companion pairing path and reads the onboarding data from the host.
2. User provides pairing code and device label.
3. System creates a pending device entry and returns a pending approval response.
4. User approves the device in the host companion context.
5. User can poll or reconnect and see approved state.

### Scenario 2: Use privileged companion operations after approval
1. User triggers a management action (for example, restart a service or read a target).
2. Client sends a request with the approved device identity.
3. Companion service executes the action and returns success payload and operational details.
4. User receives a clear message when approval is missing or revoked.

### Scenario 3: Edit a target with safety guards
1. User opens target details from the list and starts an edit flow.
2. Client validates the proposed content before writing.
3. If valid and revision matches, the companion writes the change and records a backup.
4. If invalid or stale, companion returns a structured issue list and does not apply the write.

### Scenario 4: Handle file access for diagnostics
1. User browses host folders and selects a file for inspection.
2. Companion returns directory context and file metadata.
3. For larger files, companion supports chunked download and reports whether more data remains.
4. User can complete downloads without freezing the companion session.

### Scenario 5: Run service operations during normal usage
1. User checks service status from the dashboard-like management path.
2. User starts, stops, or restarts a selected service.
3. Service state and latest output are returned in the same interaction.
4. User can also check/update companion network exposure settings and ports from the same trust path.

## Functional Requirements

- The service shall expose a predictable server state lifecycle (`stopped`, `starting`, `running`, `failed`) and surface the current listener endpoint.
- The listener configuration (`host`, `port`) shall be persisted and reused on next launch.
- The companion server shall fail startup with a user-visible error when the bound port is unavailable.
- The server shall accept and handle only WebSocket-style companion payloads through a defined envelope format.
- The server shall reject malformed payloads without terminating the active session.
- The companion shall require enrollment for protected operations and allow only pairing flow operations when not enrolled.
- The onboarding flow shall issue a time-relevant pairing code and rotate it after successful enrollment.
- Device credentials shall be treated as secrets and never be logged in plaintext.
- Device approvals shall be queryable so clients can distinguish `approved`, `pending`, and `revoked` states.
- The server shall return a stable capability list so clients can discover supported operations dynamically.
- Target operations shall include list/read/validate/write semantics with revision-awareness for write operations.
- Target write operations shall support backup creation and provide revision updates for next read-after-write flow.
- Backup operations shall provide list and restore actions to recover prior versions.
- File browsing shall return normalized path and entry metadata and allow empty directories and deeply nested paths.
- File downloads shall include both single-shot and chunked modes with explicit completion signaling.
- Service lifecycle operations (status/start/stop/restart) shall be exposed and report current service state.
- Companion service-port state shall be discoverable for host-facing ports.
- Tailscale serve state may be queried and toggled, with visible outcome for immediate UI sync.
- Hermes installation update flows shall expose status and conflict-review operations before merge.
- Runtime-management operations shall support read/update actions for tools, toolsets, models, providers, credentials, memory, profiles, schedules, skills, logs, and gateway config.
- Unsupported operations shall return a typed error instead of closing the session.
- All operations should include deterministic success/error codes and human-readable messages suitable for user-facing status surfaces.
- Server lifecycle changes and device operations should emit observable logs for troubleshooting.

## Success Criteria

- 100% of valid onboarding handshakes complete and report a deterministic pending/approved state.
- 99% of companion sessions send a valid response to every request, including invalid/unsupported requests, without session termination.
- 100% of unauthorized operations return a clear approval-required error and do not perform writes.
- 95% of target write attempts with valid revision and valid payloads succeed within 10 seconds in normal conditions.
- 100% of target-validation failures return actionable diagnostics and prevent write-through on invalid content.
- 95% of large-file diagnostics flows complete with explicit chunk completion metadata and without dropped sessions.
- 100% of service control operations return a state+output result that can be displayed in a status view.
- No implementation details (platform internals, protocol libraries, code structure) are required to understand the user-facing behavior.

## Files in Scope

- `HermesHostCompanion/CompanionServer.swift`
- `HermesHostCompanion/CompanionProtocol.swift`

## Assumptions

- iOS companion pairing settings and trust policy are configured prior to attempting write operations.
- The host companion process runs on a trusted local or tailnet endpoint accessible to the iOS app.
- Target file writes are expected to be user-driven and auditable; automatic background writes are out of scope.
- Service commands represent managed host services that the user has visibility into and explicit intent to control.
- Backup retention is configured to keep at least one recent restore point for critical target edits.

## Edge Cases

- Expired or mismatched onboarding code.
- Repeated enrollment attempts from the same device identity.
- Stale revision writes when target changed between read and write.
- Malformed envelopes or unknown payloads from older/mobile clients.
- Duplicate connections from one device while another is in progress.
- Service commands on non-existent or unauthorized service IDs.
- File browser access to paths without permission.
- Large download requests with interrupted chunk sequence.
- Tailscale/port settings changed while active sessions are running.
- Revocation or approval delay after previously approved states.
- Host service restart during active companion sessions.

## Key Entities

- `Companion session`: a connection from a client to the host companion socket with correlation and stop lifecycle.
- `Enrolled device`: device identity with secret fingerprint, approval state, and last-seen tracking.
- `Target`: named host-managed configuration object with revision history and validation constraints.
- `Backup`: immutable snapshot used to recover previous target revisions.
- `Service`: runtime host component with status and lifecycle commands.
- `Capability`: operation contract exposed to clients for discoverability.
- `Payload envelope`: standardized request/response wrapper with request id and outcome status.
