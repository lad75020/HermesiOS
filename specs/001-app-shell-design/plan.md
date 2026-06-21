# Implementation Plan: App Shell and Design System

**Branch**: `feature/time-machine-app-shell-design` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-app-shell-design/spec.md`

## Summary

Retroactively document and validate the HermesiOS app shell, shared design system, workspace navigation, launch media, localization resources, app metadata, and branding assets. The technical approach is to preserve the existing native app structure, verify that shell-level SwiftUI components and resources satisfy the specification, and add only targeted fixes if validation reveals a mismatch.

## Technical Context

**Language/Version**: Swift 5 project settings with Apple platform SDKs from the installed Xcode toolchain

**Primary Dependencies**: SwiftUI, Observation, UIKit interoperability, PhotosUI, Vision/VisionKit where already used by the shell entry area, AVFoundation/Combine for splash media, CoreText for typography helpers, local asset catalogs and localization catalogs

**Storage**: Local app settings and resource bundles only for this feature; no new persistent domain storage required

**Testing**: Xcode build validation plus manual or automated UI smoke checks on iOS/iPadOS simulator or device; localization and appearance checks through app runtime configuration

**Target Platform**: iOS/iPadOS companion app target with project deployment target 26.4; shell resources must remain independent of live Hermes host availability

**Project Type**: Native mobile companion app with a paired macOS helper target in the same repository; this feature scopes only the iOS/iPadOS shell and shared visual resources

**Performance Goals**: Primary shell visible within 5 seconds after app open; workspace section switches under 2 seconds; splash media must never indefinitely block shell access

**Constraints**: Preserve current user preference that tool/event/debug logs are not rendered in assistant chat bubbles; keep host-dependent failures out of the shell's core navigation path; preserve existing assets/localizations unless a mismatch is proven

**Scale/Scope**: One app shell, 10+ workspace sections, shared visual components reused across multiple panels, 5 localization folders plus string catalog resources

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution is still the untouched Spec Kit template and is not ratified. Apply default project gates for this native companion app:

- **Platform UX Gate**: PASS — changes must preserve native iOS/iPadOS navigation, appearance, accessibility, and launch behavior.
- **Secure Local Data Gate**: PASS — shell work must not introduce new arbitrary host mutation, secrets exposure, or unbounded background activity.
- **Offline Shell Gate**: PASS — shell and navigation must remain usable when Hermes host services are unavailable.
- **Localization/Appearance Gate**: PASS — shell labels, metadata, theme, and brand surfaces must remain legible across supported languages and appearances.
- **Build Readiness Gate**: PASS — any source/resource change must be validated by an Xcode build or a clearly reported blocker.
- **Scope Control Gate**: PASS — this feature excludes service-specific workflows handled by later Time Machine features.

## Project Structure

### Documentation (this feature)

```text
specs/001-app-shell-design/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── shell-ui-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
HermesiOS/
├── HermesiOSApp.swift
├── ContentView.swift
├── HermesWorkspaceNavigation.swift
├── HermesSharedViews.swift
├── HermesDesignSystem.swift
├── HermesAppTheme.swift
├── HermesWebsiteTypography.swift
├── HermesSplashView.swift
├── HermesBackgroundActivity.swift
├── Assets.xcassets/
├── Resources/
├── Fonts/
├── Localizable.xcstrings
├── Info.plist
├── HermesiOS.entitlements
├── HermesiOSRelease.entitlements
├── de.lproj/InfoPlist.strings
├── en.lproj/InfoPlist.strings
├── es.lproj/InfoPlist.strings
├── fr.lproj/InfoPlist.strings
└── zh-Hans.lproj/InfoPlist.strings

HermesiOS.xcodeproj/
└── project.pbxproj
```

**Structure Decision**: Use the existing single native iOS/iPadOS app target structure. Shell-level feature work stays in `HermesiOS/` shared UI/resource files and project metadata. No new module, package, backend, or persistence layer is required.

## Phase 0: Research Summary

Research decisions are captured in [research.md](./research.md). All planning unknowns are resolved with project-local evidence and conservative defaults.

## Phase 1: Design Summary

- Data model is captured in [data-model.md](./data-model.md).
- Shell UI behavior contract is captured in [contracts/shell-ui-contract.md](./contracts/shell-ui-contract.md).
- Validation scenarios are captured in [quickstart.md](./quickstart.md).
- Agent context has been updated to point at this plan.

## Post-Design Constitution Check

- **Platform UX Gate**: PASS — design artifacts validate existing shell entry, navigation, theme, launch, and shared surface behavior.
- **Secure Local Data Gate**: PASS — no new secret storage or host mutation is introduced by this feature plan.
- **Offline Shell Gate**: PASS — quickstart includes an offline-host shell validation scenario.
- **Localization/Appearance Gate**: PASS — quickstart includes supported localization and appearance checks.
- **Build Readiness Gate**: PASS — tasks will require build or explicit blocker reporting before marking implementation complete.
- **Scope Control Gate**: PASS — later service panels remain out of scope except as navigation destinations.

## Complexity Tracking

No constitution gate violations or justified complexity exceptions are present.
