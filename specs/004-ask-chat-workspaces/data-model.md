# Data Model: Ask and Chat Workspaces

## Responses Workspace

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## Chat Session

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## Prompt Attachment

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## Approval Item

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.
