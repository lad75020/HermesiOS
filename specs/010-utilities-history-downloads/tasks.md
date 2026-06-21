# Tasks: Utilities, History, and Downloads

**Input**: Design documents from `/specs/010-utilities-history-downloads/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/utilities-history-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesiOS/HermesUtilitiesView.swift, HermesiOS/Item.swift
- [x] T002 [P] Verify generated documentation artifacts exist in specs/010-utilities-history-downloads/spec.md, specs/010-utilities-history-downloads/plan.md, specs/010-utilities-history-downloads/research.md, specs/010-utilities-history-downloads/data-model.md, specs/010-utilities-history-downloads/contracts/utilities-history-contract.md, and specs/010-utilities-history-downloads/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesiOS/HermesUtilitiesView.swift, HermesiOS/Item.swift against specs/010-utilities-history-downloads/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesiOS/HermesUtilitiesView.swift, HermesiOS/Item.swift against specs/010-utilities-history-downloads/contracts/utilities-history-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix review local prompt and response history behavior in HermesiOS/HermesUtilitiesView.swift, HermesiOS/Item.swift
- [x] T006 [US2] Verify or fix use protected utility storage behavior in HermesiOS/HermesUtilitiesView.swift, HermesiOS/Item.swift
- [x] T007 [US3] Verify or fix download host files deliberately behavior in HermesiOS/HermesUtilitiesView.swift, HermesiOS/Item.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/010-utilities-history-downloads/spec.md, specs/010-utilities-history-downloads/plan.md, specs/010-utilities-history-downloads/research.md, specs/010-utilities-history-downloads/data-model.md, specs/010-utilities-history-downloads/contracts/utilities-history-contract.md, specs/010-utilities-history-downloads/quickstart.md, and specs/010-utilities-history-downloads/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after Utilities, History, and Downloads documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for Utilities, History, and Downloads"
Task: "Verify generated docs for Utilities, History, and Downloads"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
