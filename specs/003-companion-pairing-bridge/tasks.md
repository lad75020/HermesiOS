# Tasks: Host Companion Pairing Bridge

**Input**: Design documents from `/specs/003-companion-pairing-bridge/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/companion-pairing-contract.md, quickstart.md

**Tests**: This retrospective feature uses static validation plus the previously successful Xcode build baseline unless source changes are introduced.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source/resource paths exist in HermesiOS/HermesCompanionClient.swift, HermesiOS/HermesCompanionPanel.swift, HermesHostCompanion/HermesHostCompanionApp.swift, HermesHostCompanion/CompanionServer.swift, HermesHostCompanion/CompanionProtocol.swift, HermesHostCompanion/Assets.xcassets/, HermesHostCompanion/AppIcon.icns, HermesHostCompanion/Info.plist, HermesHostCompanion/Localizable.xcstrings, HermesHostCompanion/*/InfoPlist.strings
- [x] T002 [P] Verify generated documentation artifacts exist in specs/003-companion-pairing-bridge/spec.md, specs/003-companion-pairing-bridge/plan.md, specs/003-companion-pairing-bridge/research.md, specs/003-companion-pairing-bridge/data-model.md, specs/003-companion-pairing-bridge/contracts/companion-pairing-contract.md, and specs/003-companion-pairing-bridge/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check scoped feature responsibilities in HermesiOS/HermesCompanionClient.swift, HermesiOS/HermesCompanionPanel.swift, HermesHostCompanion/HermesHostCompanionApp.swift, HermesHostCompanion/CompanionServer.swift, HermesHostCompanion/CompanionProtocol.swift, HermesHostCompanion/Assets.xcassets/, HermesHostCompanion/AppIcon.icns, HermesHostCompanion/Info.plist, HermesHostCompanion/Localizable.xcstrings, HermesHostCompanion/*/InfoPlist.strings against specs/003-companion-pairing-bridge/spec.md
- [x] T004 Cross-check user-facing contract behavior in HermesiOS/HermesCompanionClient.swift, HermesiOS/HermesCompanionPanel.swift, HermesHostCompanion/HermesHostCompanionApp.swift, HermesHostCompanion/CompanionServer.swift, HermesHostCompanion/CompanionProtocol.swift, HermesHostCompanion/Assets.xcassets/, HermesHostCompanion/AppIcon.icns, HermesHostCompanion/Info.plist, HermesHostCompanion/Localizable.xcstrings, HermesHostCompanion/*/InfoPlist.strings against specs/003-companion-pairing-bridge/contracts/companion-pairing-contract.md

---

## Phase 3: User Stories (Priority Order)

- [x] T005 [US1] Verify or fix pair a trusted device behavior in HermesiOS/HermesCompanionClient.swift, HermesiOS/HermesCompanionPanel.swift, HermesHostCompanion/HermesHostCompanionApp.swift
- [x] T006 [US2] Verify or fix maintain an authenticated bridge behavior in HermesiOS/HermesCompanionClient.swift, HermesiOS/HermesCompanionPanel.swift, HermesHostCompanion/HermesHostCompanionApp.swift
- [x] T007 [US3] Verify or fix protect privileged host actions behavior in HermesiOS/HermesCompanionClient.swift, HermesiOS/HermesCompanionPanel.swift, HermesHostCompanion/HermesHostCompanionApp.swift

---

## Phase 4: Polish & Cross-Cutting Concerns

- [x] T008 Validate generated Spec Kit artifacts for unresolved placeholders in specs/003-companion-pairing-bridge/spec.md, specs/003-companion-pairing-bridge/plan.md, specs/003-companion-pairing-bridge/research.md, specs/003-companion-pairing-bridge/data-model.md, specs/003-companion-pairing-bridge/contracts/companion-pairing-contract.md, specs/003-companion-pairing-bridge/quickstart.md, and specs/003-companion-pairing-bridge/tasks.md
- [x] T009 Confirm Xcode build baseline remains valid for HermesiOS.xcodeproj/project.pbxproj after Host Companion Pairing Bridge documentation artifacts

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede user-story validation.
- User stories can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example

```bash
Task: "Verify scoped paths for Host Companion Pairing Bridge"
Task: "Verify generated docs for Host Companion Pairing Bridge"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then rely on the successful Xcode build baseline because this pass changes documentation only.
