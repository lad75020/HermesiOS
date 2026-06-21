# Feature Specification: Secure Settings and Reachability

**Feature Branch**: `feature/time-machine-secure-settings-reachability`

**Created**: 2026-06-21

**Status**: Draft

**Input**: User description: "Feature: Secure Settings and Reachability. Description: Lets users configure API credentials, trusted host endpoints, service ports, QR onboarding data, and live connectivity state securely on device. Relevant files: HermesiOS/HermesSettingsView.swift, HermesiOS/HermesSettingsPersistence.swift, HermesiOS/HermesHostEndpoints.swift, HermesiOS/HermesStatusBand.swift. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure Trusted Hermes Access (Priority: P1)

As a HermesiOS user, I want to enter or scan trusted Hermes host connection details and credentials so that the app can reach my own Hermes services without exposing secrets unnecessarily.

**Why this priority**: Without secure connection settings, every host-backed capability is unavailable or risky.

**Independent Test**: Open Settings, configure host and credential values, leave Settings, return, and verify sensitive values persist securely while non-sensitive endpoint values remain understandable.

**Acceptance Scenarios**:

1. **Given** the user has a valid Hermes gateway bearer token, **When** they save it in Settings, **Then** the app persists it through the secure storage path and uses it for authorized gateway checks.
2. **Given** the user scans companion onboarding data, **When** the QR content is accepted, **Then** host and port fields are populated without requiring manual transcription.
3. **Given** the user clears or replaces a credential, **When** Settings reloads, **Then** stale credential material is no longer used.

---

### User Story 2 - See Reachability at a Glance (Priority: P2)

As a user troubleshooting Hermes connectivity, I want clear status indicators for API, dashboard, companion, and related services so that I can tell what is reachable and what needs attention.

**Why this priority**: Host-backed features depend on several services, and users need fast diagnosis when one service is down.

**Independent Test**: Configure reachable and unreachable service endpoints, then verify the status band distinguishes reachable, unreachable, checking, and unknown states.

**Acceptance Scenarios**:

1. **Given** a service endpoint is reachable, **When** reachability checks run, **Then** the status band shows a successful state for that service.
2. **Given** a service endpoint is unreachable, **When** reachability checks run, **Then** the status band shows a failure or unavailable state without blocking the shell.
3. **Given** checks are still running, **When** the status band renders, **Then** the user can distinguish in-progress checks from confirmed failures.

---

### User Story 3 - Enforce Safe Endpoint Boundaries (Priority: P3)

As a security-conscious user, I want the app to warn or block unsafe endpoint combinations so that credentials and session data are not sent to untrusted plaintext destinations.

**Why this priority**: Secure defaults reduce the chance of leaking bearer tokens, prompts, or host-control data during setup.

**Independent Test**: Attempt to configure loopback, local network, Tailscale HTTPS, and non-loopback plaintext endpoints, then verify the app applies safe defaults and clear error messages.

**Acceptance Scenarios**:

1. **Given** a non-loopback plaintext endpoint would carry sensitive data, **When** the user tries to use it, **Then** the app rejects it or requires an explicit safe alternative.
2. **Given** a loopback development endpoint is configured, **When** validation runs, **Then** the app allows it as a local development path.
3. **Given** an endpoint string is malformed, **When** Settings validates it, **Then** the user receives a clear correction path without losing unrelated settings.

---

### Edge Cases

- QR onboarding content may be malformed, stale, or for a different host.
- A service can change from reachable to unreachable while Settings is open.
- Credentials may be absent, expired, revoked, or replaced.
- Hostnames may represent loopback, local network, Tailscale, or public endpoints with different security expectations.
- Reachability checks must not store secrets in logs or user-visible debug output.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST let users view and edit Hermes host, gateway, dashboard, companion, and service-port settings from a dedicated Settings surface.
- **FR-002**: The system MUST store bearer tokens and similarly sensitive credentials using secure device storage rather than plain preference storage.
- **FR-003**: The system MUST support QR-based companion onboarding that populates supported host and pairing fields.
- **FR-004**: The system MUST validate endpoint security before sensitive credentials, prompts, files, or session data are sent.
- **FR-005**: The system MUST distinguish loopback development endpoints from remote endpoints when evaluating plaintext transport risk.
- **FR-006**: The system MUST show live service reachability states for user-relevant Hermes services.
- **FR-007**: The system MUST preserve non-sensitive settings across launches while allowing users to clear or replace sensitive settings.
- **FR-008**: The system MUST present actionable error messages for invalid settings, unreachable services, and unsafe endpoint combinations.
- **FR-009**: The system MUST avoid exposing credential values in status labels, logs, or normal settings summaries.

### Key Entities *(include if feature involves data)*

- **Gateway Credential**: Sensitive bearer or access value used for authorized Hermes API calls.
- **Host Endpoint**: Hostname, scheme, port, and path combination used to reach a Hermes service.
- **Reachability State**: User-visible state for a service check, such as unknown, checking, reachable, or unreachable.
- **Onboarding Payload**: QR-derived host and companion connection data.
- **Endpoint Security Decision**: Validation outcome that allows, warns, or blocks use of a configured endpoint.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can configure a valid host and credential path in under 3 minutes.
- **SC-002**: Sensitive credential values are never visible in normal settings summaries or reachability status text.
- **SC-003**: Reachability checks report a clear state for configured core services within 10 seconds under normal network conditions.
- **SC-004**: Unsafe non-loopback plaintext endpoints carrying sensitive data are blocked or rejected in 100% of validation attempts.
- **SC-005**: Loopback development endpoints remain configurable without weakening remote endpoint safety rules.

## Assumptions

- The app continues to support local development endpoints for simulator and Mac-hosted Hermes workflows.
- Remote physical-device workflows should prefer HTTPS/WSS, including Tailscale Serve paths.
- Existing Keychain and LocalAuthentication usage remain the secure storage baseline for sensitive settings.
- This feature does not own the detailed behavior of downstream service panels; it owns settings, endpoint validation, and reachability presentation.
