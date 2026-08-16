# Tasks: Hermes API Client

- [x] T001 [US1] Verify Responses endpoint construction and URL normalization logic in `./HermesiOS/HermesResponsesAPI.swift`.
- [x] T002 [US2] Verify Chat Completions request construction and streaming/non-streaming parsing in `./HermesiOS/HermesChatCompletionsAPI.swift`.
- [x] T003 [US3] Verify authorization header normalization and bearer token behavior (`Authorization`, `X-Hermes-Profile`, profile persistence).
- [x] T004 [US4] Verify secure persistence behavior for API key (non-persisted plain token in settings blob, keychain-backed storage).
- [x] T005 [US1] [US2] Validate status, session continuity (`previousResponseID`, `latestResponseID`, chat session IDs), and error paths by codepath review.
- [x] T006 [US1] Add API client QA checklist for bearer auth, profile switching, streaming behavior, and malformed URL cases.
- [x] T007 Update `./.specify/specs/002-api-client/implementation-notes.md` with evidence and behavior confirmation.
