# Specification: Hermes API Client

Feature ID: `api-client`

## Summary

OpenAI-compatible Hermes API access for Ask Hermes (Responses) and Chat with Hermes (Chat Completions), including bearer token handling, profile selection, streaming and request/response continuity.

## User Stories

- As a user, I can send prompts to Ask Hermes and receive responses from the configured Hermes API gateway.
- As a user, I can run Chat with Hermes in a separate conversation thread with independent history.
- As a user, I can enable Bearer auth and profile routing so gateway access stays secure and predictable.
- As a user, I can attach files and still receive stable responses from the API paths.

## Functional Requirements

- The app SHALL send Responses requests to the resolved `responses` endpoint derived from the configured API base URL.
- The app SHALL send Chat Completions requests to the resolved `chat/completions` endpoint derived from the same base URL.
- The app SHALL include bearer auth via the `Authorization` header when provided.
- The app SHALL support optional streaming for both Responses and Chat Completions.
- The app SHALL persist API token in secure storage and avoid writing plain token text in non-keychain settings payloads.
- The app SHALL continue Conversations by reusing prior response/session IDs and chat session IDs when available.
- The app SHALL expose stable status and error states for in-progress, completed, cancelled, and failure scenarios.

## Success Criteria

- Asking Hermes and chatting both route to the expected OpenAI-compatible gateway path for valid base URLs.
- Streaming responses are shown in near-real-time in the chat bubbles; non-streaming responses return final assistant content.
- Responses include profile headers and reasoned effort parameters when selected.
- A 401/invalid response clearly indicates auth or token mismatch; invalid/malformed URLs are surfaced to the user.
- API token persists across app restarts without being written in cleartext to shared settings.

## Files in Scope

- `HermesiOS/HermesResponsesAPI.swift`
- `HermesiOS/HermesChatCompletionsAPI.swift`

## Assumptions

- The Hermes gateway exposes OpenAI-compatible endpoints and optionally requires a bearer token.
- Stream mode is a supported transport for the user-selected request type.
- `HermesEndpointSecurity` rules for base URL safety are already enforced at request-time.

## Edge Cases

- API base URL is entered as a bare host/port and still resolves to `/v1/<endpoint>`.
- Mixed endpoint paths are provided and normalized to valid `/v1/...` targets.
- Token contains a `Bearer ` prefix and is still accepted after normalization.
- Gateway returns non-2xx status or invalid payload shape while streaming.
- A request is cancelled while streaming and connection state resets cleanly.
