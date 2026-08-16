# Plan: Settings & Configuration

## Technical Context

- Settings are implemented in `HermesiOS/HermesSettingsView.swift`, with persisted state from `HermesSettingsPersistence.swift` and domain models in `HermesResponsesAPI.swift` (`HermesAPISettings`), `HermesCompanionClient.swift` (`HermesCompanionSettings`, `HermesCompanionIdentityState`, `HermesCompanionSavedConnection`), and `HermesHostEndpoints.swift`.
- Host connection behavior is also consumed across the app in `ContentView.swift` (`apiSettings`, `companionSettings`, port-derived URLs, and runtime/session refresh keys).
- Companion enrollment persistence is session-managed in `HermesCompanionClient.swift` (`HermesCompanionEnrollmentSession`) and writes to `HermesSettingsPersistence`.
- Transport policy and endpoint normalization rely on `HermesHostEndpoints` + `HermesEndpointSecurity`.
- The scope is mainly UI + persistence + cross-screen propagation, not protocol definitions.

## Approach

- Verify that all feature requirements are represented in the code path above and that no additional settings-related state exists outside the declared scope files.
- Resolve all requirement-level unknowns in one **Research** pass and turn them into explicit implementation constraints.
- Define a concrete data model for all persisted and runtime-visible settings entities.
- Draft quickstart steps aligned with existing navigation, so another engineer can validate settings behavior without rereading code.

## Foundation: Research & Validation Decisions

- Adopt existing endpoint-normalization logic instead of introducing new parsing rules.
- Keep secure-secret handling in `Keychain` and existing redaction behavior (do not persist raw secrets in JSON payloads).
- Keep saved-host switching coupled to existing enrollment/session logic and gating rules in `HermesCompanionEnrollmentSession`.
- Keep App Storage persistence for ports/theme via existing keys; do not introduce new global keys unless required by this feature.

## Implementation Tasks (phase hints)

### Phase 0 — Research and decision capture

- Resolve any clarifications in `HermesAPISettings`, companion pairing states, and service-port orchestration based on current behavior.
- Confirm edge-case handling for malformed host/path inputs and non-enrolled states.
- Record decisions in `research.md` with alternatives considered.

### Phase 1 — Design artifacts

- Create `research.md` and add explicit decisions for:
  - Transport validation + exception policy (localhost / tailnet exceptions).
  - Saved-host switching and active-connection precedence.
  - Workspace and service-port synchronization semantics.
  - Secret persistence and migration constraints.
- Create `data-model.md` with entities, invariants, and state transitions.
- Create `quickstart.md` for implementer verification of user flows.
- Add/verify interface contract notes if the team decides any external contract is exposed through settings (API, companion status endpoints).

### Phase 2 — Readiness and consistency

- Validate generated planning artifacts for placeholders, unresolved clarifications, and consistency with `spec.md`.
- Re-run the same spec/plan linkage checks used by existing feature queues:
  - feature path consistency: `.specify/specs/006-settings/`
  - artifact coverage: `plan.md`, `research.md`, `data-model.md`, `quickstart.md`
- Confirm no existing checklist or spec references are violated.

## Acceptance Conditions

- `plan.md`, `research.md`, `data-model.md`, and `quickstart.md` exist under `.specify/specs/006-settings`.
- Research explicitly records all uncertainty resolution points with a decision + rationale + alternatives.
- Data model captures saved-host switching behavior and companion trust-state transitions.
- No unresolved `NEEDS CLARIFICATION` remains in generated planning artifacts.
- Planned behavior stays aligned with current in-scope files listed in `spec.md`.
- No new feature requirements or file scope are added in planning stage beyond this feature.

## Planned Gates (default, no local constitution file present)

- Security: no secrets printed in diagnostics; plaintext transport policy remains enforced for remote non-loopback/non-tailnet endpoints.
- Usability: host/secret changes are recoverable and visibly reflected in dependent screens.
- Reliability: stale host/secret states must not silently leak into active runtime sessions.
- Data persistence: settings and host selections must survive app relaunches.
- Scope control: do not broaden into runtime panels behavior in this feature pass.
