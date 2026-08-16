# Plan: UI Design System

## Technical Context

- Design system foundations are defined in `HermesiOS/HermesDesignSystem.swift`:
  - Color token set (`ig*`, `hermes*`) and gradient helpers.
  - Liquid-glass helpers and compatibility fallbacks:
    - `View.hermesLiquidGlass(cornerRadius:tint:interactive:)`
    - `View.hermesGlassProminentButton()`
    - `View.hermesGlassButton()`
    - `View.hermesGlassEffectID(_:in:)`
  - Shared component primitives:
    - `IGSectionHeader`, `IGCard`, `IGPrimaryButton`, `IGStatusPill`, `IGChatBubble`, `IGIconButton`, `IGHairline`, `IGFieldBackground`, `HermesBrandBar`, `IGBrandHero`
  - Shared canvas/background utilities:
    - `HermesLiquidGlassCanvas`, `HermesLiquidGlassBackground`, `HermesGlassEffectContainer`
  - App-wide styling and nav appearance helpers:
    - `HermesAppearance.configureGlobalAppearance()`

- Runtime component surface is in `HermesiOS/HermesRuntimeComponents.swift`:
  - `HermesRuntimeAccordionPanel`
  - `HermesSkillToggleRow`
  - `HermesToolsetToggleRow`
  - `HermesAgentConfiguration`
  - `hermesRuntimeInput` view modifier

- Typography integration is in `HermesiOS/HermesWebsiteTypography.swift`:
  - `HermesWebsiteTypography.registerBundledFonts()`
  - `Font.hermesWebsiteTitle(size:)`, `hermesWebsiteSectionTitle(size:)`, `hermesWebsiteLabel(size:)`, `hermesWebsiteMono(size:weight:)`
  - Associated view helpers (`hermesWebsiteTitleFont`, etc.)

- Splash system currently uses `HermesiOS/HermesSplashView.swift`:
  - `HermesSplashPlayerModel` loads `HermesSplash.mp4` and controls AVPlayer lifecycle.
  - `HermesSplashVideoPlayer` wraps `AVPlayerLayer`.

- App-level integration points:
  - `HermesiOS/HermesiOSApp.swift` registers bundled fonts during app init.
  - `ContentView.swift`:
    - calls `HermesAppearance.configureGlobalAppearance()` in `init()`
    - uses `HermesLiquidGlassCanvas` as global background
    - hosts splash transition logic
  - The design system is already adopted broadly across other screens (settings, runtime panels, web browser, status, console, gateway, etc.).

- Asset baseline under `HermesiOS/Fonts/*` and `HermesiOS/Resources/HermesSplash.mp4` exists and is part of current design-system behavior.

- No generated contracts are present for this feature and no external API is introduced by this scope.

## Approach

1. Resolve all unresolved technical points in one decision pass (`research.md`) before moving to implementation.
2. Keep plan scope strict to shared visual, typography, and splash assets for current app sections that consume this system.
3. Preserve existing component behavior and compatibility pathways:
   - `#available(iOS 26.0, *)` glass APIs
   - fallback path for earlier OS versions
   - local font registration with safe defaults
4. Keep runtime panels and shared controls consistent with this feature by documenting entity/state transitions in `data-model.md`.
5. Produce deterministic validation instructions in `quickstart.md` that can be executed before implementation starts.

## Phase 0 — Research and decision capture

- Collect and formalize all design-system behavior decisions from current implementation:
  - glass behavior on iOS 26 vs. fallback behavior on earlier iOS versions
  - font registration and fallback strategy
  - splash lifecycle and transition timing semantics
  - component reuse boundaries and compatibility constraints
- Explicitly confirm how each existing token/component is reused in dependent views.
- Record each decision in `research.md` with alternatives and rationale.

### Clarification policy

- The current feature spec has no unresolved `NEEDS CLARIFICATION` markers.
- Any remaining ambiguities are converted into explicit decisions:
  - if one behavior is inherited from existing code, document that decision,
  - if behavior diverges across files, define one canonical interpretation for this feature.

## Phase 1 — Design artifacts

### Required artifacts for this feature

- `.specify/specs/010-ui-design-system/plan.md` (this file)
- `.specify/specs/010-ui-design-system/research.md`
- `.specify/specs/010-ui-design-system/data-model.md`
- `.specify/specs/010-ui-design-system/quickstart.md`

### Artifact responsibilities

- **plan.md**: technical context, implementation boundaries, phase gating, and acceptance gates.
- **research.md**: explicit decisions + rationale + alternatives considered.
- **data-model.md**: component/data/state entities and transitions.
- **quickstart.md**: manual pre-implementation validation plan.

### Scope controls

- Do not introduce API contracts, backend surfaces, or new external service behavior.
- Keep changes constrained to:
  - shared component and style definitions,
  - typography registration and usage patterns,
  - splash media fallback behavior.
- Do not add runtime business logic outside UI styling and media/font display support.

## Phase 2 — Readiness and consistency checks

- Confirm all artifact files above exist.
- Confirm no unresolved placeholders (`NEEDS CLARIFICATION`) in generated planning artifacts.
- Confirm scope consistency:
  - each requirement in `.specify/specs/010-ui-design-system/spec.md` maps to at least one design-system artifact element.
  - no other feature files are expanded in scope by this planning stage.
- Re-check artifact naming/location under `.specify/specs/010-ui-design-system/`.

## Acceptance Conditions

- Planning files exist under `.specify/specs/010-ui-design-system`:
  - `plan.md`
  - `research.md`
  - `data-model.md`
  - `quickstart.md`
- All required sections are present and concrete.
- No unresolved `NEEDS CLARIFICATION` markers remain in this feature's generated planning artifacts.
- Scope is explicitly bounded and cannot bleed into runtime protocol/business logic.
- Default governance gates are defined and measurable even without local constitution.

## Constitution Check

- `.specify/memory/constitution.md` is not present.
- Treat default template constitution as placeholder; apply explicit gates below.

### Planned gates (default)

- Security: keep UI components free of raw secrets, secrets are handled by existing persistence layers and not displayed in visual tokens.
- Accessibility: components used for interactive controls must preserve readable labels and sufficient contrast in both light/dark schemes.
- Reliability: older OS fallback paths must not crash and should render deterministic non-glass styles.
- UX consistency: avoid introducing one-off local styles where reusable system components exist.
- Build/readiness: planning artifacts completed before implementation for this feature branch.
- Performance: glass-layer and video initialization usage should not introduce avoidable startup jank in splash-to-main transitions.
- Scope control: no API, onboarding, or storage protocol changes.

## Planned Gates (default gates; no project constitution file found)

- Visual consistency: shared design components should reduce duplicated local style code in touched UI areas.
- Typography safety: fallback fonts remain readable when custom assets are unavailable.
- Font registration safety: duplicate registration or missing-asset loops must stay inert.
- Splash safety: missing media must fail over to non-crash placeholder behavior without blocking launch.
- App restart safety: changes to global appearance and splash behavior do not regress startup or persistent session restore.
- Accessibility: status, control labels, and interaction states remain understandable in color-weak/voiceover paths.