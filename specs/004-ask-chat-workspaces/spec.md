# Feature Specification: Ask and Chat Workspaces

**Feature Branch**: `feature/time-machine-ask-chat-workspaces`

**Created**: 2026-06-21

**Status**: Draft

**Input**: User description: "Feature: Ask and Chat Workspaces. Description: Enables Ask Hermes responses, chat completions, streaming console UI, attachments, speech input, prompt history, workspace attention, and approvals.. Relevant files: HermesiOS/HermesResponsesAPI.swift, HermesiOS/HermesChatCompletionsAPI.swift, HermesiOS/HermesConsoleViews.swift, HermesiOS/HermesResponsesWorkspace.swift, HermesiOS/HermesPromptHistoryStore.swift, HermesiOS/HermesApprovalsInboxView.swift. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ask Hermes in parallel workspaces (Priority: P1)

As a HermesiOS user, I want users can send independent Ask Hermes prompts and track each workspace response. so that this part of the companion app is understandable, reliable, and safe.

**Why this priority**: This journey is required to deliver the user value described by Ask and Chat Workspaces while keeping the feature bounded to its source files.

**Independent Test**: Use the source files and quickstart for this feature to verify the journey independently from unrelated Time Machine features.

**Acceptance Scenarios**:

1. **Given** the relevant app state is available, **When** the user opens this feature area, **Then** the feature presents a clear state and primary action path.
2. **Given** required host or local inputs are missing or invalid, **When** the feature renders, **Then** it presents an actionable non-secret status or recovery path.
3. **Given** the user leaves and returns to this feature area, **When** state is restored, **Then** the feature preserves expected local context without exposing sensitive implementation details.

---
### User Story 2 - Chat with streamed context (Priority: P2)

As a HermesiOS user, I want users can hold chat conversations with attachments, speech input, streaming output, and clean assistant bubbles. so that this part of the companion app is understandable, reliable, and safe.

**Why this priority**: This journey is required to deliver the user value described by Ask and Chat Workspaces while keeping the feature bounded to its source files.

**Independent Test**: Use the source files and quickstart for this feature to verify the journey independently from unrelated Time Machine features.

**Acceptance Scenarios**:

1. **Given** the relevant app state is available, **When** the user opens this feature area, **Then** the feature presents a clear state and primary action path.
2. **Given** required host or local inputs are missing or invalid, **When** the feature renders, **Then** it presents an actionable non-secret status or recovery path.
3. **Given** the user leaves and returns to this feature area, **When** state is restored, **Then** the feature preserves expected local context without exposing sensitive implementation details.

---
### User Story 3 - Resolve approvals safely (Priority: P3)

As a HermesiOS user, I want users can see and resolve pending approvals without losing chat context. so that this part of the companion app is understandable, reliable, and safe.

**Why this priority**: This journey is required to deliver the user value described by Ask and Chat Workspaces while keeping the feature bounded to its source files.

**Independent Test**: Use the source files and quickstart for this feature to verify the journey independently from unrelated Time Machine features.

**Acceptance Scenarios**:

1. **Given** the relevant app state is available, **When** the user opens this feature area, **Then** the feature presents a clear state and primary action path.
2. **Given** required host or local inputs are missing or invalid, **When** the feature renders, **Then** it presents an actionable non-secret status or recovery path.
3. **Given** the user leaves and returns to this feature area, **When** state is restored, **Then** the feature preserves expected local context without exposing sensitive implementation details.

---

### Edge Cases

- Required host services may be unavailable, slow, or return malformed data.
- User-facing state may be empty, loading, stale, failed, or partially complete.
- Sensitive values, prompts, files, and debug data must not be exposed in normal labels or summaries.
- Long localized labels, filenames, paths, or status messages must not break the app layout.
- The feature must remain scoped to its listed source files and not change unrelated Time Machine features.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide the user-facing capability described by Ask and Chat Workspaces using the scoped source files for this feature.
- **FR-002**: The system MUST present clear user-visible states for loading, success, empty, failure, and unavailable conditions where applicable.
- **FR-003**: The system MUST keep sensitive tokens, prompts, file paths, debug data, and host-control details out of normal user-facing summaries unless explicitly requested by the user.
- **FR-004**: The system MUST preserve expected local state across normal navigation away from and back to the feature area.
- **FR-005**: The system MUST provide actionable recovery guidance when required inputs, services, or permissions are missing.
- **FR-006**: The system MUST remain consistent with the shared HermesiOS app shell, navigation, accessibility, localization, and theme behavior.
- **FR-007**: The system MUST avoid modifying unrelated feature areas outside the listed source files.

### Key Entities *(include if feature involves data)*

- **Responses Workspace**: Product-level concept used by Ask and Chat Workspaces with stable identity, user-visible state, and validation rules.
- **Chat Session**: Product-level concept used by Ask and Chat Workspaces with stable identity, user-visible state, and validation rules.
- **Prompt Attachment**: Product-level concept used by Ask and Chat Workspaces with stable identity, user-visible state, and validation rules.
- **Approval Item**: Product-level concept used by Ask and Chat Workspaces with stable identity, user-visible state, and validation rules.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can reach the primary Ask and Chat Workspaces surface from the app shell in under 2 seconds after the app is responsive.
- **SC-002**: 100% of tested missing-service or invalid-input cases produce a user-visible recovery state instead of an app crash.
- **SC-003**: Sensitive values are absent from normal labels, status summaries, and generated documentation for this feature.
- **SC-004**: The feature's scoped source files and generated artifacts validate with no unresolved placeholders.
- **SC-005**: The HermesiOS project continues to build successfully after the feature artifacts are added.

## Assumptions

- This is a retrospective Time Machine feature for an existing codebase, so implementation primarily validates current behavior and applies targeted fixes only if mismatches are found.
- The existing app shell and shared design system remain the navigation and presentation baseline.
- Detailed behavior outside the listed files is owned by another Time Machine feature.
