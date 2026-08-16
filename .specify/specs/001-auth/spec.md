# Specification: Authentication & Pairing

Feature ID: `auth`

## Summary

QR-based device onboarding and companion enrollment for the iOS app.

## User Stories

- As a user, I can onboard and approve a pairing so the app can execute Host Companion actions.
- As a security-conscious user, I can tell whether pairing is pending or revoked before privileged actions.

## Functional Requirements

- The iOS app SHALL decode onboarding payloads and persist pairing identity fingerprints.
- The app SHALL mark pairing state as pending, approved, or revoked and expose clear UI labels.
- The app SHALL reject companion RPC calls when pairing is not approved.
- The app SHALL expose controls for reviewing and refreshing pairing state from settings.

## Success Criteria

- Pairing can be initiated and completed without crashes on first-run and after app restarts.
- No privilege call succeeds when pairing is missing, pending, or revoked.
- Status labels remain synchronized between panel and settings after relaunch.

## Files in Scope

- `HermesiOS/HermesCompanionClient.swift`
- `HermesiOS/HermesCompanionPanel.swift`

## Assumptions

- Host Companion service and API schema already support existing onboarding flows.
- Existing secure storage and network constraints remain unchanged.

## Edge Cases

- Duplicate pairing token scans.
- Server endpoint changes while pairing session exists.
- Revoked device session is restored from a persisted stale secret.
