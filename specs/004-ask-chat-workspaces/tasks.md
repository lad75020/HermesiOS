# Tasks: Ask and Chat Workspaces

**Input**: Design documents from `/specs/004-ask-chat-workspaces/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ask-chat-workspace-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesiOS/HermesResponsesAPI.swift, HermesiOS/HermesChatCompletionsAPI.swift, HermesiOS/HermesConsoleViews.swift, HermesiOS/HermesResponsesWorkspace.swift, HermesiOS/HermesPromptHistoryStore.swift, HermesiOS/HermesApprovalsInboxView.swift
- [x] T002 [P] Verify generated documentation artifacts exist in specs/004-ask-chat-workspaces/spec.md, specs/004-ask-chat-workspaces/plan.md, specs/004-ask-chat-workspaces/research.md, specs/004-ask-chat-workspaces/data-model.md, specs/004-ask-chat-workspaces/contracts/ask-chat-workspace-contract.md, and specs/004-ask-chat-workspaces/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesiOS/HermesResponsesAPI.swift, HermesiOS/HermesChatCompletionsAPI.swift, HermesiOS/HermesConsoleViews.swift, HermesiOS/HermesResponsesWorkspace.swift, HermesiOS/HermesPromptHistoryStore.swift, HermesiOS/HermesApprovalsInboxView.swift against specs/004-ask-chat-workspaces/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesiOS/HermesResponsesAPI.swift, HermesiOS/HermesChatCompletionsAPI.swift, HermesiOS/HermesConsoleViews.swift, HermesiOS/HermesResponsesWorkspace.swift, HermesiOS/HermesPromptHistoryStore.swift, HermesiOS/HermesApprovalsInboxView.swift against specs/004-ask-chat-workspaces/contracts/ask-chat-workspace-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix ask hermes in parallel workspaces behavior in HermesiOS/HermesResponsesAPI.swift, HermesiOS/HermesChatCompletionsAPI.swift, HermesiOS/HermesConsoleViews.swift
- [x] T006 [US2] Verify or fix chat with streamed context behavior in HermesiOS/HermesResponsesAPI.swift, HermesiOS/HermesChatCompletionsAPI.swift, HermesiOS/HermesConsoleViews.swift
- [x] T007 [US3] Verify or fix resolve approvals safely behavior in HermesiOS/HermesResponsesAPI.swift, HermesiOS/HermesChatCompletionsAPI.swift, HermesiOS/HermesConsoleViews.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/004-ask-chat-workspaces/spec.md, specs/004-ask-chat-workspaces/plan.md, specs/004-ask-chat-workspaces/research.md, specs/004-ask-chat-workspaces/data-model.md, specs/004-ask-chat-workspaces/contracts/ask-chat-workspace-contract.md, specs/004-ask-chat-workspaces/quickstart.md, and specs/004-ask-chat-workspaces/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after Ask and Chat Workspaces documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for Ask and Chat Workspaces"
Task: "Verify generated docs for Ask and Chat Workspaces"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
