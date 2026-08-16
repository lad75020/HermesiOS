# Plan: Agent Runtime Panels

## Technical Context

Runtime panel screens are implemented in the iOS Hermes app and coordinated through `HermesCompanionRuntimeSession`, which persists companion state and executes host companion commands. The feature touches multiple panel views rather than a single workflow.

## Approach

- Confirm all runtime panel views are connected to the same companion session model and that enrollment guards are consistently applied.
- Validate each panel’s read path and summary/path state propagation for consistency with current host runtime.
- Validate write actions for configuration fields, toggles, and management operations.
- Confirm safe fallback behavior when host payloads are empty, delayed, or return partial values.
- Verify that user feedback is explicit for errors and completion states (status text, last operation output, confirmation affordances).

## Implementation Tasks (phase hints)

- Phase 1: Validate Memory and Models panels for runtime and provider summary, add/edit flows, and error handling.
- Phase 2: Validate Providers, Profiles, and Tools panels for connection gating, list rendering, and update commands.
- Phase 3: Validate MCP Servers and Schedules panels for add/edit/delete and refresh behavior.
- Phase 4: Validate Observability and Skills panels for log retrieval controls, filtering/search, and toggle persistence.
- Phase 5: Validate implementation artifacts, checklist completion, and queue handoff consistency.

## Acceptance Conditions

- Every runtime panel is present and functional in the target branch with current companion session integration.
- Enrollment gating is observable and prevents unsafe write operations.
- Write operations emit either local success cues or error messages for troubleshooting.
- Edge cases (empty data, unavailability, partial host responses) do not crash the UI and show clear user guidance.
- Specification artifacts and implementation notes are complete before wrap-up.
