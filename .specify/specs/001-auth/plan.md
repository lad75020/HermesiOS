# Plan: Authentication & Pairing

## Technical Context

- SwiftUI client with websocket-backed companion transport.
- Existing persisted state in `HermesCompanionSettings` and `HermesCompanionIdentityState`.
- Runtime safety requires explicit gating before privileged RPC requests.

## Approach

- Keep current protocol and persistence model unchanged.
- Focus on hardening flow consistency and documenting expected behavior.
- Ensure all user-visible transitions are represented in a single UI summary.

## Implementation Tasks (phase hints)

- Phase 0: Verify decoding, persistence, and guard checks in existing client/session classes.
- Phase 1: Validate panel and settings visibility flows for pairing status.
- Phase 2: Add/refresh regression checks and traceability notes.

## Acceptance Conditions

- Feature behaves as specified on fresh install and relaunch.
- State transitions are deterministic and user-readable.
