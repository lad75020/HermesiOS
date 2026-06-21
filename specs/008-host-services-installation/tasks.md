# Tasks: Host Services and Installation

**Input**: Design documents from `/specs/008-host-services-installation/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/host-services-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesHostCompanion/CompanionServiceRegistry.swift, HermesHostCompanion/CompanionLogRegistry.swift, HermesHostCompanion/CompanionTailscaleServeRegistry.swift, HermesHostCompanion/CompanionGitRegistry.swift, scripts/deploy-hermesios.mjs, scripts/deploy_hermesios_stack.py
- [x] T002 [P] Verify generated documentation artifacts exist in specs/008-host-services-installation/spec.md, specs/008-host-services-installation/plan.md, specs/008-host-services-installation/research.md, specs/008-host-services-installation/data-model.md, specs/008-host-services-installation/contracts/host-services-contract.md, and specs/008-host-services-installation/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesHostCompanion/CompanionServiceRegistry.swift, HermesHostCompanion/CompanionLogRegistry.swift, HermesHostCompanion/CompanionTailscaleServeRegistry.swift, HermesHostCompanion/CompanionGitRegistry.swift, scripts/deploy-hermesios.mjs, scripts/deploy_hermesios_stack.py against specs/008-host-services-installation/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesHostCompanion/CompanionServiceRegistry.swift, HermesHostCompanion/CompanionLogRegistry.swift, HermesHostCompanion/CompanionTailscaleServeRegistry.swift, HermesHostCompanion/CompanionGitRegistry.swift, scripts/deploy-hermesios.mjs, scripts/deploy_hermesios_stack.py against specs/008-host-services-installation/contracts/host-services-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix inspect host service state behavior in HermesHostCompanion/CompanionServiceRegistry.swift, HermesHostCompanion/CompanionLogRegistry.swift, HermesHostCompanion/CompanionTailscaleServeRegistry.swift
- [x] T006 [US2] Verify or fix control deployment exposure behavior in HermesHostCompanion/CompanionServiceRegistry.swift, HermesHostCompanion/CompanionLogRegistry.swift, HermesHostCompanion/CompanionTailscaleServeRegistry.swift
- [x] T007 [US3] Verify or fix update hermes safely behavior in HermesHostCompanion/CompanionServiceRegistry.swift, HermesHostCompanion/CompanionLogRegistry.swift, HermesHostCompanion/CompanionTailscaleServeRegistry.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/008-host-services-installation/spec.md, specs/008-host-services-installation/plan.md, specs/008-host-services-installation/research.md, specs/008-host-services-installation/data-model.md, specs/008-host-services-installation/contracts/host-services-contract.md, specs/008-host-services-installation/quickstart.md, and specs/008-host-services-installation/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after Host Services and Installation documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for Host Services and Installation"
Task: "Verify generated docs for Host Services and Installation"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
