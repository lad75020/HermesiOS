# HermesiOS Functional Requirements

This document captures the functional behavior of HermesiOS extracted from the
implementation. Business rules carry confidence markers:

- HIGH: backed by an explicit code path.
- MEDIUM: inferred from implementation, README, or design notes.

No automated test suite exists, so no rules are marked from tests.

## Functional requirements and user stories

### Ask Hermes (Responses)

- As a user, I can send a prompt to the agent and receive a response.
- As a user, I can stream the response live and continue a multi-turn
  conversation that keeps context.
- As a user, I can attach images, documents, and text/source files to a prompt.
- As a user, my in-progress prompt is preserved as a draft and my last session
  can be resumed.

### Chat with Hermes

- As a user, I can hold a separate chat conversation that is independent from
  Ask Hermes.

### TUI Gateway

- As a user, I can talk to Hermes through the dashboard TUI Gateway and handle
  streamed events, clarifications, approvals, secret prompts, and sudo prompts.
- As a user, I can run multiple TUI workspaces and resume sessions.

### Approvals Inbox

- As a user, I can review pending dangerous-command approvals across sessions
  and profiles and approve or deny each.

### History

- As a user, I can search prior requests and responses grouped by session and
  resume a session.

### Hermes Agent Runtime

- As a user with a paired Mac, I can manage memory, providers, models, profiles,
  the gateway, tools, MCP servers, skills, schedules, observability, allowlisted
  targets, and knowledge erasure remotely.

### Host Companion pairing

- As a user, I can pair my device by scanning a QR code and being approved on
  the Mac, after which my device holds a unique ID and secret.

### Settings and installation

- As a user, I can configure endpoints, credentials, model, profile, streaming,
  and theme, and I can check and update the Hermes installation.

## Business rules and invariants

### Transport security (HIGH)

Plaintext `http`/`ws` is refused unless the host is loopback (`127.*`,
`localhost`, `::1`) or a Tailscale tailnet host (`*.ts.net`, the `100.64.0.0/10`
range where the first octet is 100 and the second is 64 through 127, or the
IPv6 prefix `fd7a:115c:a1e0:`). Any other host requires TLS. A credentialed
plaintext send throws `HermesEndpointSecurityError.sensitivePlaintextURL`.
Source: `HermesEndpointSecurity` in `HermesHostEndpoints.swift`.

### Companion authorization (HIGH)

Only `device.checkApproval` and `session.hello` are unauthenticated. Every other
companion operation requires a valid `deviceID`/`deviceSecret`; otherwise the
server responds with error code `unauthorized`. Source:
`CompanionServer.route` and `CompanionProtocol.isUnauthenticatedOperation`.

### Operation routing (HIGH)

The operation name's prefix before the first `.` selects a registry. An unknown
prefix returns error code `unknownOperation`. Source: `CompanionServer.route`
and `CompanionServer.registryPrefixes`.

### Dashboard port normalization (HIGH)

The legacy dashboard port `9119` is rewritten to `9120` for non-loopback hosts,
so remote devices reach the host-rewriting proxy rather than the raw local
backend. Source: `HermesHostEndpoints.remoteDashboardPort`.

### Attachment validation (HIGH)

Only whitelisted extensions are accepted (`png`, `jpg`, `jpeg`, `gif`, `webp`,
`pdf`, `docx`, `pptx`, `xlsx`, `txt`, `text`, `json`, `yaml`, `yml`, `toml`,
`swift`). Anything else throws `HermesAttachmentError.unsupportedFileType`.
Text/source files are embedded inline in a fenced block; other files are passed
as a `data:<mime>;base64,...` data URL. Source: `HermesAttachment` in
`HermesResponsesAPI.swift`.

### Secret storage (HIGH)

The API bearer token, companion device secret, and terminal SSH private key are
stored in the Keychain, never in UserDefaults. The API key is stripped from the
persisted `HermesAPISettings` blob before saving. Source:
`HermesSettingsPersistence`.

### Companion listener binding (HIGH)

The companion binds its WebSocket listener to `127.0.0.1` even when advertising a
Tailscale hostname; the Tailscale IPNExtension forwards tailnet traffic to the
loopback listener. Binding to all interfaces would conflict with Tailscale
Serve. Source: `CompanionServer.start`.

### Ask Hermes streaming and chaining (MEDIUM)

When streaming is enabled, `/v1/responses` is consumed as SSE and rendered
incrementally; the response id is retained as `previousResponseID` so the next
turn chains onto it. Inferred from `HermesResponsesSession.send`.

### Sidebar attention precedence (MEDIUM)

The TUI Gateway sidebar icon reflects the strongest attention state across TUI
workspaces with precedence red greater than green greater than orange greater
than default (failed, completed, streaming, idle). Inferred from README/DESIGN
notes and the sidebar attention model.

### QR onboarding and approval polling (MEDIUM)

Onboarding presents a QR payload; the device enrolls via `device.enroll` and
polls `device.checkApproval` until the host approves, honoring a `revoked` flag.
Inferred from the onboarding/enrollment payload types and unauthenticated
operations.

### Update stops on conflict (MEDIUM)

Update Hermes fetches official `main`, merges into local `main`, stops on
conflicts without pushing, and pushes only clean merges to the fork. Inferred
from the installation status/update payloads (`pendingUpdateBranch`,
`conflictFiles`, `isUpdateBlocked`) and README.

## Error behavior

| Condition | Surfaced as |
| --- | --- |
| Credentialed plaintext to a disallowed host | `HermesEndpointSecurityError.sensitivePlaintextURL` |
| Unapproved or unauthenticated companion call | error code `unauthorized` |
| Unknown companion operation prefix | error code `unknownOperation` |
| Unsupported attachment type | `HermesAttachmentError.unsupportedFileType` |
| Missing/invalid gateway token | HTTP `401` from the gateway |

## Side effects

- Sending a prompt performs a network call to the gateway and updates the
  workspace attention state on completion or failure.
- Companion operations mutate Mac state (services, git, files, memory, gateway
  config, skills/toolsets, MCP servers, knowledge) and return operation output.
- Pairing writes a device ID and secret to the Keychain.
