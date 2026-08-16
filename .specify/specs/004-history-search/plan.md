# Plan: History & Search

## Technical Context

- Search UI is implemented in `HermesiOS/HermesHistoryView.swift` and drives `HermesDashboardHistorySearchSession` from `HermesiOS/HermesDashboardHistorySearch.swift`.
- Resume actions are delegated to destination workspace callbacks in `ContentView.swift`.

## Approach

- Validate that search execution remains resilient to empty queries, cancellations, timeouts, and token refresh failures.
- Validate that profile filtering and matched-count presentation reflect backend results and local filtering behavior.
- Confirm resume actions for Ask Hermes, Chat, and TUI Gateway are reachable from both row-level buttons and menu actions.
- Verify status/error UX and edge-case rendering (no results, searching indicator, completion state).

## Implementation Tasks (phase hints)

- Phase 1: Validate query initiation, status updates, and result rendering in `HermesHistoryView.swift`.
- Phase 2: Validate dashboard request construction, token extraction/reuse, and search fallback logic in `HermesDashboardHistorySearch.swift`.
- Phase 3: Validate resume wiring and workspace readiness states through code review of `ContentView.swift` callbacks.
- Phase 4: Finalize requirement and implementation notes with clear completion evidence.

## Acceptance Conditions

- Search query flow is robust for user-empty, cancellation, and happy path cases.
- Search returns and displays counts/snippets in the expected sections.
- Resume options populate and route to all three destinations when available.
- No obvious crash risks from payload decoding or session-id fallback behavior.
- Implementation artifacts are complete and self-consistent.
