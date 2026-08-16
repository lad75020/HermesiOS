# Tasks: UI Design System

## Phase 1: Setup
- [X] T001 Validate `.specify/feature.json` points to `./.specify/specs/010-ui-design-system` and confirm `git branch --show-current` is `feature/time-machine-ui-design`.
- [X] T002 [P] Confirm required artifacts exist: `./.specify/specs/010-ui-design-system/spec.md`, `./.specify/specs/010-ui-design-system/plan.md`, `./.specify/specs/010-ui-design-system/research.md`, `./.specify/specs/010-ui-design-system/data-model.md`, and `./.specify/specs/010-ui-design-system/quickstart.md`.
- [X] T003 Verify there is no mandatory pre-task hook in `./.specify/extensions.yml` and document no-op if the hook file is absent.
- [X] T004 Verify no unresolved planning markers remain in `./.specify/specs/010-ui-design-system/spec.md`, `./.specify/specs/010-ui-design-system/research.md`, and `./.specify/specs/010-ui-design-system/data-model.md`.
- [X] T005 Confirm assets in scope exist in-repo: `./HermesiOS/HermesiOS/Resources/HermesSplash.mp4`, `./HermesiOS/HermesiOS/Fonts`, and all `.woff2` files consumed by `./HermesiOS/HermesiOS/HermesWebsiteTypography.swift`.

## Phase 2: Foundational
- [X] T006 Audit all files in feature scope: `./HermesiOS/HermesiOS/HermesDesignSystem.swift`, `./HermesiOS/HermesiOS/HermesRuntimeComponents.swift`, `./HermesiOS/HermesiOS/HermesWebsiteTypography.swift`, and `./HermesiOS/HermesiOS/HermesSplashView.swift`.
- [X] T007 Extract all glass and container usage sites in `./HermesiOS/HermesiOS/HermesiOSApp.swift`, `./HermesiOS/HermesiOS/ContentView.swift`, `./HermesiOS/HermesiOS/HermesSettingsView.swift`, and `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- [X] T008 [P] Verify `#available(iOS 26.0, *)` fallback branches in `./HermesiOS/HermesiOS/HermesDesignSystem.swift` and `./HermesiOS/HermesiOS/HermesRuntimeComponents.swift` avoid crash paths on older OS versions.
- [X] T009 Add the feature launch/visual-state constraints to `./.specify/specs/010-ui-design-system/data-model.md` for `HermesSplashView` and `HermesLiquidGlassCanvas`.
- [X] T010 [P] Capture baseline usage evidence for `./HermesiOS/HermesiOS/HermesDesignSystem.swift`, `./HermesiOS/HermesiOS/HermesWebsiteTypography.swift`, and `./HermesiOS/HermesiOS/HermesSplashView.swift` in `./.specify/specs/010-ui-design-system/research.md`.

## Phase 3: User Story 1 — Branded splash transition
- [X] T011 [US1] Verify `./HermesiOS/HermesiOS/ContentView.swift` still renders `HermesSplashView()` first and transitions out after the 2-second timer.
- [X] T012 [US1] Harden `./HermesiOS/HermesiOS/HermesSplashView.swift` so `playFromBeginning()` always starts from `.`zero and `stop()` always pauses playback.
- [X] T013 [US1] Harden `./HermesiOS/HermesiOS/HermesSplashView.swift` so missing `./HermesiOS/HermesiOS/Resources/HermesSplash.mp4` preserves app startup flow in `./HermesiOS/HermesiOS/ContentView.swift`.
- [X] T014 [US1] Verify `./HermesiOS/HermesiOS/HermesSplashView.swift` keeps `accessibilityHidden(true)` enabled without blocking launch state transitions.
- [X] T015 [US1] [P] Add a launch regression check for missing media in `./.specify/specs/010-ui-design-system/quickstart.md`.

## Phase 4: User Story 2 — Visual consistency across screens
- [X] T016 [US2] Replace local duplicated visual surfaces in `./HermesiOS/HermesiOS/HermesSettingsView.swift` with shared primitives from `./HermesiOS/HermesiOS/HermesDesignSystem.swift` where feasible.
- [X] T017 [US2] Normalize runtime shell visuals in `./HermesiOS/HermesiOS/HermesRuntimeComponents.swift` by using `IGCard`, `IGSectionHeader`, and `IGStatusPill` where currently duplicated.
- [X] T018 [US2] Align web-browser and host controls in `./HermesiOS/HermesiOS/HermesWebBrowserView.swift` to shared section/input/button conventions from `./HermesiOS/HermesiOS/HermesDesignSystem.swift`.
- [X] T019 [US2] [P] Align status presentation in `./HermesiOS/HermesiOS/HermesStatusBand.swift` and `./HermesiOS/HermesiOS/HermesWorkspaceNavigation.swift` with shared glass/shape conventions.
- [X] T020 [US2] Replace remaining one-off status/input styles in `./HermesiOS/HermesiOS/ContentView.swift` with shared helpers.

## Phase 5: User Story 3 — Typography continuity and fallbacks
- [X] T021 [US3] Verify `./HermesiOS/HermesiOS/HermesWebsiteTypography.swift` keeps bundled-font registration deduplicated and non-failing for missing fonts.
- [X] T022 [US3] Audit typography call sites in `./HermesiOS/HermesiOS/HermesiOSApp.swift` and `./HermesiOS/HermesiOS/ContentView.swift` to migrate missing calls to `Font.hermesWebsite*` helpers.
- [X] T023 [US3] Update shared title/body/label text in `./HermesiOS/HermesiOS/HermesSettingsView.swift` and `./HermesiOS/HermesiOS/HermesStatusBand.swift` to use `hermesWebsite*` helpers.
- [X] T024 [US3] [P] Add explicit missing-font fallback validation in `./.specify/specs/010-ui-design-system/quickstart.md` based on `./HermesiOS/HermesiOS/HermesWebsiteTypography.swift`.
- [X] T025 [US3] Verify cross-feature helper stability for `Font` and `View` helpers from `./HermesiOS/HermesiOS/HermesWebsiteTypography.swift`.

## Phase 6: User Story 4 — Interaction and feedback states in shared controls
- [X] T026 [US4] Consolidate button loading/disabled behavior via `IGPrimaryButton` from `./HermesiOS/HermesiOS/HermesDesignSystem.swift` in primary action sites like `./HermesiOS/HermesiOS/HermesSettingsView.swift`.
- [X] T027 [US4] Verify `./HermesiOS/HermesiOS/HermesDesignSystem.swift` and `./HermesiOS/HermesiOS/HermesRuntimeComponents.swift` keep consistent press feedback and non-blocking interaction states.
- [X] T028 [US4] Standardize status, toggle, and pill states in `./HermesiOS/HermesiOS/HermesRuntimeComponents.swift` and `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- [X] T029 [US4] [P] Add accessibility state labels for shared controls in `./HermesiOS/HermesiOS/HermesRuntimeComponents.swift` and `./HermesiOS/HermesiOS/HermesSettingsView.swift`.
- [X] T030 [US4] Verify `./HermesiOS/HermesiOS/ContentView.swift` preserves active feedback during streaming and status updates.

## Phase 7: User Story 5 — Accessibility and OS compatibility
- [X] T031 [US5] Verify `./HermesiOS/HermesiOS/HermesDesignSystem.swift` keeps iOS 26 glass behavior and older-OS material fallback stable for primary surfaces.
- [X] T032 [US5] Verify fallback behavior for `hermesLiquidGlass`, `HermesLiquidGlassCanvas`, and `HermesGlassEffectContainer` across representative screens in `./HermesiOS/HermesiOS/HermesSplashView.swift` and `./HermesiOS/HermesiOS/ContentView.swift`.
- [X] T033 [US5] Add light/dark and reduced-motion smoke checks in `./.specify/specs/010-ui-design-system/quickstart.md` using screens from `./HermesiOS/HermesiOS/HermesiOSApp.swift`.
- [X] T034 [US5] [P] Update `./.specify/specs/010-ui-design-system/checklists/requirements.md` for any accessibility or compatibility gaps.
- [X] T035 [US5] Verify readable contrast and clear state labels in `./HermesiOS/HermesiOS/HermesDesignSystem.swift`, `./HermesiOS/HermesiOS/HermesStatusBand.swift`, and `./HermesiOS/HermesiOS/ContentView.swift`.

## Phase 8: Polish & Cross-Cutting Concerns
- [X] T036 Record final acceptance evidence for all stories in `./.specify/specs/010-ui-design-system/quickstart.md`.
- [X] T037 [P] Reconcile any remaining blockers in `./.specify/specs/010-ui-design-system/research.md` and `./.specify/specs/010-ui-design-system/plan.md` after implementation adjustments.
- [X] T038 Run `./Volumes/WDBlack4TB/.hermes/skills/local/speckit-tasks/scripts/validate_tasks.py ././.specify/specs/010-ui-design-system/tasks.md` and fix any validation issues.
- [X] T039 Run a clean app-target build gate from project root and report results in `./.specify/specs/010-ui-design-system/quickstart.md`.
- [X] T040 Update `./.specify/specs/010-ui-design-system/quickstart.md` with final launch, typography, interaction, and compatibility observations.

## Dependencies
- T001, T002, T003, and T004 are required before moving into foundational and story work.
- T006 through T010 gate all user stories.
- US1 (T011-T015) depends on T006 and T007.
- US2 (T016-T020) depends on T007 plus shared-surface baseline updates in T009-T010.
- US3 (T021-T025) depends on T006 and typography checks from T022.
- US4 (T026-T030) follows US1-US3 stabilization.
- US5 (T031-T035) depends on US1-US4 completion.
- Polish tasks T036-T040 are completed after all story tasks.

## Independent test criteria
- US1: launch transitions from `./HermesiOS/HermesiOS/ContentView.swift` and `./HermesiOS/HermesiOS/HermesSplashView.swift` are smooth and always complete, including missing media.
- US2: shared surfaces in `./HermesiOS/HermesiOS/HermesSettingsView.swift`, `./HermesiOS/HermesiOS/HermesRuntimeComponents.swift`, `./HermesiOS/HermesiOS/HermesWebBrowserView.swift`, and `./HermesiOS/HermesiOS/HermesStatusBand.swift` are consistent and reusable.
- US3: `./HermesiOS/HermesiOS/HermesWebsiteTypography.swift` and key callers in `./HermesiOS/HermesiOS/HermesSettingsView.swift` use branded helpers with safe fallback behavior.
- US4: `./HermesiOS/HermesiOS/HermesDesignSystem.swift` and `./HermesiOS/HermesiOS/HermesRuntimeComponents.swift` surface deterministic press/loading states and clear on/off semantics.
- US5: `./HermesiOS/HermesiOS/HermesDesignSystem.swift` and `./HermesiOS/HermesiOS/HermesiOSApp.swift` remain readable and stable across light/dark and OS-capability branches.

## Parallel execution examples
- T002 and T003 can run in parallel.
- T006, T007, and T010 can run in parallel once setup tasks are done.
- T016 and T017 can be worked on separately from `./HermesiOS/HermesiOS/HermesStatusBand.swift`.
- T021 and T023 can run in parallel.
- T029 and T024 can run independently as non-functional acceptance tasks.
- T038 runs after all checklist edits are complete.

## Implementation strategy
- Complete setup and foundational tasks first.
- Execute user stories in order: US1 → US2 → US3 → US4 → US5.
- Keep changes incremental, preserving existing behavior while introducing shared reusable helpers.
- Finish with validation and final verification in `./.specify/specs/010-ui-design-system/quickstart.md` and `./.specify/specs/010-ui-design-system/checklists/requirements.md`.
