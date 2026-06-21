# Implementation Plan: Secure Settings and Reachability

**Branch**: `feature/time-machine-secure-settings-reachability` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-secure-settings-reachability/spec.md`

## Summary

Retroactively document and validate the secure settings, endpoint validation, QR onboarding, credential persistence, and service reachability surfaces used by HermesiOS. The technical approach is to preserve existing settings files, statically verify sensitive-storage and endpoint-safety patterns, and rely on Xcode build validation because this Time Machine feature introduces documentation and validation artifacts only.

## Technical Context

**Language/Version**: Swift 5 project settings with Apple platform SDKs from the installed Xcode toolchain

**Primary Dependencies**: SwiftUI, Observation, AVFoundation for QR scanning, LocalAuthentication, Security/Keychain, Network, Foundation URL handling

**Storage**: Keychain for sensitive credentials; local preferences or codable settings for non-sensitive host and UI choices

**Testing**: Static source inspection for credential and endpoint safety, settings persistence review, reachability-state review, and Xcode build validation

**Target Platform**: iOS/iPadOS companion app target with project deployment target 26.4

**Project Type**: Native mobile companion app settings and connectivity subsystem

**Performance Goals**: Reachability status updates complete within 10 seconds in normal network conditions; settings edits persist without perceptible delay

**Constraints**: Do not expose bearer tokens or companion secrets in normal UI/log output; allow loopback development endpoints while blocking unsafe non-loopback plaintext use for sensitive traffic

**Scale/Scope**: Four primary source files plus related status presentation and endpoint security helpers

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution is template-only. Default gates:

- **Secure Storage Gate**: PASS — sensitive settings must use Keychain/security APIs.
- **Endpoint Safety Gate**: PASS — non-loopback plaintext transport carrying sensitive data must be rejected or safely constrained.
- **User Recovery Gate**: PASS — invalid settings and unreachable services must be actionable.
- **Build Readiness Gate**: PASS — any source/resource changes require Xcode build validation.
- **Scope Control Gate**: PASS — downstream panel behavior remains separate from settings/reachability.

## Project Structure

### Documentation (this feature)

```text
specs/002-secure-settings-reachability/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── settings-reachability-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
HermesiOS/
├── HermesSettingsView.swift
├── HermesSettingsPersistence.swift
├── HermesHostEndpoints.swift
└── HermesStatusBand.swift
```

**Structure Decision**: Keep this feature in existing settings, persistence, endpoint, and status-band files. No new storage layer or network service is planned.

## Phase 0: Research Summary

Research decisions are captured in [research.md](./research.md).

## Phase 1: Design Summary

- Data model: [data-model.md](./data-model.md)
- Observable behavior contract: [contracts/settings-reachability-contract.md](./contracts/settings-reachability-contract.md)
- Validation flow: [quickstart.md](./quickstart.md)
- Agent context remains pointed at this plan for the active feature.

## Post-Design Constitution Check

- **Secure Storage Gate**: PASS — tasks validate Keychain/security API usage.
- **Endpoint Safety Gate**: PASS — tasks validate loopback and remote plaintext handling.
- **User Recovery Gate**: PASS — spec and contract define actionable invalid/unreachable states.
- **Build Readiness Gate**: PASS — tasks include build validation or explicit blocker recording.
- **Scope Control Gate**: PASS — only settings/reachability files are in feature scope.

## Complexity Tracking

No constitution gate violations or justified complexity exceptions are present.
