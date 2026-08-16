# Implementation Notes

## Feature Scope

Feature directory: `.specify/specs/004-history-search`

Branch: `feature/time-machine-history-search`

Status: Verified through artifact-led inspection for this Time Machine pass.

## Current Behavior Evidence

- `HermesHistoryView` owns the search input/toolbar, profile dropdown, cancel control, status line, and results rendering for dashboard search.
- `HermesDashboardHistorySearchSession` builds query requests against `api/sessions/search/conversations`, enriches request headers with dashboard session token, and updates UI state for searching, success, and failures.
- Session token retrieval and retry logic is present (`dashboardSessionToken` + refresh-on-401 pattern) and token cache is tracked per dashboard base URL.
- Search results are normalized and filtered by selected profile; destination resume callbacks are forwarded to:
  - Ask Hermes
  - Chat with Hermes
  - TUI Gateway
- Resume destination controls include busy-state gating based on streaming/in-flight states.

## Clarification/Plan/Task Status

- Specify: completed
- Clarify: completed
- Plan: completed
- Tasks: completed

## Note

No source code changes were required in this cycle; behavior appears complete through current implementation and queue handoff context.
