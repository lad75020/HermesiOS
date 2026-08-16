# Research: UI Design System

## Decision 1: Keep a single compatibility entry point for glass-style visuals

**Decision**
- Keep the glass/fallback implementation in `HermesDesignSystem.swift` (`hermesLiquidGlass`, `HermesLiquidGlassCanvas`, `HermesGlassEffectContainer`) as the shared UI primitive for this feature.

**Rationale**
- The app already depends on this path in many views (`ContentView`, settings, panels, web browser, status screens).
- Centralizing behavior here avoids visual drift and avoids duplicated iOS-version branching logic.

**Alternatives considered**
- Duplicate glass checks in every screen.
- Introduce one global `.backgroundGlass` helper replacing current extensions.

**Outcome**
- Keep the existing extension-based implementation and formalize component-level usage in planning.

## Decision 2: Preserve current iOS 26+ Glass behavior and older OS fallback

**Decision**
- Preserve current behavior:
  - iOS 26+ uses `glassEffect` / `glassProminent` / `glass` style APIs.
  - Pre-iOS 26 uses `ultraThinMaterial` and static shapes.

**Rationale**
- This already passes compile/runtime compatibility constraints and aligns with graceful fallback requirements.

**Alternatives considered**
- Drop glass APIs and standardize on material-only rendering.
- Add optional compile-time flags for design-only experiments.

**Outcome**
- Keep current availability checks as-is; plan validates no regressions in older OS rendering.

## Decision 3: Keep shared typography bootstrap at app launch and provide robust fallbacks

**Decision**
- Keep `HermesWebsiteTypography.registerBundledFonts()` in `HermesiOSApp.init()` and preserve existing fallback behavior in `Font` helpers.

**Rationale**
- Fonts are currently loaded once at app startup; this is less expensive than per-view registration.
- Custom fonts provide brand continuity where present, while fallback behavior remains explicit and predictable.

**Alternatives considered**
- Register fonts lazily in each feature or screen.
- Enforce non-fallback hard failure when fonts are missing.

**Outcome**
- Keep single bootstrap and fallback semantics so existing views remain stable if assets are unavailable.

## Decision 4: Keep splash flow tied to existing launch window and fallback to non-media behavior

**Decision**
- Keep current 2-second splash duration in `ContentView` and `HermesSplashView` loading model, with graceful nil-player behavior when media is missing.

**Rationale**
- Current product flow already uses this exact timing in existing implementation and avoids adding splash-related race conditions in startup paths.
- `HermesSplashPlayerModel` already guards missing asset and defines explicit stop behavior.

**Alternatives considered**
- Start main layout immediately and defer splash to background.
- Replace video with static image.

**Outcome**
- Keep player-based splash in this feature scope; do not change launch state machine now.

## Decision 5: Treat design-system boundaries as internal UI dependencies only

**Decision**
- Treat this feature as internal UX consistency work with no public API contract obligations.

**Rationale**
- The feature scope is purely component styling, shared primitives, typography registration, and launch media behavior.
- No new external integration contracts are introduced in this stage.

**Alternatives considered**
- Define contracts for style tokens and component parameters as public-facing API.
- Introduce design-token externalization in JSON at this stage.

**Outcome**
- No `contracts/` artifacts required for this feature.

## Decision 6: Preserve existing global behavior for status/navigation/background while documenting component touchpoints

**Decision**
- Keep `HermesAppearance.configureGlobalAppearance()` and `HermesLiquidGlassCanvas` usage boundaries as-is, while documenting their dependencies.

**Rationale**
- These are already the established visual integration points and are actively used in existing feature entry points and shared screens.
- Refactoring this behavior would alter app-wide presentation and is outside current feature scope.

**Alternatives considered**
- Introduce feature-local appearance overrides in every entry screen.
- Move background and tab/nav appearance out of SwiftUI init path.

**Outcome**
- Preserve and document current integration points only.

## Open points to validate during implementation

- Confirm no accessibility label regressions for buttons, pills, toggles, and accordions after any styling refinements.
- Confirm splash duration and transition produce no visible layout flash after `isShowingSplash` flips.
- Confirm missing font assets do not break text rendering or crash when register loop runs.
- Confirm missing splash media does not block app startup.