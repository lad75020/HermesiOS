# Quickstart: UI Design System

## Objective

Define a reproducible pre-implementation validation pass that confirms shared design-system components, typography registration, and splash behavior are well-scoped and consistent before implementation starts.

## Prerequisites

- Branch: `feature/time-machine-ui-design`
- Build prerequisites for HermesiOS are met and project opens in Xcode.
- Required media assets exist in repo (`HermesiOS/Resources/HermesSplash.mp4`, `HermesiOS/Fonts/*`).
- Feature context is correct (`.specify/feature.json` points to `specs/010-ui-design-system`).

## Step 1 — Spec-to-design scope check

1. Open `.specify/specs/010-ui-design-system/spec.md` and confirm scope is limited to:
   - shared visual system,
   - typography,
   - splash path.
2. Cross-check `.specify/specs/010-ui-design-system/spec.md` files-in-scope section with this plan's artifact scope.
3. Confirm no other feature-specific requirement (API companion, host protocol, history, etc.) is pulled into this feature.

Expected result:

- Scope only includes the four design files plus app startup/appearance touchpoints.

## Step 2 — Font registration and fallback behavior

1. In `HermesiOSApp.init()`, confirm `HermesWebsiteTypography.registerBundledFonts()` is invoked exactly once.
2. Verify font registration code path in `HermesWebsiteTypography.registerBundledFonts()`:
   - enumerates bundled `.woff2` URLs,
   - deduplicates repeated URLs,
   - calls registration process once per unique font URL.
3. Launch the app and run a known typography screen:
   - verify section titles use `hermesWebsite*` typography where specified,
   - verify missing font does not crash and fallback text remains readable.
4. Optional regression check: temporarily rename one `.woff2` file in a local branch (not committed) and confirm fallback is readable.

Expected result:

- Launch stays stable with and without every optional font asset present.
- No runtime crash during font registration.

## Step 3 — Glass compatibility behavior validation

1. Run app on iOS 26+ simulator/device:
   - open a screen with `hermesLiquidGlass` and confirm interactive and non-interactive variants render appropriately.
2. Run app on pre-iOS-26 simulator/device:
   - confirm `ultraThinMaterial` fallback appears (no runtime symbol crash).
3. Validate shared components that use glass primitives:
   - `IGCard`,
   - `IGSectionHeader`,
   - `IGPrimaryButton`,
   - `IGStatusPill`,
   - `IGIconButton`.

Expected result:

- Visual consistency is preserved on both OS branches.
- No hard dependency on unavailable iOS 26 glass APIs.

## Step 4 — App entry/splash behavior validation

1. Confirm `ContentView` starts with `HermesSplashView`:
   - `isShowingSplash` true path renders media when available.
2. Confirm `HermesSplashPlayerModel` behavior:
   - starts at `.zero` on appear,
   - pauses on disappear.
3. Confirm app automatically transitions out of splash after the configured delay and reveals main layout.
4. Validate missing media behavior by temporarily renaming `HermesSplash.mp4` in a local branch and confirming startup proceeds with blank/black background path.

Expected result:

- No startup hang when splash asset is unavailable.
- Splash phase always exits.

## Step 5 — Component reuse check

1. Open screens where design primitives are already in use:
   - `HermesiOS/HermesSettingsView.swift`
   - `HermesiOS/HermesRuntimeComponents.swift`
   - `HermesiOS/HermesWebBrowserView.swift`
   - `HermesiOS/HermesStatusBand.swift`
   - `HermesiOS/HermesConsoleViews.swift`
2. Confirm style consistency markers:
   - shared spacing and rounded surfaces,
   - status/input/button visual language,
   - tab/sidebar and background consistency.

Expected result:

- Shared components are discoverable and used consistently.

## Step 6 — Accessibility and interaction smoke checks

1. Turn on VoiceOver:
   - verify major controls keep readable labels and are still focusable.
2. Confirm toggle buttons and status pills in shared components are understandable in both light/dark modes.
3. Confirm reduced-motion users still get coherent transitions (no glass API failures blocking layout).

Expected result:

- Accessibility baseline remains valid with no crash/blank render.

## Step 7 — Build gate before implementation

1. Run a normal `xcodebuild` test target build (or at least clean build for app target).
2. Confirm no compile errors are introduced by design-system references and no file import regressions.

Expected result:

- Clean build succeeds on the current branch before implementation.

## Completion evidence

Record evidence after each step in the engineering notes:

- Device/simulator type
- OS version
- Whether iOS 26 glass path or fallback path was observed
- Splash behavior outcome (media present vs nil fallback)
- Font loading behavior summary
- Any accessibility deviations found


## Implementation Evidence

- 2026-08-16: `branch --show-current` is `feature/time-machine-ui-design` and `.specify/feature.json` points to `specs/010-ui-design-system`.
- 2026-08-16: Required artifacts exist and loaded: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`.
- 2026-08-16: Asset inventory check passed for `HermesiOS/Resources/HermesSplash.mp4`, `HermesiOS/Fonts/*` and all four `.woff2` files referenced by `HermesWebsiteTypography`.
- 2026-08-16: Build gate passed.
  - Command: `xcodebuild -project HermesiOS.xcodeproj -scheme HermesiOS -destination 'generic/platform=iOS' -configuration Debug build`
  - Result: `BUILD SUCCEEDED` (app target).
- 2026-08-16: Validation scripts run:
  - `python3 /Volumes/WDBlack4TB/.hermes/skills/local/speckit-tasks/scripts/validate_tasks.py ./.specify/specs/010-ui-design-system/tasks.md`
  - Result: `VALIDATION PASSED`.
- 2026-08-16: Splash path behavior checks:
  - `playFromBeginning()` seeks to `.zero` before `play()`.
  - `stop()` uses `pause()`.
  - Missing media handled via `HermesSplashPlayerModel.player == nil` nil path.
- 2026-08-16: Typographic registration behavior:
  - `HermesWebsiteTypography.registerBundledFonts()` enumerates `.woff2` assets and deduplicates URLs through a `Set`.
  - `Font` helpers remain role-based for title/section/label/mono text.

