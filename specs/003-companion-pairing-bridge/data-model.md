# Data Model: Host Companion Pairing Bridge

## Companion Device

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## Pairing Request

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## WebSocket Envelope

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.

## Authorized Session

**Fields**:
- `id`: Stable identity.
- `displayState`: User-visible state.
- `source`: Scoped feature source or host-backed origin.

**Validation Rules**:
- State is clear, non-secret, and recoverable.
- Invalid or unavailable backing data produces an actionable user-visible state.
