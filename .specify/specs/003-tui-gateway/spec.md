# Specification: TUI Gateway

Feature ID: `tui-gateway`

**Status**: Refined

**Refined**: 2026-08-24 — Replaced header status pills with composer inference controls for profile, model, reasoning effort, and speed; condensed iPhone controls into a confirmed popover.

## Summary

Provide a robust terminal-style workspace that connects to the Hermes dashboard WebSocket gateway, lets users create and switch sessions, stream progress, and continue prior TUI sessions from dashboard history.

## User Stories

- As a user, I can start or reconnect to a live TUI Gateway session and see workspace state and session availability.
- As a user, I can submit prompts and see assistant response streaming with clear attention cues.
- As a user, I can interrupt, close, and resume specific TUI sessions.
- As a user, I can resume a previously run TUI workflow from the dashboard search results.
- As a user, I can choose the Hermes Agent model, supported reasoning effort, and available inference speed for each TUI Gateway workspace before sending a prompt.
- As a user, I can choose the Hermes profile my TUI Gateway workspace uses and begin with that profile's default model while retaining the ability to override it.

## Functional Requirements

- The app SHALL establish a valid WebSocket connection to the configured TUI gateway endpoint when entering a dashboard-aware workspace.
- The app SHALL expose session lifecycle actions for create, resume, close, interrupt, and refresh without losing local workspace state.
- The app SHALL render user prompts, assistant output, and event messages with role-aware differentiation.
- The app SHALL surface live attention states for streaming, completion, and failure so users can quickly respond.
- The app SHALL support attachment-assisted prompts when the input is file-backed and maintain request continuity.
- The app SHALL validate that sensitive content is not sent as plain text in logs when plaintext transport is blocked.
- The app SHALL keep dashboard search integration functional for resuming TUI sessions by session ID.
- The TUI Gateway header SHALL not render the Session, Status, or Events status pills.
- The TUI Gateway composer SHALL load all selectable Hermes Agent models from the gateway `model.options` JSON-RPC method and present them grouped and sorted by provider.
- The TUI Gateway composer SHALL load selectable profiles from `profiles.list`, render the profile control to the left of the model control, and scope `model.options` to the selected profile.
- Selecting a profile SHALL select that profile's configured default model and create a new profile-scoped TUI session; users MAY subsequently choose any model available to that profile.
- The selected model and provider SHALL be passed in `session.create` and `prompt.submit` requests so both new and existing sessions use the selection.
- The composer SHALL show only reasoning-effort choices supported by the selected model and pass the selected effort in `session.create` and `prompt.submit` requests.
- The composer SHALL expose Normal and Fast speed choices only when the selected model advertises fast-inference capability, and pass the selected speed through the gateway session and prompt requests.
- Model, reasoning-effort, and speed selections SHALL remain workspace-scoped while the workspace is active.
- Profile selection SHALL remain workspace-scoped and be included in profile-scoped TUI session requests.
- On iPhone compact-width layouts only, the four inference controls SHALL be hidden behind one accessible inference icon that presents a popover with draft controls and a validation action.
- The iPhone validation action SHALL close the popover and apply all draft inference selections together before the next inference; iPad layouts SHALL retain their inline inference controls.

## Success Criteria

- Users can create a new TUI session, send at least one prompt, and observe progressive outputs.
- Users can complete or cancel a streamed output within 5 seconds of interruption.
- Session resume from history opens the expected prior context in under 2 seconds for normal network latency.
- Attention indicators switch correctly at least for streaming/completion/failure states during normal operation.
- No crashes occur on malformed websocket payloads or token refresh retries.
- Models are grouped by provider and displayed in provider/name order, while unsupported reasoning and speed controls remain unavailable.
- A prompt submitted after changing any inference control reaches the gateway with the selected model/provider, reasoning effort, and applicable fast flag.
- A profile change switches subsequent TUI work to a fresh session configured for that profile and its default model.
- On iPhone, the inference icon opens a popover, and its validation control applies the selected profile/model/reasoning/speed values without changing the iPad composer layout.

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
