# Plan: Hermes API Client

## Technical Context

- Core API behavior is implemented in `HermesiOS/HermesResponsesAPI.swift` and `HermesiOS/HermesChatCompletionsAPI.swift`.
- Request construction and persistence behavior is shared through `HermesAPISettings` and `HermesSettingsPersistence`.
- Both endpoints rely on stable URL derivation plus optional bearer token and transport security checks.

## Approach

- Keep existing architecture and protocol behavior in place.
- Verify endpoint resolution, request headers, payload structure, and continuation identifiers.
- Validate attachment/path/stream parsing and status/error handling semantics for resilience.
- Confirm session continuity behavior and secure token persistence behavior.

## Implementation Tasks (phase hints)

- Phase 1: Audit Responses and Chat request builders for URL, headers, payload, and fallback logic.
- Phase 2: Verify streaming path handling, parser behavior, and completion/state transitions.
- Phase 3: Verify storage and configuration behavior for API key/profile/bearer token normalization.
- Phase 4: Add/update manual verification notes and evidence mapping.

## Acceptance Conditions

- No functional regressions introduced for Ask Hermes or Chat with Hermes interactions.
- Endpoint selection remains deterministic for host-only and already-path URLs.
- Response continuity/session headers remain stable across retries and follow-up turns.
- The feature artifacts are complete and traceable in Time Machine outputs.
