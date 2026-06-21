# Tasks: App Shell and Design System

**Input**: Design documents from `/specs/001-app-shell-design/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/shell-ui-contract.md, quickstart.md

**Tests**: This retrospective feature uses build and focused runtime/readiness validation tasks instead of new test files unless a mismatch is discovered.

**Organization**: Tasks are grouped by user story to enable independent validation and targeted remediation.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the source/resource baseline for shell validation.

- [x] T001 Verify HermesiOS target build settings and resource membership baseline in HermesiOS.xcodeproj/project.pbxproj
- [x] T002 Verify app metadata, entitlements, and localization resource paths exist in HermesiOS/Info.plist, HermesiOS/HermesiOS.entitlements, HermesiOS/HermesiOSRelease.entitlements, HermesiOS/Localizable.xcstrings, and HermesiOS/en.lproj/InfoPlist.strings
- [x] T003 [P] Verify app icon, accent color, logo, splash media, and font resources exist in HermesiOS/Assets.xcassets/Contents.json, HermesiOS/Resources/HermesLogoDark.png, HermesiOS/Resources/HermesLogoLight.png, HermesiOS/Resources/HermesSplash.mp4, and HermesiOS/Fonts/JetBrainsMono-Regular.woff2
- [x] T004 [P] Verify the feature documentation artifact set exists in specs/001-app-shell-design/spec.md, specs/001-app-shell-design/plan.md, specs/001-app-shell-design/research.md, specs/001-app-shell-design/data-model.md, specs/001-app-shell-design/contracts/shell-ui-contract.md, and specs/001-app-shell-design/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Confirm shell-owned files are mapped to the correct feature scope before story validation.

**⚠️ CRITICAL**: No user story validation can be marked complete until this phase is complete.

- [x] T005 Cross-check shell entry and root composition responsibilities in HermesiOS/HermesiOSApp.swift and HermesiOS/ContentView.swift against specs/001-app-shell-design/spec.md
- [x] T006 Cross-check workspace navigation and shell attention responsibilities in HermesiOS/HermesWorkspaceNavigation.swift and HermesiOS/HermesStatusBand.swift against specs/001-app-shell-design/contracts/shell-ui-contract.md
- [x] T007 Cross-check shared visual component and theme responsibilities in HermesiOS/HermesSharedViews.swift, HermesiOS/HermesDesignSystem.swift, HermesiOS/HermesAppTheme.swift, and HermesiOS/HermesWebsiteTypography.swift against specs/001-app-shell-design/data-model.md
- [x] T008 Cross-check launch, background activity, and resource fallback responsibilities in HermesiOS/HermesSplashView.swift, HermesiOS/HermesBackgroundActivity.swift, and HermesiOS/Resources/HermesSplash.mp4 against specs/001-app-shell-design/quickstart.md

**Checkpoint**: Shell baseline ready - user story validation can now proceed.

---

## Phase 3: User Story 1 - Open a Coherent Companion Workspace (Priority: P1) 🎯 MVP

**Goal**: The app launches into a stable shell with usable navigation even before host services are available.

**Independent Test**: Build and inspect entry/root/navigation code paths, then run or document the quickstart shell smoke path.

### Implementation for User Story 1

- [x] T009 [US1] Verify or fix app entry initialization and root shell presentation in HermesiOS/HermesiOSApp.swift and HermesiOS/ContentView.swift
- [x] T010 [US1] Verify or fix workspace section selection and visible content switching in HermesiOS/HermesWorkspaceNavigation.swift and HermesiOS/ContentView.swift
- [x] T011 [US1] Verify or fix splash transition fallback so launch media cannot indefinitely block the shell in HermesiOS/HermesSplashView.swift and HermesiOS/Resources/HermesSplash.mp4
- [x] T012 [US1] Verify or fix offline-host shell usability boundaries in HermesiOS/ContentView.swift, HermesiOS/HermesStatusBand.swift, and HermesiOS/HermesHostEndpoints.swift

**Checkpoint**: User Story 1 is functional and independently testable.

---

## Phase 4: User Story 2 - Navigate with Consistent Visual Hierarchy (Priority: P2)

**Goal**: Navigation, shared cards, headers, status rows, status pills, and message surfaces use a consistent hierarchy.

**Independent Test**: Inspect representative shared components and verify consistent state, spacing, typography, and long-text behavior.

### Implementation for User Story 2

- [x] T013 [P] [US2] Verify or fix shared header, card, status row, status pill, and message surface consistency in HermesiOS/HermesSharedViews.swift
- [x] T014 [P] [US2] Verify or fix color, gradient, glass surface, and typography consistency in HermesiOS/HermesDesignSystem.swift and HermesiOS/HermesWebsiteTypography.swift
- [x] T015 [US2] Verify or fix workspace icon, selected state, and attention state precedence in HermesiOS/HermesWorkspaceNavigation.swift and HermesiOS/HermesResponsesWorkspace.swift
- [x] T016 [US2] Verify or fix long-text handling for navigation/status/shared shell surfaces in HermesiOS/HermesSharedViews.swift and HermesiOS/HermesWorkspaceNavigation.swift

**Checkpoint**: User Stories 1 and 2 both work independently.

---

## Phase 5: User Story 3 - Personalize and Localize the Shell (Priority: P3)

**Goal**: Supported localization, theme, branding, fonts, metadata, and entitlements preserve a native-feeling shell.

**Independent Test**: Inspect localization/resource coverage and verify appearance-related shell paths.

### Implementation for User Story 3

- [x] T017 [P] [US3] Verify or fix supported localization coverage in HermesiOS/Localizable.xcstrings, HermesiOS/en.lproj/InfoPlist.strings, HermesiOS/fr.lproj/InfoPlist.strings, HermesiOS/de.lproj/InfoPlist.strings, HermesiOS/es.lproj/InfoPlist.strings, and HermesiOS/zh-Hans.lproj/InfoPlist.strings
- [x] T018 [P] [US3] Verify or fix theme selection and appearance behavior in HermesiOS/HermesAppTheme.swift and HermesiOS/HermesDesignSystem.swift
- [x] T019 [US3] Verify or fix brand asset, font, launch resource, metadata, and entitlement integration in HermesiOS/Assets.xcassets/Contents.json, HermesiOS/Resources/HermesLogoDark.png, HermesiOS/Fonts/RulesExpanded-Regular.woff2, HermesiOS/Info.plist, and HermesiOS/HermesiOS.entitlements

**Checkpoint**: All user stories are independently validated.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation consistency.

- [x] T020 Run Xcode build validation for the HermesiOS scheme using HermesiOS.xcodeproj/project.pbxproj and record the result in specs/001-app-shell-design/quickstart.md if a blocker appears
- [x] T021 Validate generated Spec Kit artifacts for unresolved placeholders in specs/001-app-shell-design/spec.md, specs/001-app-shell-design/plan.md, specs/001-app-shell-design/research.md, specs/001-app-shell-design/data-model.md, specs/001-app-shell-design/contracts/shell-ui-contract.md, specs/001-app-shell-design/quickstart.md, and specs/001-app-shell-design/tasks.md
- [x] T022 Confirm Time Machine implementation-phase tracking for app-shell-design in .specify/extensions/time-machine/features-queue.yml after successful validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion - blocks all user story validation.
- **User Stories (Phase 3+)**: Depend on Foundational completion; validate in priority order for single-agent execution.
- **Polish (Phase 6)**: Depends on all selected user stories being validated.

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational phase; no dependency on other stories.
- **User Story 2 (P2)**: Can start after Foundational phase; benefits from US1 shell context but is independently inspectable.
- **User Story 3 (P3)**: Can start after Foundational phase; depends on shared shell/theme context but is independently inspectable.

### Parallel Opportunities

- T003 and T004 can run in parallel after T001-T002 start.
- T013 and T014 can run in parallel because they inspect different shared visual files.
- T017 and T018 can run in parallel because localization resources and theme files are independent.

---

## Parallel Example: User Story 2

```bash
Task: "Verify shared surface consistency in HermesiOS/HermesSharedViews.swift"
Task: "Verify design token and typography consistency in HermesiOS/HermesDesignSystem.swift and HermesiOS/HermesWebsiteTypography.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 setup checks.
2. Complete Phase 2 foundational scope checks.
3. Complete Phase 3 launch/navigation/offline shell validation.
4. Stop and validate that the shell opens and remains navigable without host services.

### Incremental Delivery

1. Validate shell baseline and source/resource coverage.
2. Validate US1 launch and navigation.
3. Validate US2 shared visual hierarchy.
4. Validate US3 localization, theme, branding, and resources.
5. Finish with build validation and artifact placeholder checks.

### Single-Agent Strategy

Because this is a retrospective single-repository feature, execute tasks sequentially except for explicitly independent inspections marked `[P]`. Mark tasks complete only after verification or a concrete fix has been applied and checked.
