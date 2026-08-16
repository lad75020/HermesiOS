# Specification: History & Search

Feature ID: `history-search`

## Summary

The History & Search feature lets users query dashboard conversation history, review matching sessions, and resume any matching conversation in Ask Hermes, Chat with Hermes, or the TUI Gateway.

## User Stories

- As a user, I can search dashboard conversations by entering a query and quickly see matching sessions.
- As a user, I can narrow results by profile so I can focus on conversations from a specific context.
- As a user, I can resume a selected conversation in Ask Hermes, Chat with Hermes, or TUI Gateway.
- As a user, I can start, cancel, and retry searches without restarting the app.
- As a user, I can continue work immediately after resume, with obvious status and error messages when the dashboard is unavailable.

## Functional Requirements

- The app SHALL provide a dashboard search input in the History view and validate that a non-empty query is submitted.
- The app SHALL query the dashboard endpoint `api/sessions/search/conversations` with query, profile, limit, and role parameters.
- The app SHALL resolve the dashboard base URL from explicit settings and fallback to API host settings when needed.
- The app SHALL obtain and reuse dashboard session token(s) from the dashboard HTML to authorize search requests.
- The app SHALL handle token or permission failures by attempting recovery where feasible and surfacing clear errors when recovery fails.
- The app SHALL display search status, counts, and result sections so users know whether search is active, empty, failed, or successful.
- The app SHALL preserve and expose profile options, including default and named profiles, for query scoping.
- The app SHALL support canceling an in-progress search.
- The app SHALL allow resume actions from search results into:
  - Ask Hermes (Responses workspace)
  - Chat with Hermes (chat workspace)
  - TUI Gateway
- The app SHALL block or gate resume actions in TUI/Chat/Responses when their streaming state prevents interruption.
- The app SHALL display helpful snippets and message context so users can make confident resume choices.

## Success Criteria

- A valid query returns results and updates result counts and status messaging.
- Profile filtering changes which sessions are shown without requiring app restart.
- Resume to each destination is routed to the correct workspace and preloads context from selected conversation metadata.
- Search can be canceled and retried safely.
- No crashes occur when search endpoints return empty results, timeouts, malformed responses, or authorization failures.

## Files in Scope

- `HermesiOS/HermesHistoryView.swift`
- `HermesiOS/HermesDashboardHistorySearch.swift`

## Assumptions

- Dashboard base host and API host are configured from app settings.
- Dashboard exposes `/api/sessions/search/conversations` for FTS-style conversation search.
- Resume callbacks in `ContentView` and workspace stores already understand `HermesDashboardConversationResult`.

## Edge Cases

- Empty query should not trigger network calls and should prompt the user via status handling.
- Search cancellation while in flight should stop request work and clear transient busy UI state.
- Dashboard token may expire; fallback token refresh should run and retry query.
- Search result payloads may include mixed content types (string/object/array); decoding should remain robust.
- Resume session IDs may be missing in search metadata, requiring fallback IDs.
- Busy states in destination workspaces should disable risky resume actions.
- Profile dropdown values may include default and named profiles with case/casing differences.
