# Tasks: TUI Gateway and Command Center

**Input**: Design documents from `/specs/005-tui-gateway-command-center/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/tui-command-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesiOS/HermesTUIGatewayView.swift, HermesiOS/HermesCommandCenterView.swift, HermesiOS/HermesDashboardGatewayRestart.swift
- [x] T002 [P] Verify generated documentation artifacts exist in specs/005-tui-gateway-command-center/spec.md, specs/005-tui-gateway-command-center/plan.md, specs/005-tui-gateway-command-center/research.md, specs/005-tui-gateway-command-center/data-model.md, specs/005-tui-gateway-command-center/contracts/tui-command-contract.md, and specs/005-tui-gateway-command-center/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesiOS/HermesTUIGatewayView.swift, HermesiOS/HermesCommandCenterView.swift, HermesiOS/HermesDashboardGatewayRestart.swift against specs/005-tui-gateway-command-center/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesiOS/HermesTUIGatewayView.swift, HermesiOS/HermesCommandCenterView.swift, HermesiOS/HermesDashboardGatewayRestart.swift against specs/005-tui-gateway-command-center/contracts/tui-command-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix open dashboard-backed tui sessions behavior in HermesiOS/HermesTUIGatewayView.swift, HermesiOS/HermesCommandCenterView.swift, HermesiOS/HermesDashboardGatewayRestart.swift
- [x] T006 [US2] Verify or fix handle interactive stream events behavior in HermesiOS/HermesTUIGatewayView.swift, HermesiOS/HermesCommandCenterView.swift, HermesiOS/HermesDashboardGatewayRestart.swift
- [x] T007 [US3] Verify or fix run command center actions behavior in HermesiOS/HermesTUIGatewayView.swift, HermesiOS/HermesCommandCenterView.swift, HermesiOS/HermesDashboardGatewayRestart.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/005-tui-gateway-command-center/spec.md, specs/005-tui-gateway-command-center/plan.md, specs/005-tui-gateway-command-center/research.md, specs/005-tui-gateway-command-center/data-model.md, specs/005-tui-gateway-command-center/contracts/tui-command-contract.md, specs/005-tui-gateway-command-center/quickstart.md, and specs/005-tui-gateway-command-center/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after TUI Gateway and Command Center documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for TUI Gateway and Command Center"
Task: "Verify generated docs for TUI Gateway and Command Center"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
