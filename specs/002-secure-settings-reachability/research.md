# Research: Secure Settings and Reachability

## Decision: Keep sensitive credentials in secure device storage

**Rationale**: Hermes gateway bearer tokens and companion secrets can authorize private prompts, files, and host-control actions. Existing settings persistence imports Security and LocalAuthentication, which matches the secure-storage requirement.

**Alternatives considered**:
- Store tokens in plain preferences: rejected because it exposes high-value credentials.
- Require users to paste credentials every launch: rejected because it damages usability and encourages insecure workarounds.

## Decision: Treat endpoint security as a first-class settings validation outcome

**Rationale**: HermesiOS supports loopback, local Mac, Tailscale, and potentially remote endpoints. Plaintext loopback can be acceptable for local development, while non-loopback plaintext carrying bearer tokens or prompts is high risk.

**Alternatives considered**:
- Globally reject all plaintext endpoints: rejected because simulator and local development workflows need loopback support.
- Accept all user-entered endpoints: rejected because accidental remote plaintext credential leakage is too risky.

## Decision: Keep reachability user-facing and non-blocking

**Rationale**: Reachability helps troubleshooting but must not prevent the shell or settings UI from opening. Status should distinguish checking, reachable, unreachable, and unknown without exposing secrets.

**Alternatives considered**:
- Block access until every service is reachable: rejected because it prevents recovery when settings are wrong.
- Hide reachability state: rejected because users need service-level diagnosis.

## Decision: Use QR onboarding as convenience, not blind trust

**Rationale**: QR payloads reduce transcription errors, but malformed or stale payloads must still be validated and not bypass endpoint security decisions.

**Alternatives considered**:
- Manual-only settings: rejected because host companion pairing is error-prone.
- Trust all QR payloads: rejected because QR contents can be stale or malformed.
