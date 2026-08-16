# Specification: Settings & Configuration

Feature ID: `settings`

## Summary

The Settings feature gives users full control over Hermes connectivity and appearance from the iOS app:
API gateway targeting, companion host configuration, workspace paths, service port visibility/selection, and the visual theme. Settings changes persist across app restarts so the user returns to a valid, usable configuration state immediately after relaunch.

## User Stories

- As a user, I can set the Hermes API base URL and authentication key in one place so my app requests use my chosen gateway instance.
- As a user, I can configure the Host Companion endpoint and trust policy so the app can open a trusted connection to the host.
- As a user, I can review and switch saved companion hosts so I can use multiple remote environments without re-pairing from scratch.
- As a user, I can inspect or override the service ports (API, dashboard, office, companion) to match my host setup.
- As a user, I can enable and tune theme appearance so the UI stays comfortable across environments.
- As a user, I can choose and persist a workspace path for companion-driven operations and updates.
- As a user, I can rely on these settings being preserved across launches without re-entering credentials.

## User Scenarios & Testing

### Scenario 1: API and gateway setup
1. User opens Settings and enters a new hostname and API port, then saves by navigating away.
2. User verifies API requests use the new endpoint immediately in the relevant workspace screens.
3. User restarts the app and confirms the API URL is still applied.

### Scenario 2: Companion configuration and pairing
1. User updates the host entry, scans or enters companion details, and observes approval status.
2. User performs a status refresh and confirms companion-dependent sections respond to the selected host.
3. User switches to another saved host and verifies credentials and endpoint context update automatically.

### Scenario 3: Security and transport behavior
1. User enters a plaintext remote URL for API or companion and receives a clear warning.
2. User uses a local/Tailscale endpoint and confirms the warning is not shown.
3. User validates that API key values are not displayed in plain form in status summaries.

### Scenario 4: Ports and workspace
1. User views detected service ports and selects which port is exposed via tailscale serve controls.
2. User updates workspace path and triggers companion actions that use it.
3. User checks behavior when service host ports are missing or malformed.

### Scenario 5: Theme persistence
1. User changes the app theme (system/light/dark).
2. User switches screens and restarts the app.
3. User confirms the selected theme is applied consistently.

## Functional Requirements

- The Settings screen shall allow editing and persisting the Hermes API base URL and authentication token.
- The application shall normalize entered host/port values into the endpoint formats used for API and companion traffic.
- The application shall display transport safety guidance when credentials might flow over insecure remote links.
- Companion settings shall include host endpoint, workspace path, and active device pairing context.
- The user shall be able to save, list, switch, and forget companion host entries while preserving per-host identity and status.
- The application shall keep the companion endpoint and selected device secret aligned to the active host entry.
- Service ports for API, dashboard, office, and companion shall be visible, editable when needed, and persisted.
- The application shall maintain a distinct selected tailscale-serve port and validate that it remains compatible with known service ports.
- Theme preference (system/light/dark) shall be applied to the app UI and persisted across restarts.
- Workspace path for Hermes companion operations shall be editable and persisted.
- All settings changes in scope shall survive app termination and relaunch without manual re-entry.
- Credential values (API bearer token and companion secret) shall be stored using platform-secured storage semantics.
- Invalid inputs (empty host, malformed endpoint, invalid port, revoked/expired pair state) shall produce clear, recoverable user feedback without crash.

## Success Criteria

- New users can complete API and companion setup from Settings without leaving the app and can execute a request path without misconfiguration.
- Settings updates for host, ports, workspace, theme, and pairing are reflected within one interaction cycle in status and dependent screens.
- All configured settings persist across cold restarts and re-open in the expected state.
- Security guidance appears for insecure remote plaintext transport, and users can still use local/Tailscale transport without warnings.
- Companion switching retains the correct per-host context (endpoint + credentials) and no host action is sent with stale pairing information.
- 95% of setting edits in acceptance tests result in the expected persisted value and visible UI representation.
- Users can complete common flows without app crashes, even when service ports are missing, out-of-range, or host names include non-standard formats.

## Files in Scope

- `HermesiOS/HermesSettingsView.swift`
- `HermesiOS/HermesSettingsPersistence.swift`
- `HermesiOS/HermesHostEndpoints.swift`
- `HermesiOS/HermesAppTheme.swift`

## Assumptions

- Host Companion and Hermes API endpoints are reachable with versions compatible with current payload structures.
- Users may configure local/Tailscale endpoints and expect those to bypass plaintext transport restrictions.
- The platform keychain/credential store is available and may require biometric/OS trust policy as configured by the app.
- Existing Time-Machine workflow commands and navigation expect settings artifacts under `.specify/specs`.
- Default fallback ports from existing deployment conventions are acceptable when input values are temporarily missing.

## Edge Cases

- User enters only a bare host while previously saved full URLs existed.
- User enters non-numeric or out-of-range port values.
- Multiple saved companion hosts exist and one is revoked while selected.
- User changes mac host while streaming jobs are active.
- Secret values are cleared or become unavailable from secure storage.
- Legacy endpoint/port values are present and need migration to new persisted formats.
- Concurrent host switching and status refresh requests occur near app start or resume.

## Key Entities

- `HermesAPISettings`: API-facing configuration (base URL, auth token, transport preference).
- `HermesCompanionSettings`: Companion endpoint, workspace path, and per-device authentication context.
- `HermesCompanionSavedConnection`: Saved host entry with pairing identity and status metadata.
- `HermesAppTheme`: User-chosen visual preference.
- `HermesSettingsPersistence`: Persistence boundary for user preferences and secure secret handling.
