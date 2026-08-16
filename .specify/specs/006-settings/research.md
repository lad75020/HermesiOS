# Research: Settings & Configuration

## Decision: Endpoint normalization strategy

**Decision**
- Use existing `HermesHostEndpoints` normalization and URL constructor functions for all host/port edits.

**Rationale**
- The code already normalizes host input, extracts ports from URL/path, and preserves compatibility behavior (`defaultHermesMacHost`, legacy dashboard port mapping) in one location.

**Alternatives considered**
- Reimplement host parsing in settings UI.
- Accept arbitrary host/path input and push parsing downstream.

**Outcome**
- Keep a single normalization path in `HermesHostEndpoints` to avoid divergence between view, persistence, and runtime refresh keys.

## Decision: Transport warning and secure transport policy

**Decision**
- Keep plaintext transport restrictions in `HermesEndpointSecurity` with explicit exceptions for localhost and `.ts.net` hosts.

**Rationale**
- Security policy already exists and is used by both API and companion sections in the UI.

**Alternatives considered**
- Remove plaintext checks in settings and rely on runtime failures.
- Add a separate user-toggle bypass.

**Outcome**
- Keep restrictions and preserve warning-first behavior; do not add a bypass switch.

## Decision: Secret persistence model

**Decision**
- Preserve current layered persistence:
- API token and companion device secret kept in Keychain-backed persistence entries; mutable config serialized via UserDefaults.

**Rationale**
- Secret raw values are currently redacted from Codable settings before persistence; this reduces accidental leak risk and matches existing handling.

**Alternatives considered**
- Store all raw fields in UserDefaults.
- Move all secrets to plain Secure Enclave-only storage (too invasive for current feature scope).

**Outcome**
- Keep current pattern; no structural secret-model changes in this planning pass.

## Decision: Host switching with active enrollment state

**Decision**
- Keep host activation and connection selection inside existing companion enrollment session flow (`activeConnectionID` + `syncActiveCompanionConnectionToSettings`).

**Rationale**
- Existing session logic already handles stale-state invalidation, approval checks, and persistence updates.

**Alternatives considered**
- Introduce independent Settings-only selection state and reconcile later.

**Outcome**
- Continue using enrollment/session as the single source of truth for active companion selection.

## Decision: Quickstart coverage scope

**Decision**
- Focus quickstart on user and developer validation for API/base URL, companion onboarding, saved host management, service-port derivation, and tailscale serve behavior.

**Rationale**
- These paths are highest-impact for this feature and already exercised by current UI sections.

**Alternatives considered**
- Extend quickstart to every downstream runtime surface.

**Outcome**
- Keep scope tight to settings screens and immediate dependencies to keep verification fast and repeatable.

## Open dependency checks (to confirm in implementation)

- Verify whether any additional persistence keys are required by future plan items and whether they remain within the 006-settings scope.
- Confirm dashboard/runtime status refresh behavior when host and companion settings change at runtime (especially while sessions are active).
- Validate onboarding QR payload migration behavior for legacy fields across app upgrades.
