# Plan: TUI Gateway

> ⚠️ **STALE**: spec.md was refined on 2026-08-24. Run `/speckit.refine.propagate` to update this plan.

## Technical Context

- UI/workflow entrypoint uses `HermesTUIGatewayView.swift` for sessions and message rendering.
- Session persistence and request submission are implemented through `HermesResponsesWorkspace.swift` and related workspace model helpers.
- WebSocket and dashboard URL handling are already shared with existing Hermes networking infrastructure.

## Approach

- Keep existing websocket transport and session model patterns as-is.
- Validate session flow integrity through direct review and focused verification notes.
- Strengthen user-visible transitions for session state, attention indicators, and resume actions.
- Document expected acceptance behavior for resuming and interruption.

## Implementation Tasks (phase hints)

- Phase 1: Verify stream event parsing and status transitions in `HermesTUIGatewayView.swift`.
- Phase 2: Verify attachment prompt, resume, and interrupt flows in `HermesResponsesWorkspace.swift`.
- Phase 3: Validate dashboard search + resume hookup and capture behavior notes.
- Phase 4: Finalize implementation notes and artifact closure.

## Acceptance Conditions

- Session lifecycle actions are coherent and deterministic.
- Streaming and completion/error attention states are observable and documented.
- Resume actions from search restore valid conversation context.
- Behavior is confirmed in implementation notes with no major ambiguity.
