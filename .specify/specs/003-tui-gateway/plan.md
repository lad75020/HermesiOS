# Plan: TUI Gateway

**Propagated**: 2026-08-24 — Updated from spec.md refinement

## Technical Context

- UI/workflow entrypoint uses `HermesTUIGatewayView.swift` for sessions and message rendering.
- Session persistence and request submission are implemented through `HermesResponsesWorkspace.swift` and related workspace model helpers.
- WebSocket and dashboard URL handling are already shared with existing Hermes networking infrastructure.

## Approach

- Keep existing websocket transport and session model patterns as-is.
- Validate session flow integrity through direct review and focused verification notes.
- Strengthen user-visible transitions for session state, attention indicators, and resume actions.
- Document expected acceptance behavior for resuming and interruption.
- Remove the Session, Status, and Events pills from the TUI Gateway header and place inference controls in the composer.
- Load `profiles.list`, then request profile-scoped `model.options` and group/sort models by provider for selection.
- Keep model, provider, reasoning-effort, and speed selections workspace-scoped; gate reasoning and Fast controls by model capability.
- Include applicable inference selections in both `session.create` and `prompt.submit` JSON-RPC requests.
- Place the workspace-scoped profile selector before the model selector and reset each profile selection to its configured default model before allowing a model override.

## Implementation Tasks (phase hints)

- Phase 1: Verify stream event parsing and status transitions in `HermesTUIGatewayView.swift`.
- Phase 2: Verify attachment prompt, resume, and interrupt flows in `HermesResponsesWorkspace.swift`.
- Phase 3: Validate dashboard search + resume hookup and capture behavior notes.
- Phase 4: Finalize implementation notes and artifact closure.
- Phase 5: Validate composer profile/inference controls, profile-default model selection, capability gating, workspace-scoped selection, and gateway request parameters.

## Acceptance Conditions

- Session lifecycle actions are coherent and deterministic.
- Streaming and completion/error attention states are observable and documented.
- Resume actions from search restore valid conversation context.
- Behavior is confirmed in implementation notes with no major ambiguity.
- Header status pills are absent, and models are grouped in provider/name order in the composer.
- Unsupported reasoning and speed controls are unavailable for the selected model.
- Session creation and prompt submission carry the selected model/provider, reasoning effort, and applicable Fast flag.
- Selecting a profile creates a profile-scoped session with its default model while preserving per-profile model override selection.
