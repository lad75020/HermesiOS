# Implementation Notes

This feature is currently represented by existing behavior in:

- `HermesiOS/HermesResponsesAPI.swift`
- `HermesiOS/HermesChatCompletionsAPI.swift`

During this Time Machine pass, implementation work remains artifact-first and behavior-confirmation only.

Current API behavior confirmed:

- `HermesAPISettings` resolves both `responses` and `chat/completions` paths and supports bearer token normalization.
- API requests are sent with request ID/profile/session continuation headers and support streaming.
- Response IDs/session IDs are persisted for continuation.
- Token persistence uses keychain-backed loading/saving through settings helpers.

Branch: `feature/time-machine-api-client`
Feature directory: `.specify/specs/002-api-client`
Status: feature files created and scoped for verification in this pass.

- Wrap-up: artifact pass completed for feature/branch `feature/time-machine-api-client` with branch-local implementation-notes and behavior confirmation captured in this pass.
