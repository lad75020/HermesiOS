# Specification: TUI Gateway

Feature ID: `tui-gateway`

## Summary

Provide a robust terminal-style workspace that connects to the Hermes dashboard WebSocket gateway, lets users create and switch sessions, stream progress, and continue prior TUI sessions from dashboard history.

## User Stories

- As a user, I can start or reconnect to a live TUI Gateway session and see workspace state and session availability.
- As a user, I can submit prompts and see assistant response streaming with clear attention cues.
- As a user, I can interrupt, close, and resume specific TUI sessions.
- As a user, I can resume a previously run TUI workflow from the dashboard search results.

## Functional Requirements

- The app SHALL establish a valid WebSocket connection to the configured TUI gateway endpoint when entering a dashboard-aware workspace.
- The app SHALL expose session lifecycle actions for create, resume, close, interrupt, and refresh without losing local workspace state.
- The app SHALL render user prompts, assistant output, and event messages with role-aware differentiation.
- The app SHALL surface live attention states for streaming, completion, and failure so users can quickly respond.
- The app SHALL support attachment-assisted prompts when the input is file-backed and maintain request continuity.
- The app SHALL validate that sensitive content is not sent as plain text in logs when plaintext transport is blocked.
- The app SHALL keep dashboard search integration functional for resuming TUI sessions by session ID.

## Success Criteria

- Users can create a new TUI session, send at least one prompt, and observe progressive outputs.
- Users can complete or cancel a streamed output within 5 seconds of interruption.
- Session resume from history opens the expected prior context in under 2 seconds for normal network latency.
- Attention indicators switch correctly at least for streaming/completion/failure states during normal operation.
- No crashes occur on malformed websocket payloads or token refresh retries.

## Files in Scope

- `HermesiOS/HermesTUIGatewayView.swift`
- `HermesiOS/HermesResponsesWorkspace.swift`

## Assumptions

- Dashboard URL and API settings are supplied from existing global settings.
- The backend gateway provides active session IDs and message stream envelopes used by this client.
- Streamed output can be temporarily interrupted and resumed without immediate data-loss.

## Edge Cases

- WebSocket reconnects while a session is streaming.
- Missing or malformed session IDs in resume history results.
- Gateway token refresh failure and retry timing.
- Plaintext transport disallowed by policy and downgraded to secure submission paths.
- Duplicate event IDs and unordered event delivery from the gateway.
