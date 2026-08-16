# HermesiOS Architecture

HermesiOS is a native SwiftUI companion for a self-hosted Hermes Agent runtime.
It gives an iPhone or iPad a full command center for a Mac-hosted Hermes stack:
chatting with the agent, managing models and providers, driving the gateway,
inspecting skills and tools, monitoring observability, and controlling a paired
macOS host. This document describes the system's structure, runtime topology,
component boundaries, and core control/data flows.

## Targets and layers

The repository builds two Swift targets from one Xcode project
(`HermesiOS.xcodeproj`):

| Target | Platform | Role | Graph nodes | Layer |
| --- | --- | --- | --- | --- |
| `HermesiOS` | iOS/iPadOS | SwiftUI client and command center | 1408 | core |
| `HermesHostCompanion` | macOS | Trusted host helper (menu-bar app) | 553 | internal |

The client holds the user-facing workspaces and all API/WebSocket clients. The
companion performs privileged host operations (service control, git, file I/O,
Hermes install/update) behind an authenticated WebSocket. Cross-target call
boundaries observed in the graph: HermesHostCompanion to HermesiOS 101 calls and
HermesiOS to HermesHostCompanion 33 calls, reflecting shared protocol and model
types rather than a runtime dependency (the two apps run on different devices).

## Runtime topology

HermesiOS does not run Hermes Agent on iOS. It connects to services on the Mac.

```text
iPhone / iPad (HermesiOS)
  |
  |-- HTTPS  --> Hermes API gateway        (Mac, default :8642/v1)
  |-- HTTPS  --> Hermes dashboard proxy    (Mac, default :9120)
  |-- WS/WSS --> HermesHostCompanion       (Mac, default :9112/ws)
  |-- HTTPS  --> Hermes Office / Studio     (Mac, default :9116)

Mac host
  |-- Hermes Agent workspace (normally ~/.hermes/hermes-agent)
  |-- Hermes API gateway LaunchAgent (ai.hermes.gateway)
  |-- Dashboard + host-rewriting proxy (fr.dubertrand.hermes-dashboard-host-proxy)
  |-- HermesHostCompanion macOS app
  |-- Tailscale Serve HTTPS/WSS forwards for physical devices
  |-- Optional Office / Claw3D services
```

For the iOS Simulator, Mac-local loopback endpoints are usually sufficient. A
physical device reaches the Mac through Tailscale Serve or another trusted
HTTPS/WSS path.

## Client structure

The iOS app entry point is `HermesiOSApp` (`@main`), which registers bundled
fonts and, only under `#if DEBUG`, starts a local `StateServer` and installs the
debug UI bridge. It presents `ContentView`, which hosts the workspace sidebar.

Navigation is modeled by the `WorkspaceSection` enum
(`HermesWorkspaceNavigation.swift`):

| Section | Title | Purpose |
| --- | --- | --- |
| `responses` | Ask Hermes | `/v1/responses` with SSE and response chaining |
| `chat` | Chat with Hermes | `/v1/chat/completions`, independent transcript |
| `tuiGateway` | TUI Gateway | Dashboard TUI Gateway WebSocket sessions |
| `approvals` | Approvals Inbox | Approve/deny dangerous-command requests |
| `history` | History | Dashboard-backed request/response history |
| `web` | Web | In-app web page browsing |
| `terminal` | Terminal | SSH terminal to the configured Mac host |
| `utilities` | Utilities | Clipboard history and local helpers |
| `settings` | Settings | Gateway, prompts, models, streaming config |
| `runtime` | Hermes Agent Runtime | Companion-backed runtime panels |

The sidebar surfaces channel activity (API, companion, dashboard) and per-section
attention states: unread completion, unread failure, and streaming/in-progress.

## API clients

The client talks to the Hermes gateway over OpenAI-compatible HTTP:

- `HermesResponsesSession` drives `POST /v1/responses` as a Server-Sent Events
  stream (`Accept: text/event-stream`), honoring a `stream` flag and chaining
  turns with `previousResponseID`.
- `HermesChatCompletionsSession` drives `POST /v1/chat/completions` with an
  independent transcript.
- Profiles are fetched from `GET /v1/profiles`.

All requests carry `Authorization: Bearer <token>` when a token is set and
`X-Hermes-Profile: <profile>` when a profile is selected.

The TUI Gateway workspace connects to the Hermes dashboard WebSocket. Because
dashboard JSON routes require a session token injected into dashboard HTML, the
client first loads the dashboard root, extracts the session token, then calls
dashboard APIs and opens the gateway socket.

## Companion protocol and routing

`HermesHostCompanion` runs an `NWListener`-based WebSocket server
(`CompanionServer`). It binds the actual listener to `127.0.0.1` even when a
Tailscale hostname is advertised; the Tailscale IPNExtension owns tailnet
addresses and forwards to the loopback listener, avoiding a bind conflict with
Tailscale Serve.

Messages are JSON envelopes:

- Request: `CompanionIncomingEnvelope { id?, type, deviceID?, deviceSecret?,
  payload? }`
- Response: `CompanionOutgoingEnvelope { id?, ok, payload?, error? }`

Routing in `CompanionServer.route`:

1. `type` is the operation name (for example `service.restart`).
2. `device.checkApproval` and `session.hello` are unauthenticated; all other
   operations require a valid `deviceID`/`deviceSecret` or the server returns
   error code `unauthorized`.
3. The prefix before the first `.` selects a registry. An unknown prefix returns
   `unknownOperation`.
4. The matched registry handles the operation and returns a payload or error.

Registry prefixes (18) map to `Companion*Registry` handlers: `target`,
`service`, `git`, `memory`, `models`, `provider`, `profiles`, `schedule`,
`skills`, `toolset`, `mcp`, `gateway`, `tailscale`, `hermes`, `knowledge`,
`log`, `filedownload`, `download`. The complete 49-operation catalog is in the
API reference.

## Security boundaries

Transport security is centralized in `HermesEndpointSecurity`
(`HermesHostEndpoints.swift`):

- Plaintext `http`/`ws` is allowed only for loopback hosts (`127.*`,
  `localhost`, `::1`) or Tailscale tailnet hosts (`*.ts.net`, the `100.64/10`
  range, and the `fd7a:115c:a1e0:` IPv6 prefix).
- Any other host must use TLS (`https`/`wss`); a credentialed plaintext send
  throws `HermesEndpointSecurityError.sensitivePlaintextURL`.
- Self-signed trust is likewise limited to loopback/tailnet hosts.

Secrets never live in plaintext defaults: the API bearer token, companion device
secret, and terminal SSH private key are stored in the Keychain (see the
configuration guide). The companion is the sole path for privileged host
mutations; the iOS app does not directly mutate arbitrary macOS files.

## Core control flow: Ask Hermes turn

1. The user composes a prompt (optionally with attachments) in the Ask Hermes
   workspace.
2. `HermesResponsesSession.send` builds `POST <base>/v1/responses` with the
   selected model, bearer token, and profile header, requesting SSE.
3. If streaming is enabled, the response body is consumed incrementally and
   rendered as it arrives; the returned response id is retained as
   `previousResponseID` so the next turn chains onto it.
4. Completion and failure update the sidebar attention state for the workspace.

## Data persistence

User configuration is persisted by `HermesSettingsPersistence` (structured
Codable values in UserDefaults) with secrets in the Keychain. Drafts and last
session identifiers enable prompt draft recovery and session resume. See the
configuration guide for the full key inventory.
