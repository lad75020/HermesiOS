# Data Model: App Shell and Design System

## Workspace Section

Represents one top-level destination reachable from the app shell.

**Fields**:
- `id`: Stable section identity used for selection and state preservation.
- `displayName`: Localized label shown to the user.
- `icon`: Visual symbol or asset used in navigation.
- `selectionState`: Whether the section is currently selected.
- `attentionState`: Optional status indicator such as default, active, completed, failed, or unread.
- `destination`: The shell panel or content area reached by selecting the section.

**Validation Rules**:
- Every visible workspace section has a stable identity, display label, and destination.
- Only one primary section is selected at a time.
- Attention state does not obscure selection state.

## Theme Preference

Represents the user's selected or inherited appearance behavior.

**Fields**:
- `mode`: System, light, dark, or another supported app-level mode.
- `effectiveAppearance`: The appearance currently applied after resolving system settings.
- `contrastBehavior`: Expected readability behavior for shared surfaces.

**Validation Rules**:
- Primary navigation and shared status surfaces remain legible in every supported mode.
- Brand assets retain recognizable contrast in supported appearances.

## Shared Visual Component

Represents a reusable shell-level presentation element.

**Fields**:
- `componentType`: Header, card, status row, status pill, message surface, navigation icon, or marquee text.
- `contentRole`: Navigation, status, informational, action, or message content.
- `visualState`: Default, selected, disabled, loading, success, warning, failure, or attention.
- `accessibilityLabel`: User-facing label or semantic description when needed.

**Validation Rules**:
- Reused components keep consistent spacing, typography, hierarchy, and state meaning across representative panels.
- Long content is truncated, wrapped, or animated intentionally without breaking layout.

## Brand Asset

Represents static or media resources used to identify the app and support launch or shell presentation.

**Fields**:
- `assetName`: Resource identifier or file name.
- `assetRole`: App icon, logo, splash media, font, accent color, or visual resource.
- `appearanceVariant`: Light, dark, universal, or fallback.
- `bundleLocation`: Resource bundle path.

**Validation Rules**:
- Required launch and shell assets are included in the app bundle.
- Missing optional media does not block reaching the shell.
- Fonts or typography helpers have a readable fallback.

## Localized String

Represents user-facing shell or app metadata copy in supported languages.

**Fields**:
- `key`: Stable localization key or metadata string.
- `locale`: Supported locale identifier.
- `value`: Translated text.
- `usageContext`: Navigation label, app metadata, status text, header, or shared surface.

**Validation Rules**:
- Shell-level labels and metadata use available localized values for supported languages.
- Missing translations fall back to understandable default text rather than empty labels.
