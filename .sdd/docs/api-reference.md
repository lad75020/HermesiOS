# HermesiOS API Reference (Observed)

This reference documents the API surfaces HermesiOS consumes. It is an OBSERVED
reference derived from the client and companion source code, not generated from
formal contract files (none exist in `.sdd`). Request and response shapes
describe what the app sends and expects; the authoritative gateway contract is
owned by the Hermes Agent backend.

There are two surfaces:

1. OpenAI-compatible HTTP to the Hermes gateway.
2. The Host Companion WebSocket JSON envelope API.

## 1. Hermes gateway (HTTP)

Base URL: `https://<mac-host>:<api-port>/v1` (default api-port `8642`).

Common headers:

- `Authorization: Bearer <token>` when an API bearer token is configured.
- `X-Hermes-Profile: <profile>` when a profile is selected.
- `Content-Type: application/json` for request bodies.

### POST /v1/responses (Ask Hermes)

Streams a response with Server-Sent Events.

- Request header `Accept: text/event-stream`.
- Request body fields: `model`, `input`, `stream` (bool), `previousResponseID`
  (nullable, used to chain turns onto a prior response).
- Response: an SSE event stream when `stream` is true; the client renders text
  incrementally and retains the response id to chain the next turn.

### POST /v1/chat/completions (Chat)

OpenAI-style chat completion with an independent transcript. Sends the chat
messages and model; supports streaming analogously to the responses endpoint.

### GET /v1/profiles

Returns the list of available Hermes profiles. The selected profile is sent as
`X-Hermes-Profile` on subsequent gateway calls.

## 2. Host Companion (WebSocket)

The companion server (`CompanionServer`) accepts JSON envelopes over an
authenticated WebSocket (default `ws://<mac-host>:9112/ws`, TLS/WSS required for
non-loopback, non-tailnet hosts).

### Envelopes

Request (`CompanionIncomingEnvelope`):

```json
{ "id": "<uuid>", "type": "<operation>", "deviceID": "<id>", "deviceSecret": "<secret>", "payload": { } }
```

Response (`CompanionOutgoingEnvelope`):

```json
{ "id": "<uuid>", "ok": true, "payload": { }, "error": null }
```

On failure, `ok` is false and `error` is `{ "code": "...", "message": "..." }`.

### Authentication and routing

- `type` is the operation name (for example `service.restart`).
- `device.checkApproval` and `session.hello` are unauthenticated. All other
  operations require a valid `deviceID`/`deviceSecret`; otherwise the response
  carries error code `unauthorized`.
- The prefix before the first `.` selects a registry. An unknown prefix returns
  error code `unknownOperation`.

### Operation catalog

The companion exposes 49 operations across 18 registry prefixes.

| Prefix | Operations |
| --- | --- |
| device | `device.checkApproval`, `device.enroll` |
| session | `session.hello` |
| target | `target.list`, `target.read`, `target.validate`, `target.write`, `target.listBackups`, `target.restoreBackup` |
| service | `service.list`, `service.status`, `service.start`, `service.stop`, `service.restart` |
| git | `git.status`, `git.diff`, `git.log`, `git.commit`, `git.push` |
| memory | `memory.read`, `memory.write` |
| models | `models.list`, `models.refresh` |
| provider | `provider.list`, `provider.setModel` |
| profiles | `profiles.list` |
| schedule | `schedule.list` |
| skills | `skills.list`, `skills.setState` |
| toolset | `toolset.list`, `toolset.setState` |
| mcp | `mcp.list`, `mcp.add`, `mcp.remove` |
| gateway | `gateway.config`, `gateway.status`, `gateway.setEnv`, `gateway.setPlatform`, `gateway.restart` |
| tailscale | `tailscale.serveStatus`, `tailscale.serveSet` |
| hermes | `hermes.installStatus`, `hermes.installUpdate` |
| knowledge | `knowledge.status`, `knowledge.eraseAll` |
| log | `log.tail` |
| filedownload | `filedownload.info`, `filedownload.chunk`, `filedownload.browse` |
| download | `download.file` |

### Representative payloads

Payload structs are defined in `CompanionProtocol.swift`. Examples:

- `device.enroll` payload `{ code, deviceName }` returns
  `{ deviceID, deviceSecret, deviceName, serverEndpoint, approved, message }`.
- `device.checkApproval` payload `{ deviceID, deviceSecret }` returns
  `{ deviceID, approved, revoked, message }`.
- `service.restart` payload `{ serviceID }` returns
  `{ serviceID, status, output }`.
- `hermes.installStatus` returns branch/commit fields plus `behindBy`,
  `conflictFiles`, and `pendingUpdateBranch` (blocks further updates when set).
- `filedownload.chunk` streams file bytes as base64 in bounded chunks with
  `offset`, `totalByteCount`, and `isComplete`.

### Error codes

| Code | Meaning |
| --- | --- |
| `unauthorized` | Device not approved or missing/invalid credentials |
| `unknownOperation` | No registry matches the operation prefix |

Registry handlers may return additional operation-specific error codes in the
`error.message` field.
