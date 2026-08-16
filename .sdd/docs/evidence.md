# HermesiOS Documentation Evidence Packet

This packet records the structural, functional, and technical evidence gathered
before writing the HermesiOS documentation set. Every significant claim in the
generated docs traces back to graph output, source snippets, or repository files
listed here.

## Project identity

- Canonical git root (verified with `git rev-parse --show-toplevel`):
  `/Volumes/WDBlack4TB/Code/HermesiOS/HermesiOS`.
- Source directories: `HermesiOS/` (iOS/iPadOS client) and
  `HermesHostCompanion/` (macOS helper), plus `HermesiOS.xcodeproj`.
- Git remote: `https://github.com/lad75020/HermesiOS.git`.
- codebase-memory project id: `Volumes-WDBlack4TB-Code-HermesiOS`
  (index status `ready`, 5248 nodes, 16002 edges at documentation time).
- "Hermes" is the user's product name for this codebase; the source tree uses
  the `Hermes` prefix throughout, so documentation keeps the on-disk `Hermes`
  identifiers to match the code.
- Path caveat: the enclosing `/Volumes/WDBlack4TB/Code/HermesiOS` directory and
  the outer `HermesiOS` wrapper alias intermittently to this git root; all
  documentation paths use the verified git root above.

## Graph tools used

- `list_projects`, `index_status`, `get_graph_schema`, `get_architecture`
- `search_graph` (classes, registries, sessions, entry points)
- `query_graph` (Cypher: registries, companion methods)
- `search_code` (endpoints, unauthenticated operations, profile header)
- Direct source reads for authoritative confirmation (see below)

## Source files read directly

- `HermesiOS/HermesiOSApp.swift` (app entry point)
- `HermesiOS/HermesWorkspaceNavigation.swift` (navigation model)
- `HermesiOS/HermesHostEndpoints.swift` (endpoints + transport security)
- `HermesiOS/HermesSettingsPersistence.swift` (settings + Keychain)
- `HermesiOS/HermesResponsesAPI.swift` (Responses API SSE flow, attachments)
- `HermesHostCompanion/CompanionProtocol.swift` (wire protocol)
- `HermesHostCompanion/CompanionServer.swift` (routing/auth/listener)
- `README.md` (existing detailed install/deploy doc, preserved)

## Architecture and runtime layers

- Two Swift targets in one Xcode project (`HermesiOS.xcodeproj`):
  - `HermesiOS` iOS/iPadOS SwiftUI client (1408 graph nodes, core layer).
  - `HermesHostCompanion` macOS menu-bar helper (553 nodes, internal layer).
- Languages: Swift (64 files), YAML (8 files).
- Cross-target boundaries: HermesHostCompanion to HermesiOS 101 calls; reverse
  33 calls (shared protocol/model types).
- Build settings (`project.pbxproj`):
  - `IPHONEOS_DEPLOYMENT_TARGET = 26.4`
  - `MACOSX_DEPLOYMENT_TARGET = 26.0`
  - `SWIFT_VERSION = 5.0`, `MARKETING_VERSION = 1.0`
  - Bundle IDs `fr.dubertrand.HermesiOS`, `fr.dubertrand.HermesHostCompanion`
- App entry: `HermesiOSApp` (`@main`) shows `ContentView`; registers bundled
  fonts; starts `StateServer`/DebugBridge only under `#if DEBUG`.
- Companion server binds the local listener to `127.0.0.1` even when a Tailscale
  hostname is advertised; the Tailscale IPNExtension owns tailnet addresses and
  forwards to loopback (`CompanionServer.start`).

## Main user-facing features (navigation)

`WorkspaceSection` enum (`HermesWorkspaceNavigation.swift`) defines the sidebar:
`responses` (Ask Hermes), `chat` (Chat with Hermes), `tuiGateway` (TUI Gateway),
`approvals` (Approvals Inbox), `history`, `web`, `terminal`, `utilities`,
`settings`, `runtime` (Hermes Agent Runtime). Each carries title, subtitle, and
an SF Symbol. The sidebar tracks API/companion/dashboard channel activity plus
unread completion, unread failure, and streaming attention states.

## HTTP API surface (client to Hermes gateway)

OpenAI-compatible endpoints, base `https://<mac-host>:<api-port>/v1`:

- `POST /v1/responses` (Ask Hermes): SSE (`Accept: text/event-stream`),
  `stream` flag, `previousResponseID` chaining
  (`HermesResponsesAPI.swift` around line 192).
- `POST /v1/chat/completions` (Chat) (`HermesChatCompletionsAPI.swift:150`).
- `GET /v1/profiles` (profiles) (`HermesProfilesPanel.swift:44`).
- Auth header `Authorization: Bearer <token>`; profile header
  `X-Hermes-Profile: <profile>` (`HermesResponsesAPI.swift:200`).

## Companion WebSocket API (client to macOS helper)

- Wire protocol lives in `CompanionProtocol.swift`.
- Envelopes: `CompanionIncomingEnvelope {id?, type, deviceID?, deviceSecret?,
  payload?}` and `CompanionOutgoingEnvelope {id?, ok, payload?, error?}`
  with `.success`/`.error` factories.
- Routing (`CompanionServer.route`): `type` is the operation; the prefix before
  the first `.` selects a registry; `device.checkApproval` and `session.hello`
  are unauthenticated; every other operation requires device auth, otherwise the
  server returns error code `unauthorized`; an unknown prefix returns
  `unknownOperation`.
- Registry prefixes (18): `target, service, git, memory, models, provider,
  profiles, schedule, skills, toolset, mcp, gateway, tailscale, hermes,
  knowledge, log, filedownload, download`.
- Full operation catalog (49 operations, from `case "x.y":` dispatch):
  `device.checkApproval`, `device.enroll`, `session.hello`,
  `target.list/read/validate/write/listBackups/restoreBackup`,
  `service.list/status/start/stop/restart`,
  `git.status/diff/log/commit/push`, `memory.read/write`,
  `models.list/refresh`, `provider.list/setModel`, `profiles.list`,
  `schedule.list`, `skills.list/setState`, `toolset.list/setState`,
  `mcp.list/add/remove`,
  `gateway.config/status/setEnv/setPlatform/restart`,
  `tailscale.serveStatus/serveSet`,
  `hermes.installStatus/installUpdate`,
  `knowledge.status/eraseAll`, `log.tail`,
  `filedownload.info/chunk/browse`, `download.file`.
- 16 registry classes back these operations, one file each under
  `HermesHostCompanion/Companion*Registry.swift`.

## Device onboarding and security model

- QR onboarding: the Mac app shows an onboarding payload (endpoint, code,
  server name, optional config folder, API key) and the enrollment result
  returns a per-device `deviceID`/`deviceSecret`; the iOS app then polls
  `device.checkApproval` for host approval and honors a `revoked` flag.
- Transport security (`HermesEndpointSecurity`): plaintext `http`/`ws` allowed
  only for loopback (`127.*`, `localhost`, `::1`) or Tailscale tailnet hosts
  (`*.ts.net`, `100.64.0.0/10` i.e. octet[0]==100 and 64..127, IPv6 prefix
  `fd7a:115c:a1e0:`); otherwise TLS is required and credentialed sends over
  plaintext throw `HermesEndpointSecurityError.sensitivePlaintextURL`.
- Legacy note: shared API keys, `9212/enroll`, pinned certs are stale; current
  access is QR device onboarding with per-device secrets.

## Configuration and persisted settings

Authoritative source: `HermesSettingsPersistence` enum
(`HermesiOS/HermesSettingsPersistence.swift`). Settings are stored as structured
Codable values in UserDefaults, with secrets in the Keychain.

UserDefaults keys (structured Codable blobs and scalars):

- `hermes.apiSettings` (`HermesAPISettings`: host, ports, model, profile,
  streaming, theme; API key stripped before persist)
- `hermes.responsesDraft`, `hermes.chatDraft` (in-progress prompt drafts)
- `hermes.lastResponsesSessionID` / `...Title`,
  `hermes.lastChatSessionID` / `...Title` (session resume)
- `hermes.companionSettings`, `hermes.companionIdentityState`,
  `hermes.companionConnections`, `hermes.activeCompanionConnectionID`
- `hermes.terminalSettings`

Keychain services and accounts (secrets, never in UserDefaults):

- API bearer token: service `com.hermesios.api`, account `bearerToken`
- Companion device secret: service `com.hermesios.companion`, account
  `deviceSecret` (legacy account `authenticationToken`)
- Terminal SSH private key: service `com.hermesios.terminal`, account
  `sshPrivateKey`

Endpoint constants (`HermesHostEndpoints.swift`) expose default ports: API
`8642`, dashboard `9120` (legacy local `9119`), office `9116`, companion
`9112`, plus `hermes.mac.host`, `hermes.runtime.tab.enabled`,
`hermes.tailscale.serve.selected.port`. The dashboard helper rewrites legacy
port `9119` to `9120` for non-loopback hosts (`remoteDashboardPort`).

## Prompt attachments

`HermesAttachment` supports images (`png,jpg,jpeg,gif,webp`), documents
(`pdf,docx,pptx,xlsx`), and text/source (`txt,text,json,yaml,yml,toml,swift`).
Text/source files are embedded inline in a fenced block; other files are passed
as a `data:<mime>;base64,...` data URL. Unsupported extensions throw
`HermesAttachmentError.unsupportedFileType`.

## Build, install, deployment

See existing `README.md` for the very detailed install/deploy section (ports,
LaunchAgents `ai.hermes.gateway` and `fr.dubertrand.hermes-dashboard-host-proxy`,
Tailscale Serve). Deployment docs derive from README plus the endpoint constants
above and are cross-checked against them.

## Tests, health, observability

- No XCTest/unit-test targets found in the graph (`is_test` false everywhere).
- In-app observability panel, background activity, schedules, approvals inbox,
  and companion `log.tail` provide runtime visibility.
- Debug-only `StateServer`/`DebugBridge` wiring compiles under `#if DEBUG`.

## Evidence gaps and caveats

- The codebase-memory graph's `CompanionProtocol` snippet was stale relative to
  the on-disk file (older `RequestEnvelope` shape vs current
  `CompanionIncomingEnvelope`/`type` shape). On-disk source is authoritative;
  API docs follow the on-disk envelopes and dispatch.
- No `.sdd` API contract files exist, so `api-reference.md` is derived from the
  observed runtime API surface (endpoints plus companion operations) and is
  labeled as observed, not contract-generated.
- No automated test suite is present, so functional confidence markers rely on
  code paths (high) and implementation inference (medium).
- Git status was clean at evidence time (no pre-existing uncommitted changes).
