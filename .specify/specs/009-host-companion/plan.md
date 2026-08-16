# Plan: Host Companion Service

## Technical Context

- Host Companion process entry points:
  - `HermesHostCompanion/HermesHostCompanionApp.swift`
    - `CompanionServerController` owns `CompanionServer`, launches/restarts the server, exposes onboarding/network/service-port controls, emits device list refresh loop, and exposes UI state for status/errors.
  - `HermesHostCompanion/CompanionServer.swift`
    - `CompanionServer` binds `NWListener` on loopback (`127.0.0.1`), tracks lifecycle state (`stopped/starting/running/failed`), creates/disposes `CompanionClientSession`s and dispatches requests.
    - `CompanionServerConfiguration` sanitizes host/port and builds advertised websocket URL.
  - `HermesHostCompanion/CompanionProtocol.swift`
    - Shared protocol and payload model definitions for all request/response envelopes.
  - Registry modules behind request routing:
    - `CompanionTargetRegistry.swift` (targets, revisions, validation, backups, skill state)
    - `CompanionFileDownloadRegistry.swift` (directory browse and full/chunked downloads)
    - `CompanionServiceRegistry.swift` (service status/start/stop/restart)
    - `CompanionTailscaleServeRegistry.swift`
    - `CompanionProviderRegistry.swift`, `CompanionModelRegistry.swift`, `CompanionProfileRegistry.swift`, `CompanionToolsetRegistry.swift`, `CompanionMemoryRegistry.swift`, `CompanionScheduleRegistry.swift`, `CompanionLogRegistry.swift`, `CompanionGatewayRegistry.swift`, `CompanionMCPRegistry.swift`, `CompanionKnowledgeEraserRegistry.swift`, `CompanionGitRegistry.swift`
  - `CompanionDeviceAuthorizationStore` in `CompanionServer.swift`
    - enrollment state, onboarding code rotation, secure secret fingerprint matching, approval/revoke lifecycle.

- iOS client and runtime surfaces:
  - `HermesiOS/HermesCompanionClient.swift`
    - Onboarding parsing and enrollment/session models (`HermesCompanionSettings`, `HermesCompanionIdentityState`, `HermesCompanionSavedConnection`).
    - Typed protocol envelope mirror: `HermesCompanionIncomingEnvelope`, `HermesCompanionOutgoingEnvelope`, typed payload/result structs.
    - `HermesCompanionSessionFactory.request(...)` for request dispatch and decoding.
  - `HermesCompanionRuntimeSession` in the same file
    - owns live runtime state used by panels (targets, diagnostics, service states, logs, model/provider/memory/toolset/MCP/schedules/gateway/schedules/installation and tailscale views).
  - Runtime/runtime panel entry points (`HermesCompanionPanel.swift`, `HermesCompanionSettingsView`, `HermesToolsPanel`, etc.) consume `HermesCompanionRuntimeSession` for user interactions.

- Existing request coverage is already broad and includes all capability names declared by `hello`. The current feature specifically scopes to ensuring server-side behavior and protocol stability for onboarding, target write safety, session/authorization, service operations, file browsing/download flows, and runtime-management surfaces.

- Known constraints to honor:
  - Secret/token material must not be logged in plaintext.
  - Unauthenticated operations are currently only `enroll_device` and `check_device_approval`.
  - Many operations are multi-tenant by workspace/profile and require explicit workspace resolution path validation.
  - Target writes are revision-aware and rely on SHA-256 content digest for concurrency protection.
  - File upload remains unsupported by this service; only read/metadata/download flows are planned.

## Approach

- Keep feature strictly in the Host Companion scope: companion protocol/schema, route behavior, authorization lifecycle, registry behavior, and iOS runtime contract assumptions.
- Make protocol behavior deterministic and explicit for all paths:
  - unknown payload handling,
  - malformed request handling,
  - unauthorized operations,
  - revision mismatches,
  - validation failures.
- Preserve existing implementation footprint and extend only when planning identifies missing consistency (for example, explicit artifact and contract documentation).
- Reduce accidental regressions by tracing each operation from protocol definition (`CompanionProtocol.swift`) to request handlers (`CompanionClientSession.route`) to client-facing runtime usage (`HermesCompanionRuntimeSession`).

## Implementation Plan by Phase

### Phase 0 — Research and Decision Capture

- Resolve and document key protocol/runtime decisions from current behavior in `research.md`:
  - auth model and allowed unauthenticated paths,
  - workspace/profile resolution for target and profile-backed operations,
  - revision handling and conflict outcome behavior,
  - file download completion semantics (`isComplete`, chunk boundaries, metadata-first flow),
  - tailscale/installation/gateway error surfaces,
  - policy for unknown operation codes and malformed envelopes.
- Validate no spec placeholders remain unresolved in target artifacts once generated.

### Phase 1 — Design Artifacts

- Create `research.md` from the above decisions.
- Create `data-model.md` covering server, authorization, protocol envelope, and target/config/runtime entities.
- Create `quickstart.md` describing reproducible validation steps for each major domain:
  - pairing/approval,
  - target read/validate/write with revision,
  - backup + restore,
  - file browse/download (single and chunked),
  - service controls,
  - companion config/profile-target updates.
- Create `contracts/companion-websocket-contract.md` describing:
  - websocket transport + endpoint naming,
  - authenticated/unauthenticated operation matrix,
  - request/response envelope fields,
  - typed payload/result/error code expectations,
  - operation catalog for implementation verification.

### Phase 2 — Readiness and Consistency Checks

- Ensure artifacts exist:
  - `.specify/specs/009-host-companion/plan.md`
  - `.specify/specs/009-host-companion/research.md`
  - `.specify/specs/009-host-companion/data-model.md`
  - `.specify/specs/009-host-companion/quickstart.md`
  - `.specify/specs/009-host-companion/contracts/companion-websocket-contract.md`
- Verify no `NEEDS CLARIFICATION` remains in generated artifacts.
- Confirm artifact scope is limited to this feature’s in-scope files and behaviors.

## Acceptance Conditions

- Planning artifacts are complete and mutually consistent:
  - every capability listed in protocol/route code is represented in contracts or explicitly out-of-scope for this feature.
  - every major state transition in `CompanionServer` / `CompanionDeviceAuthorizationStore` / `CompanionTargetRegistry` / `HermesCompanionRuntimeSession` is captured in `data-model.md`.
  - quickstart steps can be executed independently after a clean checkout of the branch.
- No unresolved placeholders in any required artifact.
- No scope drift: keep `implementation-notes` and design to Runtime + Host Companion protocol + companion operations only.

## Constitution Check

- No local `.specify/memory/constitution.md` exists, so treat this as template-only governance.
- Apply default gates:
  - Security: secrets remain fingerprinted/hashed in logs, no plaintext secrets in stable outputs.
  - Reliability: unsupported/invalid requests do not tear down the connection and return typed error responses.
  - Usability: approval-required actions fail with explicit authorization outcomes.
  - Testability: deterministic operation catalog and request IDs.
  - Scope control: no UI redesign scope creep beyond host-companion operation surfaces and supporting runtime behavior.

## Planned Gates (default gates)

- Security: enforce device secret matching, avoid raw secret logging, keep API key onboarding path non-plain in runtime UI and state stores.
- Reliability: malformed/unauthorized requests return deterministic error envelopes; server continues to accept subsequent requests.
- Consistency: revision checks block stale target writes and surface explicit diagnostics.
- Accessibility: companion status and approval states have user-visible labels consistent with existing UI patterns.
- Build/readiness: planning artifacts are generated before implementation starts for this feature.
