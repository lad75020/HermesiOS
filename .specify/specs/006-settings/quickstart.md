# Quickstart: Settings & Configuration

## Objective

Validate the settings implementation end-to-end from the Settings tab and confirm dependent screens react correctly.

## Prerequisites

- Open the app in simulator/device with a reachable Hermes API and companion host.
- Ensure the 006-settings branch is checked out: `feature/time-machine-settings`.

## Step 1 — API settings baseline

1. Open Settings → Gateway section.
2. Edit `baseURL` and `API key` and confirm:
   - `baseURL` remains normalized by host/port helpers.
   - Bearer token is trimmed and accepted in common formats.
3. For remote plaintext host (`http`/`ws`), verify warning text is shown.
4. Toggle self-signed certificate mode and verify warning copy still reflects fingerprint behavior.

## Step 2 — Companion onboarding and host switching

1. Open Host Companion section.
2. Start QR scan with a valid onboarding payload.
3. Confirm:
   - active host updates to scanned endpoint
   - workspace path is populated from payload when available
   - device status transitions from unpaired to waiting/approved based on host action
4. Connect to a second host and verify host list and active host switching are shown correctly.
5. Confirm host switching is prevented during active streaming paths (`canSwitchHosts == false`).

## Step 3 — Saved connection lifecycle

1. For at least one saved host row, use `Check` to refresh approval state.
2. Use `Forget` on a non-active host and confirm it is removed from the list.
3. When no connection is active, clear active host and confirm settings fallback is sane.

## Step 4 — Service ports and Tailscale Serve

1. In Service/Ports UI, confirm:
   - API/dashboard/office ports are visible and refreshable.
   - companion control is blocked until enrollment exists.
2. Open Tailscale Serve controls:
   - refresh status for the selected port,
   - toggle serve and verify command status changes.
3. Confirm host/service ports are persisted and reflected in derived URLs across tabs.

## Step 5 — Persistence sanity

1. Change theme and restart app: confirm theme preference is restored.
2. Change API/companion settings and restart app: confirm values persist.
3. Update `hermesWorkspacePath` and confirm companion operations use it.
4. Import and remove terminal private key; verify has-key status updates and no raw key appears in persisted plain settings.

## Step 6 — Dependent screen propagation

1. Return to main app tabs.
2. Confirm dependent views derive URLs/status from current host settings:
   - Dashboard URL
   - Office URL
   - API gateway traffic paths
3. Validate that status/refresh loops run when settings are valid and stop when appropriate if enrollment is unavailable.

## Known quick checks

- Ensure `dashboardURLString` and `officeURLString` are no-ops for malformed host/path input (fallback defaults shown).
- Ensure companion endpoints never crash when pending/revoked states are present.
- Verify no plain API token or device secret appears in visible non-secure logs.
