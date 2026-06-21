# Tasks: Developer Debug Bridge

**Input**: Design documents from `/specs/011-developer-debug-bridge/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/developer-debug-bridge-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesiOS/GstackDebugBridges.swift, HermesiOS/GstackDebugStateServer.swift
- [x] T002 [P] Verify generated documentation artifacts exist in specs/011-developer-debug-bridge/spec.md, specs/011-developer-debug-bridge/plan.md, specs/011-developer-debug-bridge/research.md, specs/011-developer-debug-bridge/data-model.md, specs/011-developer-debug-bridge/contracts/developer-debug-bridge-contract.md, and specs/011-developer-debug-bridge/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesiOS/GstackDebugBridges.swift, HermesiOS/GstackDebugStateServer.swift against specs/011-developer-debug-bridge/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesiOS/GstackDebugBridges.swift, HermesiOS/GstackDebugStateServer.swift against specs/011-developer-debug-bridge/contracts/developer-debug-bridge-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix expose debug state for qa behavior in HermesiOS/GstackDebugBridges.swift, HermesiOS/GstackDebugStateServer.swift
- [x] T006 [US2] Verify or fix capture screenshots and elements behavior in HermesiOS/GstackDebugBridges.swift, HermesiOS/GstackDebugStateServer.swift
- [x] T007 [US3] Verify or fix apply controlled ui mutations behavior in HermesiOS/GstackDebugBridges.swift, HermesiOS/GstackDebugStateServer.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/011-developer-debug-bridge/spec.md, specs/011-developer-debug-bridge/plan.md, specs/011-developer-debug-bridge/research.md, specs/011-developer-debug-bridge/data-model.md, specs/011-developer-debug-bridge/contracts/developer-debug-bridge-contract.md, specs/011-developer-debug-bridge/quickstart.md, and specs/011-developer-debug-bridge/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after Developer Debug Bridge documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for Developer Debug Bridge"
Task: "Verify generated docs for Developer Debug Bridge"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
