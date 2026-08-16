# Data Model: Settings & Configuration

## Entities

### HermesAPISettings
- Location: `HermesiOS/HermesResponsesAPI.swift`
- Fields
  - `baseURL: String`
  - `apiKey: String`
  - `allowSelfSignedCertificates: Bool`
- Derived values
  - `normalizedAPIKey`
  - `hasAuthorizationToken`
  - `authorizationHeaderValue`
- Invariants
  - `baseURL` can be normalized via `HermesHostEndpoints.httpURLString` for derived API routes.
  - `apiKey` should not be written directly to plain JSON when persisted.

### HermesCompanionSettings
- Location: `HermesiOS/HermesCompanionClient.swift`
- Fields
  - `apiURL: String` (derived from mac host + companion port)
  - `deviceSecret: String` (stored securely before persistence)
  - `hermesWorkspacePath: String`
- Invariants
  - `apiURL` must align with an active host context when possible.
  - Workspace path should be user-editable but still visible in companion operations.

### HermesCompanionIdentityState
- Location: `HermesiOS/HermesCompanionClient.swift`
- Fields
  - `deviceID`, `deviceName`, `serverEndpoint`, `deviceSecretFingerprint`, `issuedAt`, `approvedAt`, `revokedAt`
- Computed states
  - `hasPairing`, `isPendingApproval`, `isEnrolled`
- Invariants
  - `isEnrolled == hasPairing && approvedAt != nil && revokedAt == nil`
  - Pairing matching is fingerprint-based against selected settings secret.

### HermesCompanionSavedConnection
- Location: `HermesiOS/HermesCompanionClient.swift`
- Fields
  - `nickname`, `serverName`, `identityState`, `lastMessage`, `updatedAt`
  - `id` derived from `identityState.deviceID`
- Invariants
  - Must preserve per-host pairing context.
  - Duplicate IDs are deduplicated when persisted.

### HermesTerminalSettings
- Location: `HermesiOS/HermesTerminalView.swift`
- Fields
  - `username`, `port`, `hasPrivateKey`
- Invariants
  - Private key is not stored in raw file state; retrieval requires Keychain path when connecting.

### HermesAppTheme
- Location: `HermesiOS/HermesAppTheme.swift`
- Values
  - `system`, `light`, `dark`
- Invariant
  - Persists as user preference and used to set app appearance globally.

## Host/service configuration model

### HermesHostEndpoints
- Provides defaults and derivation helpers:
  - `hermesMacHostStorageKey`, `hermesDashboardPortStorageKey`, `hermesOfficePortStorageKey`, `hermesTailscaleServePortStorageKey`
  - `httpURLString`, `dashboardURLString`, `webSocketURLString`, `remoteDashboardPort`
- Invariants
  - Dashboard port migration: if input is legacy local port and host is remote, map to default dashboard port.
  - Ports derive from parsed numeric content and fallback safely.

### HermesCompanionServicePortsResult
- Location: `HermesiOS/HermesCompanionClient.swift`
- Fields
  - `apiGatewayPort`, `dashboardPort`, `officePort`
- Invariants
  - Returned values populate port state used by settings and content-level URLs.

## State transitions

### Companion identity state

- **Not paired**: no pairing data (`isPendingApproval` false, `isEnrolled` false)
- **Pending approval**: pairing exists, no approval timestamp
- **Approved**: `isEnrolled` true
- **Revoked**: `revokedAt` set

### Active host selection

- Active host is driven by enrollment session `activeConnectionID`.
- Selecting a host updates `companionSettings` through `syncActiveCompanionConnectionToSettings`.
- Host switches are blocked while active Hermes streams are running (via `canSwitchHosts`).

## Validation rules

- Host/port values should be normalized through `HermesHostEndpoints` before persistence display.
- Plaintext transport to non-loopback/non-tailnet hosts is warned/blocked depending on endpoint usage.
- `saved host` list should remain sorted and deduplicated.
- Secret-bearing values (`apiKey`, companion secret) must not appear in plain-state summaries.
