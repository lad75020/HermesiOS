# Implementation Plan: Utilities, History, and Downloads

**Branch**: `feature/time-machine-utilities-history-downloads` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-utilities-history-downloads/spec.md`

## Summary

Retroactively document and validate Utilities, History, and Downloads. The feature already exists in the HermesiOS source tree, so implementation focuses on scoped artifact generation, source-file existence and pattern checks, no-placeholder validation, and preserving the successful Xcode build baseline.

## Technical Context

**Language/Version**: Swift 5 project settings with Apple platform SDKs from the installed Xcode toolchain

**Primary Dependencies**: Existing Apple platform frameworks and package dependencies used by the scoped source files

**Storage**: Existing local app storage or host-backed state only where already used by the scoped feature files

**Testing**: Static source inspection, generated artifact validation, and Xcode build validation baseline

**Target Platform**: iOS/iPadOS companion app target with project deployment target 26.4

**Project Type**: Native mobile companion app feature area

**Performance Goals**: Primary feature surface reachable in under 2 seconds once the app shell is responsive

**Constraints**: Preserve sensitive-data boundaries, existing shell conventions, and feature scope

**Scale/Scope**: 2 scoped source/resource paths

## Constitution Check

The constitution is template-only. Default gates all PASS: platform UX, secure local data, offline recovery, build readiness, and scope control.

## Project Structure

### Documentation (this feature)

```text
specs/010-utilities-history-downloads/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── utilities-history-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
HermesiOS/HermesUtilitiesView.swift
HermesiOS/Item.swift
```

**Structure Decision**: Keep validation and any future targeted fixes inside the listed source/resource paths. No new module is required.

## Phase 0: Research Summary

Research decisions are captured in [research.md](./research.md).

## Phase 1: Design Summary

- Data model: [data-model.md](./data-model.md)
- Observable behavior contract: [contracts/utilities-history-contract.md](./contracts/utilities-history-contract.md)
- Validation flow: [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

Default gates remain PASS because the plan introduces documentation/validation artifacts and no risky source mutation.

## Complexity Tracking

No constitution gate violations or justified complexity exceptions are present.
