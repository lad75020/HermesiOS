# Feature Specification: App Shell and Design System

**Feature Branch**: `feature/time-machine-app-shell-design`

**Created**: 2026-06-21

**Status**: Draft

**Input**: User description: "Feature: App Shell and Design System. Description: Provides the HermesiOS application entry point, workspace navigation, shared visual components, themed branding, localization, fonts, and launch experience. Relevant files: HermesiOS/HermesiOSApp.swift, HermesiOS/ContentView.swift, HermesiOS/HermesWorkspaceNavigation.swift, HermesiOS/HermesSharedViews.swift, HermesiOS/HermesDesignSystem.swift, HermesiOS/HermesAppTheme.swift, HermesiOS/HermesWebsiteTypography.swift, HermesiOS/HermesSplashView.swift, HermesiOS/HermesBackgroundActivity.swift, HermesiOS/Assets.xcassets/, HermesiOS/Resources/, HermesiOS/Fonts/, HermesiOS/Localizable.xcstrings, HermesiOS/*/InfoPlist.strings, HermesiOS/Info.plist, HermesiOS/HermesiOS.entitlements, HermesiOS/HermesiOSRelease.entitlements. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a Coherent Companion Workspace (Priority: P1)

As a HermesiOS user, I want the app to launch into a stable, recognizable workspace shell so that I can quickly reach the Hermes companion tools without confusion.

**Why this priority**: The app shell is the entry point for every other feature. If launch, navigation, or high-level layout fails, no downstream Hermes capability is discoverable or usable.

**Independent Test**: Install and open the app, then verify that the launch experience completes, the primary workspace shell appears, and the main navigation choices are visible without requiring any host connection.

**Acceptance Scenarios**:

1. **Given** the user opens HermesiOS for the first time, **When** the launch sequence completes, **Then** the app presents a branded workspace shell with a clear primary navigation area and content area.
2. **Given** the user is in the workspace shell, **When** they select each available workspace section, **Then** the selected section is visibly highlighted and the corresponding panel area changes consistently.
3. **Given** host services are unreachable, **When** the user opens the app shell, **Then** navigation and static visual structure remain usable while service-dependent panels can report their own unavailable state.

---

### User Story 2 - Navigate with Consistent Visual Hierarchy (Priority: P2)

As a frequent user, I want sidebar icons, headers, cards, status rows, and message surfaces to follow a consistent visual hierarchy so that I can distinguish navigation, status, content, and actions at a glance.

**Why this priority**: Consistent shared components reduce cognitive load and prevent every workspace from inventing different patterns for the same concepts.

**Independent Test**: Review the workspace shell and at least three distinct panels that use shared visual elements, then verify that spacing, typography, card treatment, status indicators, and selected states remain consistent.

**Acceptance Scenarios**:

1. **Given** multiple panels use shared cards and headers, **When** the user moves between panels, **Then** the visual hierarchy remains recognizable and controls are grouped consistently.
2. **Given** a navigation item has status or attention state, **When** that state changes, **Then** the user can identify the state without losing the selected navigation context.
3. **Given** text content is longer than its available space, **When** it appears in constrained navigation or status areas, **Then** the UI preserves readability through an intentional truncation or marquee behavior.

---

### User Story 3 - Personalize and Localize the Shell (Priority: P3)

As a user in a supported language or theme preference, I want the app shell to respect localization, app metadata, branding assets, and theme choices so that HermesiOS feels native and personal on my device.

**Why this priority**: Localization and theme polish improve trust and usability, but depend on the foundational shell and shared components already being stable.

**Independent Test**: Change device language and app theme-related settings, then verify that app metadata, navigation labels, branding, and major shared text surfaces remain understandable and visually coherent.

**Acceptance Scenarios**:

1. **Given** the device uses a supported localization, **When** the app shell and app metadata are shown, **Then** user-facing labels and metadata appear in the expected language where translations exist.
2. **Given** the user changes between supported appearance modes, **When** the shell re-renders, **Then** the brand assets, contrast, and shared surfaces remain legible.
3. **Given** app branding assets are displayed during launch or within the shell, **When** the system appearance changes, **Then** the app uses an appropriate asset variant or presentation that preserves brand recognition.

---

### Edge Cases

- The app shell must remain navigable when Hermes host services, gateway status, or companion pairing are unavailable.
- The app shell must tolerate missing or delayed media playback during splash or launch and still reach the main workspace.
- Long workspace names, localized strings, or status text must not break the sidebar or primary content layout.
- Theme changes, dynamic type changes, and accessibility contrast settings must not make essential navigation or status controls unreadable.
- Asset or font fallback behavior must keep the app usable if an optional visual resource is unavailable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a single application entry point that initializes the root workspace shell and makes primary HermesiOS sections reachable.
- **FR-002**: The system MUST present a primary navigation structure that lists all configured workspace sections with clear selected, default, and attention states.
- **FR-003**: Users MUST be able to switch between workspace sections without restarting the app or losing the shell layout.
- **FR-004**: The system MUST provide reusable shared visual patterns for hero cards, section headers, cards, status rows, status pills, chat message surfaces, and similar common shell elements.
- **FR-005**: The system MUST provide a consistent design language for colors, glass-like surfaces, gradients, spacing, typography, and icon treatments across shell-level views.
- **FR-006**: The system MUST provide a launch or splash experience that transitions into the main workspace without blocking access indefinitely.
- **FR-007**: The system MUST support localized user-facing app metadata and shell labels for the supported language set present in the project.
- **FR-008**: The system MUST support theme and appearance choices that keep navigation, content surfaces, and brand assets legible in supported appearances.
- **FR-009**: The system MUST preserve shell usability when dependent services are offline, leaving service-specific failures to their own panels or status views.
- **FR-010**: The system MUST include the app assets, fonts, launch media, entitlements, and metadata required for the shell and branding experience to run on supported devices.
- **FR-011**: The system MUST expose background activity behavior only in ways that are visible, bounded, and understandable from the user-facing app experience.

### Key Entities *(include if feature involves data)*

- **Workspace Section**: A top-level destination in the app shell with a label, icon, selection state, and optional attention/status presentation.
- **Theme Preference**: The user's selected or inherited appearance mode that influences shell colors, contrast, and visual assets.
- **Shared Visual Component**: A reusable presentation pattern such as a card, header, status pill, message card, or navigation element used by multiple panels.
- **Brand Asset**: Images, fonts, icons, launch media, and related metadata that define the app's recognizable identity.
- **Localized String**: User-facing text mapped to supported languages for app metadata, navigation, labels, and shared surfaces.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can open the app and reach the primary workspace shell in under 5 seconds on a normally responsive supported device.
- **SC-002**: A user can switch between any two primary workspace sections in under 2 seconds without the shell losing selection state.
- **SC-003**: At least 95% of shell-level user-facing labels visible in the primary navigation and app metadata appear localized when the device uses a supported localization.
- **SC-004**: All primary navigation labels, selected states, and shared status surfaces remain readable in supported light, dark, and system appearance modes.
- **SC-005**: The app shell remains available for navigation in 100% of tested offline-host scenarios where Hermes services are unreachable at launch.
- **SC-006**: Shared shell components produce visually consistent spacing, typography, and status treatment across at least three independently selected workspace panels.

## Assumptions

- HermesiOS is a native companion app whose shell must be useful even before a host connection succeeds.
- Service-specific panels may own detailed error messages, but the shell owns navigation, presentation consistency, and discoverability.
- The supported localization set is the set already represented by the project's localization resources.
- Theme support includes system appearance plus any app-level theme choice already exposed to users.
- This feature scopes app shell, design, launch, branding, localization, and shared view behavior only; individual Hermes service workflows remain separate Time Machine features.
