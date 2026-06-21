# Quickstart: Validate Secure Settings and Reachability

## Static Validation

1. Inspect `HermesiOS/HermesSettingsPersistence.swift` for secure storage APIs used for sensitive credentials.
2. Inspect `HermesiOS/HermesHostEndpoints.swift` for endpoint security decisions that distinguish loopback from remote plaintext endpoints.
3. Inspect `HermesiOS/HermesSettingsView.swift` for QR onboarding, settings editing, and user-facing error paths.
4. Inspect `HermesiOS/HermesStatusBand.swift` for non-secret reachability states.

## Build Validation

1. Build the `HermesiOS` scheme with XCodeMCP or Xcode.
2. Confirm the build succeeds or record the exact blocker.

## Manual Runtime Scenario

1. Open Settings.
2. Save a valid host and bearer token.
3. Leave and return to Settings; confirm sensitive values are not exposed in plain summaries.
4. Configure an unreachable service; confirm status reflects unreachable without blocking Settings.
5. Try an unsafe non-loopback plaintext endpoint; confirm the app rejects or warns with a clear correction path.
6. Scan or simulate QR onboarding content; confirm imported fields still pass endpoint validation.
