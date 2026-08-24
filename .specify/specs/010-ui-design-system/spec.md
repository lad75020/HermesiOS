# Specification: UI Design System

Feature ID: `ui-design-system`

**Status**: Refined

**Refined**: 2026-08-24 — Removed the Ask Hermes and Chat with Hermes entries and their menu icons from primary iPhone navigation.

## Summary

The UI Design System feature defines a shared visual foundation for the iOS app, including consistent tokenized colors, typography, glass surfaces, reusable component primitives, startup branding, and intentional primary-navigation presentation. The goal is to make every target screen use a common language for appearance, spacing, and interaction behavior while preserving graceful fallback behavior on older OS versions.

## User Stories

- As a user, I can see a branded splash experience before the main app interface appears.
- As a user, I can recognize a consistent visual style (colors, surfaces, spacing, and button behaviors) across screens.
- As a user, I can read key labels and controls clearly in both light and dark appearances.
- As a user, I can sense when controls are available and when they are in-progress state during busy interactions.
- As a user, I can access the app on older iOS versions without losing core visual structure.
- As a user, I do not see Ask Hermes or Chat with Hermes as primary iPhone tabs or as their associated menu icons.

## User Scenarios & Testing

### Scenario 1: App launch and onboarding transition
1. User opens the app.
2. A branded splash sequence is shown first, centered on full-screen playback or equivalent fallback.
3. After launch warm-up, user transitions to the normal app layout automatically.
4. User can continue normal workflows without manual dismissal of the splash path.

### Scenario 2: Visual consistency across runtime sections
1. User opens the main app and browses multiple sections that rely on reusable components (status surfaces, cards, pills, and section headers).
2. Each area should use a shared look-and-feel for emphasis, spacing, typography, and status states.
3. User can quickly identify actionable rows and status signals without learning each screen independently.

### Scenario 3: Font and branding continuity
1. User enters a section with both headline and body text.
2. Brand and section typographic styles are applied consistently.
3. If a custom web brand font is unavailable, the text still renders predictably with a safe fallback.

### Scenario 4: Interaction and accessibility behavior
1. User toggles or presses controls built with shared components (buttons, toggles, rows, inputs).
2. Controls provide clear visual feedback for press/loading state and clearly communicated on/off states.
3. Accessibility readers can announce interactive elements and status changes reliably.

### Scenario 5: Visual robustness and system compatibility
1. User switches appearance settings and returns to app.
2. Surfaces and contrast remain usable in light and dark appearance modes.
3. On unsupported OS/device capability for the advanced glass API, the app remains stable and readable using an equivalent material-based fallback.

### Scenario 6: Curated primary iPhone navigation
1. User opens the app on an iPhone-sized layout.
2. The primary tab bar does not display Ask Hermes or Chat with Hermes entries.
3. The dot-radiowaves and text-bubble icons formerly associated with those entries are not displayed in primary navigation.
4. The selected navigation state always resolves to a remaining supported destination.

## Functional Requirements

- The design system shall define reusable color tokens for canvas, surfaces, dividers, secondary text, links, status, and brand accents.
- The design system shall include reusable gradients and visual utilities for primary brand accents and story-like decorative surfaces.
- The design system shall provide a compatibility wrapper for the glass effect API that provides a modern look where supported and a stable fallback where unavailable.
- Shared component styles (cards, pill indicators, section headers, list rows, buttons, icon buttons, chat bubbles, status badges, and input style modifiers) shall be defined centrally and reused by major screens.
- The design system shall provide a consistent way to apply liquid-glass-like surfaces, motion-compatible press feedback, and reusable component shapes.
- The runtime component library (panels, rows, and configuration shells) in scope for this feature shall provide a unified behavior pattern for headers, expand/collapse state, status badges, and inline toggle actions.
- The typography module shall register bundled fonts at app startup and expose helper styles for titles, labels, mono/technical text, and sections.
- Typography helpers shall gracefully fallback when custom webfonts are not available.
- The splash system shall play the configured branded media when available, loop/pause behavior aligned to launch flow expectations, and stop cleanly when leaving the splash route.
- The design system shall expose reusable methods to standardize button prominence hierarchy, input fields, and list surfaces.
- Design tokens and styles shall be designed to preserve visual clarity at multiple sizes and text scales.
- All style changes required for this feature shall be scoped to the shared UI asset files and consumed across existing affected screens rather than duplicating styling logic.
- The primary iPhone tab bar shall not present Ask Hermes or Chat with Hermes destinations.
- The primary iPhone navigation shall not present the dot-radiowaves or text-bubble icons that identified the removed Ask Hermes and Chat with Hermes destinations.
- Navigation actions, restoration, and automatic transitions that previously selected a removed destination shall resolve to a remaining supported destination without a blank or invalid tab state.
- This refinement shall not remove the underlying response or chat client capabilities, configuration controls, or non-navigation UI components unless separately specified.

## Success Criteria

- 95% of major navigable sections use shared design-system components instead of local, custom one-off visual styling.
- App launch transition from splash to main UI is perceived as smooth in user smoke tests and completes within 4 seconds in normal startup conditions.
- In light mode and dark mode, users report readable contrast for text and status surfaces in visual regression checks.
- New or updated UI interactions using shared components show consistent press/loading behavior with no visible regressions in repeated toggles.
- On unsupported system versions, the app remains usable and visually coherent without crashes or blank states for splash, surfaces, and major controls.
- At least 90% of tested screens pass manual accessibility smoke checks for labels, role clarity, and focus feedback on interactive elements using shared controls.
- iPhone navigation smoke tests show no Ask Hermes or Chat with Hermes tab labels and no associated dot-radiowaves or text-bubble tab icons, while all displayed destinations remain selectable.

## Files in Scope

- `HermesiOS/HermesDesignSystem.swift`
- `HermesiOS/HermesRuntimeComponents.swift`
- `HermesiOS/HermesWebsiteTypography.swift`
- `HermesiOS/HermesSplashView.swift`
- `HermesiOS/ContentView.swift`

## Assumptions

- Branded media and font assets are included in the app bundle and named consistently for lookup.
- The app primarily targets modern iOS versions while still supporting an older fallback behavior for visual effects.
- Shared components defined here are used as the baseline for new UI work in runtime, settings, and status flows.
- Users expect the splash sequence to be short and non-blocking.
- The change is limited to primary iPhone navigation presentation; response and chat capabilities remain available to code and non-navigation surfaces unless a future requirement removes them.

## Edge Cases

- Missing or unavailable splash media.
- Missing, partially installed, or corrupted custom font files.
- Appearance mode switches while app is active.
- Large dynamic type and reduced-motion accessibility settings.
- Older devices without glass-effect APIs.
- Temporary rendering pressure during app warm-up and route transitions.
- Duplicate font registration attempts during repeated app launches.
- In-flight launch path interrupted by backgrounding or app interruption.
- A persisted, restored, or programmatically requested navigation selection that references Ask Hermes or Chat with Hermes after their tabs are removed.

## Key Entities

- `Design tokens`: centralized color, gradient, and status style primitives.
- `Glass surface helpers`: wrappers and fallbacks for glass-like cards and backgrounds.
- `Reusable component primitives`: shared cards, pills, headers, rows, buttons, and toggles.
- `Typography set`: registered custom fonts with role-based helper styles.
- `Runtime component shell`: reusable accordions and rows used by runtime settings workflows.
- `Splash screen`: branded app entry route with safe fallback when media cannot be played.
- `Primary iPhone navigation`: the supported tab destinations and their visible labels/icons for compact layouts.