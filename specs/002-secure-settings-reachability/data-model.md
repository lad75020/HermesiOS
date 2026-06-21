# Data Model: Secure Settings and Reachability

## Gateway Credential

**Fields**:
- `identifier`: Logical credential name or service target.
- `secretValue`: Sensitive token stored through secure device storage.
- `lastUpdated`: Time the credential was last replaced or cleared.

**Validation Rules**:
- Secret values are not shown in normal UI summaries.
- Clearing a credential prevents stale values from being reused.

## Host Endpoint

**Fields**:
- `scheme`: Transport scheme.
- `host`: Hostname or address.
- `port`: Service port.
- `path`: Optional route prefix.
- `serviceRole`: API gateway, dashboard, companion, office, or related host service.

**Validation Rules**:
- Malformed endpoints are rejected with actionable feedback.
- Loopback plaintext is treated differently from non-loopback plaintext.
- Sensitive traffic must not use unsafe remote plaintext endpoints.

## Reachability State

**Fields**:
- `serviceRole`: Service being checked.
- `state`: Unknown, checking, reachable, unreachable, or degraded.
- `lastChecked`: Last check time.
- `message`: Non-secret user-facing detail.

**Validation Rules**:
- Status messages never reveal credentials.
- Checking and confirmed failure states are visually distinguishable.

## Onboarding Payload

**Fields**:
- `host`: Proposed host.
- `companionPort`: Proposed companion port.
- `pairingMaterial`: Optional enrollment data.
- `servicePorts`: Optional service port map.

**Validation Rules**:
- Payload must be parseable and relevant before applying.
- Endpoint security validation still runs after QR import.

## Endpoint Security Decision

**Fields**:
- `result`: Allow, warn, or block.
- `reason`: User-facing explanation.
- `affectedService`: Service role affected.
- `recommendedAction`: Safe correction path.

**Validation Rules**:
- Blocks are deterministic for unsafe remote plaintext sensitive traffic.
- Loopback development endpoints remain allowed when appropriate.
