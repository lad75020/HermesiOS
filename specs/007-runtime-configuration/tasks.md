# Tasks: Agent Runtime Configuration

**Input**: Design documents from `/specs/007-runtime-configuration/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/runtime-configuration-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesiOS/HermesRuntimeComponents.swift, HermesiOS/HermesAgentConfigView.swift, HermesiOS/HermesMemoryPanel.swift, HermesiOS/HermesProvidersPanel.swift, HermesiOS/HermesModelsPanel.swift, HermesiOS/HermesProfilesPanel.swift, HermesiOS/HermesGatewayPanel.swift, HermesiOS/HermesToolsPanel.swift, HermesiOS/HermesMCPServersPanel.swift, HermesiOS/HermesSkillsPanel.swift, HermesiOS/HermesSchedulesPanel.swift, HermesiOS/HermesObservabilityPanel.swift, HermesiOS/HermesKnowledgeEraserPanel.swift, HermesHostCompanion/CompanionMemoryRegistry.swift, HermesHostCompanion/CompanionProviderRegistry.swift, HermesHostCompanion/CompanionModelRegistry.swift, HermesHostCompanion/CompanionProfileRegistry.swift, HermesHostCompanion/CompanionGatewayRegistry.swift, HermesHostCompanion/CompanionToolsetRegistry.swift, HermesHostCompanion/CompanionMCPRegistry.swift, HermesHostCompanion/CompanionScheduleRegistry.swift, HermesHostCompanion/CompanionTargetRegistry.swift, HermesHostCompanion/CompanionKnowledgeEraserRegistry.swift, HermesHostCompanion/CompanionFileDownloadRegistry.swift
- [x] T002 [P] Verify generated documentation artifacts exist in specs/007-runtime-configuration/spec.md, specs/007-runtime-configuration/plan.md, specs/007-runtime-configuration/research.md, specs/007-runtime-configuration/data-model.md, specs/007-runtime-configuration/contracts/runtime-configuration-contract.md, and specs/007-runtime-configuration/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesiOS/HermesRuntimeComponents.swift, HermesiOS/HermesAgentConfigView.swift, HermesiOS/HermesMemoryPanel.swift, HermesiOS/HermesProvidersPanel.swift, HermesiOS/HermesModelsPanel.swift, HermesiOS/HermesProfilesPanel.swift, HermesiOS/HermesGatewayPanel.swift, HermesiOS/HermesToolsPanel.swift, HermesiOS/HermesMCPServersPanel.swift, HermesiOS/HermesSkillsPanel.swift, HermesiOS/HermesSchedulesPanel.swift, HermesiOS/HermesObservabilityPanel.swift, HermesiOS/HermesKnowledgeEraserPanel.swift, HermesHostCompanion/CompanionMemoryRegistry.swift, HermesHostCompanion/CompanionProviderRegistry.swift, HermesHostCompanion/CompanionModelRegistry.swift, HermesHostCompanion/CompanionProfileRegistry.swift, HermesHostCompanion/CompanionGatewayRegistry.swift, HermesHostCompanion/CompanionToolsetRegistry.swift, HermesHostCompanion/CompanionMCPRegistry.swift, HermesHostCompanion/CompanionScheduleRegistry.swift, HermesHostCompanion/CompanionTargetRegistry.swift, HermesHostCompanion/CompanionKnowledgeEraserRegistry.swift, HermesHostCompanion/CompanionFileDownloadRegistry.swift against specs/007-runtime-configuration/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesiOS/HermesRuntimeComponents.swift, HermesiOS/HermesAgentConfigView.swift, HermesiOS/HermesMemoryPanel.swift, HermesiOS/HermesProvidersPanel.swift, HermesiOS/HermesModelsPanel.swift, HermesiOS/HermesProfilesPanel.swift, HermesiOS/HermesGatewayPanel.swift, HermesiOS/HermesToolsPanel.swift, HermesiOS/HermesMCPServersPanel.swift, HermesiOS/HermesSkillsPanel.swift, HermesiOS/HermesSchedulesPanel.swift, HermesiOS/HermesObservabilityPanel.swift, HermesiOS/HermesKnowledgeEraserPanel.swift, HermesHostCompanion/CompanionMemoryRegistry.swift, HermesHostCompanion/CompanionProviderRegistry.swift, HermesHostCompanion/CompanionModelRegistry.swift, HermesHostCompanion/CompanionProfileRegistry.swift, HermesHostCompanion/CompanionGatewayRegistry.swift, HermesHostCompanion/CompanionToolsetRegistry.swift, HermesHostCompanion/CompanionMCPRegistry.swift, HermesHostCompanion/CompanionScheduleRegistry.swift, HermesHostCompanion/CompanionTargetRegistry.swift, HermesHostCompanion/CompanionKnowledgeEraserRegistry.swift, HermesHostCompanion/CompanionFileDownloadRegistry.swift against specs/007-runtime-configuration/contracts/runtime-configuration-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix manage runtime panels behavior in HermesiOS/HermesRuntimeComponents.swift, HermesiOS/HermesAgentConfigView.swift, HermesiOS/HermesMemoryPanel.swift
- [x] T006 [US2] Verify or fix apply host-backed changes safely behavior in HermesiOS/HermesRuntimeComponents.swift, HermesiOS/HermesAgentConfigView.swift, HermesiOS/HermesMemoryPanel.swift
- [x] T007 [US3] Verify or fix understand operational state behavior in HermesiOS/HermesRuntimeComponents.swift, HermesiOS/HermesAgentConfigView.swift, HermesiOS/HermesMemoryPanel.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/007-runtime-configuration/spec.md, specs/007-runtime-configuration/plan.md, specs/007-runtime-configuration/research.md, specs/007-runtime-configuration/data-model.md, specs/007-runtime-configuration/contracts/runtime-configuration-contract.md, specs/007-runtime-configuration/quickstart.md, and specs/007-runtime-configuration/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after Agent Runtime Configuration documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for Agent Runtime Configuration"
Task: "Verify generated docs for Agent Runtime Configuration"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
