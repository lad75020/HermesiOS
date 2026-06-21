# Tasks: Secure Settings and Reachability

**Input**: Design documents from `/specs/002-secure-settings-reachability/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/settings-reachability-contract.md, quickstart.md

**Tests**: This retrospective feature uses static security checks plus build validation unless a mismatch requires code changes.

**Organization**: Tasks are grouped by user story to enable independent validation and remediation.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Verify scoped source files exist in HermesiOS/HermesSettingsView.swift, HermesiOS/HermesSettingsPersistence.swift, HermesiOS/HermesHostEndpoints.swift, and HermesiOS/HermesStatusBand.swift
- [x] T002 [P] Verify feature documentation artifacts exist in specs/002-secure-settings-reachability/spec.md, specs/002-secure-settings-reachability/plan.md, specs/002-secure-settings-reachability/research.md, specs/002-secure-settings-reachability/data-model.md, specs/002-secure-settings-reachability/contracts/settings-reachability-contract.md, and specs/002-secure-settings-reachability/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Cross-check sensitive settings persistence responsibilities in HermesiOS/HermesSettingsPersistence.swift against specs/002-secure-settings-reachability/spec.md
- [x] T004 Cross-check endpoint security and host construction responsibilities in HermesiOS/HermesHostEndpoints.swift against specs/002-secure-settings-reachability/contracts/settings-reachability-contract.md
- [x] T005 Cross-check reachability state responsibilities in HermesiOS/HermesStatusBand.swift against specs/002-secure-settings-reachability/data-model.md

---

## Phase 3: User Story 1 - Configure Trusted Hermes Access (Priority: P1) 🎯 MVP

**Goal**: Users can configure trusted host and credential settings without exposing secrets.

**Independent Test**: Inspect persistence and settings UI code for secure credential and QR onboarding paths.

- [x] T006 [US1] Verify or fix Keychain/security-backed credential storage in HermesiOS/HermesSettingsPersistence.swift
- [x] T007 [US1] Verify or fix QR onboarding and host field population in HermesiOS/HermesSettingsView.swift
- [x] T008 [US1] Verify or fix credential clearing/replacement paths in HermesiOS/HermesSettingsView.swift and HermesiOS/HermesSettingsPersistence.swift

---

## Phase 4: User Story 2 - See Reachability at a Glance (Priority: P2)

**Goal**: Users can distinguish service reachability states quickly.

**Independent Test**: Inspect status monitor/state code and confirm no secret-bearing labels are presented.

- [x] T009 [US2] Verify or fix service reachability state modeling in HermesiOS/HermesStatusBand.swift
- [x] T010 [US2] Verify or fix user-facing status labels and non-blocking unavailable states in HermesiOS/HermesStatusBand.swift and HermesiOS/HermesSettingsView.swift

---

## Phase 5: User Story 3 - Enforce Safe Endpoint Boundaries (Priority: P3)

**Goal**: Unsafe remote plaintext endpoints carrying sensitive traffic are rejected while loopback development remains usable.

**Independent Test**: Inspect endpoint validation logic and security decision messages.

- [x] T011 [US3] Verify or fix loopback versus remote plaintext endpoint decisions in HermesiOS/HermesHostEndpoints.swift
- [x] T012 [US3] Verify or fix malformed endpoint error messaging in HermesiOS/HermesHostEndpoints.swift and HermesiOS/HermesSettingsView.swift

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T013 Run Xcode build validation for the HermesiOS scheme using HermesiOS.xcodeproj/project.pbxproj
- [x] T014 Validate generated Spec Kit artifacts for unresolved placeholders in specs/002-secure-settings-reachability/spec.md, specs/002-secure-settings-reachability/plan.md, specs/002-secure-settings-reachability/research.md, specs/002-secure-settings-reachability/data-model.md, specs/002-secure-settings-reachability/contracts/settings-reachability-contract.md, specs/002-secure-settings-reachability/quickstart.md, and specs/002-secure-settings-reachability/tasks.md

---

## Dependencies & Execution Order

- Setup precedes foundational checks.
- Foundational checks precede all user stories.
- User Story 1 is MVP; User Stories 2 and 3 can be validated independently after foundational checks.
- Polish follows all selected user stories.

## Parallel Example: Setup

```bash
Task: "Verify source files in HermesiOS/HermesSettingsView.swift and related files"
Task: "Verify docs in specs/002-secure-settings-reachability/"
```

## Implementation Strategy

Complete static verification first, apply targeted fixes only if mismatches appear, then validate build and mark completed tasks.
