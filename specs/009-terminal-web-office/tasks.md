# Tasks: Terminal, Web, and Office Workspaces

**Input**: Design documents from `/specs/009-terminal-web-office/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/terminal-web-office-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesiOS/HermesTerminalView.swift, HermesiOS/HermesWebBrowserView.swift, HermesiOS/HermesOfficeView.swift
- [x] T002 [P] Verify generated documentation artifacts exist in specs/009-terminal-web-office/spec.md, specs/009-terminal-web-office/plan.md, specs/009-terminal-web-office/research.md, specs/009-terminal-web-office/data-model.md, specs/009-terminal-web-office/contracts/terminal-web-office-contract.md, and specs/009-terminal-web-office/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesiOS/HermesTerminalView.swift, HermesiOS/HermesWebBrowserView.swift, HermesiOS/HermesOfficeView.swift against specs/009-terminal-web-office/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesiOS/HermesTerminalView.swift, HermesiOS/HermesWebBrowserView.swift, HermesiOS/HermesOfficeView.swift against specs/009-terminal-web-office/contracts/terminal-web-office-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix open ssh terminal workspaces behavior in HermesiOS/HermesTerminalView.swift, HermesiOS/HermesWebBrowserView.swift, HermesiOS/HermesOfficeView.swift
- [x] T006 [US2] Verify or fix browse web workspaces behavior in HermesiOS/HermesTerminalView.swift, HermesiOS/HermesWebBrowserView.swift, HermesiOS/HermesOfficeView.swift
- [x] T007 [US3] Verify or fix use office and claw3d web surfaces behavior in HermesiOS/HermesTerminalView.swift, HermesiOS/HermesWebBrowserView.swift, HermesiOS/HermesOfficeView.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/009-terminal-web-office/spec.md, specs/009-terminal-web-office/plan.md, specs/009-terminal-web-office/research.md, specs/009-terminal-web-office/data-model.md, specs/009-terminal-web-office/contracts/terminal-web-office-contract.md, specs/009-terminal-web-office/quickstart.md, and specs/009-terminal-web-office/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after Terminal, Web, and Office Workspaces documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for Terminal, Web, and Office Workspaces"
Task: "Verify generated docs for Terminal, Web, and Office Workspaces"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
