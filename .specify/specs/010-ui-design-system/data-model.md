# Data Model: UI Design System

## Entities

### Color token layer

#### `Color` static token set

- Location: `HermesiOS/HermesDesignSystem.swift`
- Scope: global shared colors used across iOS app views.
- Categories:
  - Instagram-style tokens: `igCanvasLight`, `igCanvasDark`, `igElevatedDark`, `igSurfaceInputL`, `igSurfaceInputD`, `igDividerLight`, `igDividerDark`
  - Text and accents: `igTextSecondaryL`, `igTextSecondaryD`, `igActionBlue`, `igActionPressed`, `igDestructive`, `igLinkLight`, `igLinkDark`
  - Gradients: `igGradBlue`, `igGradPurpleBlue`, `igGradPurple`, `igGradPurpleRed`, `igGradRose`, `igGradRed`, `igGradRedOrange`, `igGradOrange`, `igGradOrangeYellow`, `igGradYellow`
  - Dynamic `hermes*` palette values via `UIColor` dynamic provider:
    - `hermesCanvas`, `hermesElevated`, `hermesSurfaceInput`, `hermesDivider`, `hermesSecondaryText`, `hermesLink`
- State/invariant:
  - Token names are stable and additive within this feature scope.
  - Dynamic colors resolve per system color scheme.

#### `ShapeStyle` extension

- Location: `HermesiOS/HermesDesignSystem.swift`
- Adds shorthand access for static tokenized colors (`Color.hermesCanvas`, etc.).
- Purpose: simplify call sites while preserving semantic naming.

### Gradient layer

#### `LinearGradient.instagramBrand` and `.instagramBrandShort`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Purpose: brand wash and accent usage in reusable components.
- Invariants:
  - `instagramBrand` includes the full sequence of configured stops.
  - `instagramBrandShort` uses a shortened 3-stop variant.

#### `AngularGradient.storyRing`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Purpose: avatar/story ring effect for reusable decorative motifs.

### Glass + material behavior

#### `View.hermesLiquidGlass(cornerRadius:tint:interactive:)`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs:
  - `cornerRadius: CGFloat`
  - `tint: Color?`
  - `interactive: Bool`
- Behavior:
  - iOS 26+: applies `glassEffect` with configurable tint and optional interactive mode.
  - older iOS: applies `ultraThinMaterial` in same shape.
- Invariant:
  - Never crashes when run on lower OS versions.

#### `HermesLiquidGlassCanvas`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Rendered as a global decorative background with layered gradients/circles and theme adaptation.
- Invariant:
  - Provides visual continuity for app entry and high-level surfaces.

#### `HermesGlassEffectContainer`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Behavior:
  - Uses `GlassEffectContainer` on iOS 26+
  - Passthrough on older OS
- Invariant:
  - Keeps component grouping and morph behavior where supported.

#### `View.hermesGlassEffectID(_:in:)`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Purpose: stable identity for glass morphing containers.
- Invariant:
  - Calls are stable identifiers derived from deterministic section names where used.

#### `View.hermesGlassProminentButton()` and `View.hermesGlassButton()`

- Location: `HermesiOS/HermesDesignSystem.swift`
- OS-dependent mapping:
  - iOS 26+: `.glassProminent` / `.glass`
  - older iOS: `.borderedProminent` / `.bordered`
- Invariant:
  - No visual style crashes when called on older OS.

### Shared component primitives

#### `IGSectionHeader`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs: `title`, optional `trailing`
- Output: uppercase caption row with tracking and secondary style.
- Relation: used in multiple list/section contexts for visual consistency.

#### `IGCard<Content: View>`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs: `Content` view
- Purpose: containerized glass surface with standard spacing, shape, and width behavior.

#### `IGPrimaryButton`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs:
  - `title`, optional `icon`, `variant`, `isLoading`, action closure.
- Invariant:
  - Supports loading state with inline `ProgressView`.
  - Visual variant maps color and background in deterministic branch.

#### `IGStatusPill`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs: `label`, `value`, `tint`
- Use case: compact labeled status row for runtime and diagnostics contexts.

#### `IGChatBubble`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs: `text`, `isFromUser`, optional `timestamp`
- Invariant:
  - `isFromUser` inverts text alignments and color/shape treatment.

#### `IGIconButton`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs: `systemImage`, optional `size`, optional `tint`, action
- Purpose: compact icon control aligned to glass surface language.

#### `IGHairline`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Purpose: thin divider with tokenized secondary color.

#### `IGBrandHero`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Composition:
  - Title, subtitle, gradient wash, glass wrapper.

#### `IGFieldBackground`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs: none (modifier)
- Behavior:
  - Applies tokenized rounded background + stroke + glass effect.
- Invariant:
  - Reusable style for input fields to standardize text-entry visuals.

#### `HermesBrandBar`

- Location: `HermesiOS/HermesDesignSystem.swift`
- Inputs: `title`, optional trailing action view.
- Purpose: top brand/title surface.

### Typography layer

#### `HermesWebsiteTypography`

- Location: `HermesiOS/HermesWebsiteTypography.swift`
- API:
  - `registerBundledFonts()`
- Invariant:
  - Registers every `.woff2` font URL from `Fonts` folder and process-level duplicates are deduplicated.

#### Font extension helpers

- Location: `HermesiOS/HermesWebsiteTypography.swift`
- Helpers:
  - `Font.hermesWebsiteTitle`, `Font.hermesWebsiteSectionTitle`, `Font.hermesWebsiteLabel`, `Font.hermesWebsiteMono`
  - view helpers: `hermesWebsiteTitleFont`, `hermesWebsiteSectionTitleFont`, `hermesWebsiteLabelFont`
- Invariant:
  - Named helpers are stable and referenced consistently across the UI.

### Splash subsystem

#### `HermesSplashView`

- Location: `HermesiOS/HermesSplashView.swift`
- Inputs: none (state-owned internally)
- Rendering:
  - Uses `HermesSplashPlayerModel` and `HermesSplashVideoPlayer`.
- Invariant:
  - If media is missing, content remains black and app still continues.

#### `HermesSplashPlayerModel`

- Location: `HermesiOS/HermesSplashView.swift`
- Fields/state:
  - `player: AVPlayer?`
- Methods:
  - `playFromBeginning()`
  - `stop()`
- Invariant:
  - `player` remains optional; nil path is valid and non-fatal.
  - playback starts on appear and pauses on disappear.

#### `HermesSplashVideoPlayer` and `HermesSplashVideoPlayerView`

- Location: `HermesiOS/HermesSplashView.swift`
- Purpose: UIView wrapper around `AVPlayerLayer` with `.resizeAspectFill` behavior.
- Invariant:
  - Layer class remains `AVPlayerLayer`, updated only when needed.

### App entry and global integration

#### `HermesiOSApp`

- Location: `HermesiOS/HermesiOSApp.swift`
- Responsibility: app init calls `HermesWebsiteTypography.registerBundledFonts()`.

#### `ContentView`

- Location: `HermesiOS/ContentView.swift`
- Responsibility:
  - `isShowingSplash` startup state (2s timer) drives splash visibility.
  - global background and appearance are set through design system helpers.
- Dependency:
  - reads `HermesSplashView()` and `HermesLiquidGlassCanvas`.
- Invariant:
  - splash is shown first and transitions off automatically while maintaining state initialization.

## State and transitions

### Font bootstrap lifecycle

1. App init executes font registration.
2. Registration runs idempotent and adds available bundled fonts.
3. Font helpers resolve to named assets where available.
4. Missing assets fall back to platform/system behavior if font lookup fails.

### Glass primitive lifecycle

1. View body calls `hermesLiquidGlass(...)`.
2. OS gate decides native glass or material fallback.
3. Tint and interactive parameters control motion/press affordance.

### Splash lifecycle

1. `ContentView` shows `HermesSplashView` while `isShowingSplash == true`.
2. `HermesSplashView` starts playback on appear if player exists.
3. `ContentView` waits for timer and transitions to main layout.
4. On disappear, `HermesSplashPlayerModel.stop()` pauses playback.

### Design-system dependency graph

- `HermesAppearance.configureGlobalAppearance()` establishes baseline nav/tab appearance.
- `HermesDesignSystem` primitives are used by all major screens in the app.
- `HermesRuntimeComponents` and `HermesWebsiteTypography` are feature artifacts consumed by existing runtime views.

## Validation rules

- No direct references to network secrets, credentials, or local storage policy in this feature.
- Any future styling changes should preserve:
  - OS fallback behavior,
  - optional media handling,
  - and stable tokenized semantics.
- Global appearance and splash behavior are treated as shared integration points and must remain deterministic.