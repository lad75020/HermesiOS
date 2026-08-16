# Research: Host Companion Service

## Decision 1: Protocol version and transport defaults

- Decision: Keep WebSocket protocol version at `1` and use advertised websocket URL format produced by `CompanionServerConfiguration.webSocketURLString`.
- Rationale:
  - The iOS-side onboarding decoder expects `version == 1` and fails enrollment if mismatch.
  - Current client/server already share this implicit contract and changing it would require a coordinated migration.
- Alternatives considered:
  - Introduce a multi-version negotiation layer.
  - Keep a hard-coded version 1 while versioning payloads per operation.
- Why rejected:
  - No migration pressure yet and current ecosystem is stable around a single contract.

## Decision 2: Authorization gate behavior

- Decision: Only `enroll_device` and `check_device_approval` remain unauthenticated; all other operations require approved device state and matching secret fingerprint.
- Rationale:
  - Existing server-side logic centralizes this in `route(...)` and `CompanionDeviceAuthorizationStore.authenticate(...)`; keeping it stable minimizes regression risk.
  - iOS flows already rely on explicit approval state and `check_device_approval` polling.
- Alternatives considered:
  - Allow read-only public operations.
  - Move to bearer-token auth only.
- Why rejected:
  - Public read access adds risk and is not currently required by iOS UX; token migration would require broad platform changes.

## Decision 3: Target write safety and revision control

- Decision: Keep revision matching mandatory for `write_target` and `restore_backup`, with `revisionMismatch` rejected via typed error.
- Rationale:
  - Prevents silent overwrite from stale editor state and preserves operator trust in companion config editing flows.
  - Current UI already surfaces `currentRevision` and expects deterministic update/refresh after save.
- Alternatives considered:
  - Allow force-write.
  - Add optimistic writes with server-side merge.
- Why rejected:
  - Merge semantics are not yet specified for all target formats and increase risk for high-impact runtime files.

## Decision 4: YAML validation dependency

- Decision: Keep Python-based YAML validation path with warning fallback when parser unavailable; treat parse failure as hard error only when parser output is explicit.
- Rationale:
  - Existing behavior already emits warning diagnostics instead of blocking if Python/PyYAML is unavailable.
  - Avoids hard service breakage on environments missing optional tooling while still surfacing validation risk.
- Alternatives considered:
  - Remove Python dependency and disable validation.
  - Make parser hard-required.
- Why rejected:
  - Full removal weakens integrity checks; hard-required fails on valid installs lacking parser.

## Decision 5: File download behavior

- Decision: Keep both full-file and chunked download APIs; full-file for convenience and chunked for large artifacts.
- Rationale:
  - `HermesCompanionRuntimeSession` and UI surfaces already map to both `download_file[_info|_chunk]` semantics.
  - Chunked output currently communicates byte offsets and completion status needed for large result handling.
- Alternatives considered:
  - Keep only chunked transfer.
  - Keep only full-file transfer.
- Why rejected:
  - Single-mode transfer increases implementation risk for either tiny files (chunking overhead) or large files (memory pressure).

## Decision 6: Service and runtime-management operation surface

- Decision: Treat service/installation/runtime-management operations as in-scope interface contract for this feature because capability list and iOS panels already depend on them and they are advertised by `hello`.
- Rationale:
  - Feature spec explicitly includes service lifecycle, tailscale serve, runtime mgmt and profile/model/toolset/provider memory operations.
  - Client panels currently call these ops directly under enrolled state.
- Alternatives considered:
  - Restrict scope to pure onboarding + target editing only.
  - Defer service/runtime management to later feature.
- Why rejected:
  - The spec and onboarding payload model already expose this as part of expected companion behavior; limiting now introduces partial contract ambiguity.

## Outcome

- No unresolved `NEEDS CLARIFICATION` remains for current implementation intent.
- No additional external dependencies are required by this planning pass.
