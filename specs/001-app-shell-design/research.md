# Research: App Shell and Design System

## Decision: Treat this as a retrospective validation and documentation feature

**Rationale**: The queue was generated from an existing codebase. The app shell, navigation, shared components, assets, localizations, and launch resources already exist under `HermesiOS/`. Implementation should first verify current behavior against the new specification and only make targeted fixes if mismatches are found.

**Alternatives considered**:
- Rebuild the shell from scratch: rejected because the existing app already has shell structure and this would create unnecessary regression risk.
- Split design system and navigation into separate Time Machine features: rejected because their source files and user value are tightly coupled at shell level.

## Decision: Keep host availability outside the core shell dependency path

**Rationale**: README and existing project structure describe multiple host-backed panels, but the shell must remain reachable even when gateway, dashboard, or companion services are offline. The shell should own navigation and high-level presentation; individual panels should own service-specific errors.

**Alternatives considered**:
- Block launch until host status is known: rejected because it violates offline shell usability and makes troubleshooting harder.
- Hide all service panels when host is offline: rejected because it reduces discoverability and prevents users from reaching settings or diagnostics.

## Decision: Validate shared UI through representative shell surfaces

**Rationale**: Shared visual components are reused across many panels. A representative validation set covering navigation, headers/cards/status rows, launch/splash, and theme/localization provides meaningful confidence without testing every downstream feature in this Time Machine feature.

**Alternatives considered**:
- Exhaustive visual validation of every panel: rejected because later Time Machine features cover panel-specific workflows.
- Source-only inspection: rejected because shell regressions are often visual or runtime-state issues.

## Decision: Preserve existing localization and brand resource structure

**Rationale**: The repository contains string catalogs, localized InfoPlist resources, fonts, images, asset catalogs, and launch media. The feature should verify that these resources are present and used coherently rather than introducing a second resource strategy.

**Alternatives considered**:
- Move all copy into a new localization layer: rejected because it is broader than shell validation and risks disrupting existing translations.
- Remove launch media fallback: rejected because a missing or delayed splash must not prevent shell access.

## Decision: Use Xcode build plus focused runtime checks as the validation baseline

**Rationale**: This is a native Apple platform app with project-level resource and entitlement dependencies. A successful build catches resource/project integration issues, while runtime shell checks validate launch, navigation, offline behavior, localization, and appearance.

**Alternatives considered**:
- Unit tests only: rejected because this feature is dominated by app shell composition and visual/runtime behavior.
- Manual inspection only: rejected because build validation is a necessary guard for resource/project changes.
