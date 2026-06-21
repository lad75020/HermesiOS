# Tasks: Dashboard History Search

**Input**: Design documents from `/specs/006-dashboard-history/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/dashboard-history-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesiOS/HermesDashboardHistorySearch.swift, HermesiOS/HermesHistoryView.swift
- [x] T002 [P] Verify generated documentation artifacts exist in specs/006-dashboard-history/spec.md, specs/006-dashboard-history/plan.md, specs/006-dashboard-history/research.md, specs/006-dashboard-history/data-model.md, specs/006-dashboard-history/contracts/dashboard-history-contract.md, and specs/006-dashboard-history/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesiOS/HermesDashboardHistorySearch.swift, HermesiOS/HermesHistoryView.swift against specs/006-dashboard-history/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesiOS/HermesDashboardHistorySearch.swift, HermesiOS/HermesHistoryView.swift against specs/006-dashboard-history/contracts/dashboard-history-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix search previous conversations behavior in HermesiOS/HermesDashboardHistorySearch.swift, HermesiOS/HermesHistoryView.swift
- [x] T006 [US2] Verify or fix inspect matched context behavior in HermesiOS/HermesDashboardHistorySearch.swift, HermesiOS/HermesHistoryView.swift
- [x] T007 [US3] Verify or fix resume useful sessions behavior in HermesiOS/HermesDashboardHistorySearch.swift, HermesiOS/HermesHistoryView.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/006-dashboard-history/spec.md, specs/006-dashboard-history/plan.md, specs/006-dashboard-history/research.md, specs/006-dashboard-history/data-model.md, specs/006-dashboard-history/contracts/dashboard-history-contract.md, specs/006-dashboard-history/quickstart.md, and specs/006-dashboard-history/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after Dashboard History Search documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for Dashboard History Search"
Task: "Verify generated docs for Dashboard History Search"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
