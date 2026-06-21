# Research: TUI Gateway and Command Center

## Decision: Treat this feature as existing behavior to validate first

**Rationale**: The Time Machine queue was generated from an existing app. The safest path is to document expected behavior, verify the scoped files, and avoid source changes unless validation finds a concrete mismatch.

**Alternatives considered**:
- Rebuild the feature: rejected because it would create avoidable regression risk.
- Skip validation: rejected because specs must be grounded in current behavior and build readiness.

## Decision: Keep user-facing recovery states explicit

**Rationale**: HermesiOS depends on local and host-backed capabilities. Users need clear loading, empty, failed, unavailable, and success states without exposing sensitive internals.

**Alternatives considered**:
- Hide failures: rejected because it makes troubleshooting impossible.
- Show raw debug payloads by default: rejected because prompts, tokens, files, or tool data may be sensitive.

## Decision: Preserve shell and security boundaries

**Rationale**: The app shell, settings, and security posture are shared across features. This feature must not weaken host, credential, debug, file, or WebKit boundaries while documenting its behavior.

**Alternatives considered**:
- Make feature-specific exceptions to shell conventions: rejected because consistency is core to the companion experience.
