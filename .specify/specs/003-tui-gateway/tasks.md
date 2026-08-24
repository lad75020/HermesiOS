# Tasks: TUI Gateway

**Propagated**: 2026-08-24 — Updated from spec.md refinement

- [x] T001 Verify session create and connect behavior in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T002 [US1] [US2] Validate WebSocket resume path and message streaming continuity in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T003 [US1] [US2] Verify workspace state resets, attention states, and completion/failure visibility in `HermesiOS/HermesResponsesWorkspace.swift`.
- [x] T004 [US1] [US2] Validate interrupt and close transitions in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T005 Verify attachment prompt handling in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T006 [US3] Confirm resume workflow from dashboard history in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T007 [P] Validate request/response parsing helpers and edge-cases in `HermesiOS/HermesTUIGatewayView.swift` and `HermesiOS/HermesResponsesWorkspace.swift`.
- [x] T008 Polish artifact trail by updating `/.specify/specs/003-tui-gateway/implementation-notes.md` and `/.specify/specs/003-tui-gateway/checklists/requirements.md`.

## Phase 5: Composer Inference Controls (US5)

- [x] T009 [US5] Remove the Session, Status, and Events pills from the TUI Gateway header in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T010 [US5] Load `model.options` and decode selectable models with provider and capability metadata in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T011 [US5] Group and sort the model menu by provider and model name in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T012 [US5] Add workspace-scoped model, reasoning-effort, and speed selection with capability-gated controls in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T013 [US5] Pass model/provider, reasoning effort, and applicable Fast state through `session.create` and `prompt.submit` requests in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T014 [US5] Load `profiles.list`, add a profile picker before the model picker, and request profile-scoped model options in `HermesiOS/HermesTUIGatewayView.swift`.
- [x] T015 [US5] Select the chosen profile's configured default model, create a new profile-scoped TUI session, and preserve model override capability in `HermesiOS/HermesTUIGatewayView.swift`.
