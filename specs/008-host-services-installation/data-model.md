# Data Model: Host Services and Installation

## Managed Service

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## Log Request

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## Tailscale Serve Rule

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## Git Update Operation

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.
