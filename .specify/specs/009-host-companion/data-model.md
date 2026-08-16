# Data Model: Host Companion Service

## Entities

### CompanionIncomingEnvelope / CompanionOutgoingEnvelope

- Location: `HermesHostCompanion/CompanionProtocol.swift`
- Type: `Codable` structs shared between host and iOS
- Fields:
  - `id: String?`
  - `type: String`
  - `deviceID: String?`
  - `deviceSecret: String?`
  - `payload: JSONValue?`
  - `ok: Bool`
  - `error: CompanionErrorPayload?`
- Invariants:
  - Every request is typed by `type` and deserialized payload-specific structure.
  - Every response is either `ok=true` with payload or `ok=false` with error.

### CompanionServerConfiguration

- Location: `HermesHostCompanion/CompanionServer.swift`
- Fields: `host`, `port`, computed `webSocketURLString`, `advertisedWebSocketScheme`
- Behavior:
  - Listener always binds loopback (`127.0.0.1`); advertised host/port are advertised for onboarding and URL display.
  - Host and port sanitized before persisting.
- Invariants:
  - `state == .running` implies listener is active and `listenerDescription` reflects current websocket URL.

### CompanionServer + CompanionServer.State

- Location: `HermesHostCompanion/CompanionServer.swift`
- State values: `stopped/starting/running/failed`
- Fields:
  - `state`, `listenerDescription`, `lastErrorMessage`, active `sessions`, `configuration`
- Behavior:
  - `start()` validates parameters, starts listener, assigns state handlers.
  - `accept()` creates a `CompanionClientSession` per connection and tracks lifecycle.
- Invariants:
  - `stop()` always clears sessions and moves to stopped state.
  - Port binding failures are captured in `.failed` with a human-readable `lastErrorMessage`.

### CompanionClientSession

- Location: `HermesHostCompanion/CompanionServer.swift`
- Fields: `id`, `connection`, `decoder`, `encoder`, registries
- Behavior:
  - Receives bytes, decodes request envelope, routes by type, sends envelope response.
  - Maintains malformed-request fallback (`invalid_request`) without killing peer session.
- Invariants:
  - Route dispatch always emits one response path for each input frame.
  - Unauthorized requests are denied before write-sensitive route handling.

### CompanionDeviceAuthorizationStore

- Location: `HermesHostCompanion/CompanionServer.swift`
- Stored model: `CompanionAuthorizedDeviceRecord` (`id`, `deviceName`, `secretFingerprint`, timestamps, approval/revoke flags)
- Behavior:
  - Generates onboarding code and rotates it.
  - Stores device records in `UserDefaults`.
  - Generates/validates secret fingerprints on enrollment and auth checks.
- Invariants:
  - Only approved + unrevoked devices pass `authenticate(...)`.
  - Revoked/pending devices cannot operate privileged routes.

### CompanionTargetRegistry

- Location: `HermesHostCompanion/CompanionTargetRegistry.swift`
- Key models:
  - `CompanionTargetRecord`, `CompanionTargetRegistryDocument`, `CompanionBackupRecord`
  - `ReadTargetResult`, `ValidateTargetResult`, `WriteTargetResult`, `ListBackupsResult`, `RestoreBackupResult`
- Behavior:
  - `listTargets`, `readTarget`, `validateTarget`, `writeTarget`, backups list/restore.
  - `writeTarget` is revision-gated and runs validators.
  - `setHermesSkillState` tracks skill metadata usage in workspace.
- Invariants:
  - `writeTarget` with stale revision is rejected with `revisionMismatch`.
  - `writeTarget` only proceeds if validation passes.

### CompanionFileDownloadRegistry

- Location: `HermesHostCompanion/CompanionFileDownloadRegistry.swift`
- Behavior:
  - `listDirectory(path...)` returns directory entries and parent path.
  - `downloadFile` returns in-memory base64 payload for full-file transfer.
  - `downloadFileInfo` exposes metadata and chunk size.
  - `downloadFileChunk` returns explicit `isComplete`, `offset`, and total byte count.
- Invariants:
  - Directory and download paths are normalized to safe absolute/relative expectations.
  - Chunked transfer is bounded and offset-based.

### CompanionServiceRegistry / CompanionTailscaleServeRegistry

- Locations:
  - `HermesHostCompanion/CompanionServiceRegistry.swift`
  - `HermesHostCompanion/CompanionTailscaleServeRegistry.swift`
- Behavior:
  - Query and control service lifecycle (`status/start/stop/restart`).
  - Query and set tailscale-serve flags and output.
- Invariants:
  - Service status requests are typed and stable by `serviceID`.
  - Tailnet settings are explicit and surfaced by status/toggle ops.

### CompanionServerController

- Location: `HermesHostCompanion/HermesHostCompanionApp.swift`
- Responsibilities:
  - host-side settings persistence and UI mutation
  - apply network target, service ports, onboarding settings
  - start/stop server and onboarding refresh loop
- Invariants:
  - start button/restart flow updates bound server configuration and avoids stale bind port states.

### CompanionOnboardingSettingsStore / CompanionServicePortsStore

- Location: `HermesHostCompanion/HermesHostCompanionApp.swift`
- Purpose:
  - persist QR onboarding values and service port defaults.
  - sanitize stored values (host/path/key normalization, port normalization)
- Invariants:
  - API key stored in Keychain and normalized.
  - service ports are sanitized to integer TCP ranges.

### HermesCompanionSessionFactory and Runtime session

- Location: `HermesiOS/HermesCompanionClient.swift`
- Runtime state: `HermesCompanionRuntimeSession`
- Behavior:
  - tracks targets, targets diagnostics, services, logs, model/provider/toolset/schedule/profile/memory/gateway data
  - kickstart and refresh section-specific loaders
  - sends typed requests and decodes typed responses
- Invariants:
  - runtime operations that mutate remote state are gated by `identityState.isEnrolled`.
  - operation methods preserve last status/error fields for user-visible feedback.

## State Transitions

### Enrollment lifecycle

- `unknown code` 
- `scan onboarding` 
- `enroll_device` issued  `pending approval` with `approved=false`
- Host-side approval  `approved`
- Revocation/forget  `revoked` or removed

### Target edit lifecycle

- `list/read target`  state + content + revision loaded
- `validate_target`  diagnostics emitted without write side effects
- `write_target` with matching revision and valid diagnostics  saved + optional backup + new revision
- `write_target` mismatch/invalid  hard error response

### Service/management lifecycle

- Each runtime section has load/refresh operations that map into local cached fields.
- Service commands (`start/stop/restart`) always return updated service status payloads for immediate UI reflection.

## Validation Rules

- Envelope decode failures return `invalid_request` and keep session alive.
- Unauthorized operations return `device_not_approved` or equivalent authorization error.
- Target writes require exact `expectedRevision`.
- `list_targets` and `read_target` must resolve workspace/profile variants before hitting disk.
- Secret fingerprints must be compared with constant-time style matcher.
