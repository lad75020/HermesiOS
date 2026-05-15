# HermesiOS

HermesiOS is a SwiftUI iOS/iPadOS companion for Laurent's Hermes Agent setup. It provides mobile access to Ask Hermes, Chat with Hermes, dashboard history search, host-side Hermes runtime settings, macOS service controls, and the Hermes Office / Claw3D web experience.

The repository contains two apps:

- `HermesiOS/`: the iOS/iPadOS client.
- `HermesHostCompanion/`: the macOS helper that performs trusted host operations over an authenticated WebSocket.

Host file edits, service controls, git operations, and secret-aware configuration changes should go through HermesHostCompanion. The iOS app should not directly mutate arbitrary macOS files.

## Features

- Ask Hermes via `/v1/responses`, with up to four parallel independent screens.
- Chat with Hermes via `/v1/chat/completions`.
- Profile selection through `GET /v1/profiles` and `X-Hermes-Profile`.
- Prompt attachments for images, documents, text, and source files.
- Dashboard-backed history search and session resume actions.
- Agent Runtime panels for memory, providers, models, profiles, gateway/messaging, tools, MCP servers, skills, schedules, observability, allowlisted targets, and knowledge erasure.
- Settings for the Hermes API bearer token, Host Companion endpoint/API key, macOS service controls, Hermes installation status/update, and theme; API/Dashboard/Office ports are defined in HermesHostCompanion and fetched by HermesiOS.
- Office tab with a persisted Claw3D WebView On/Off switch.
- iPad sidebar status/completion indicators and app-wide API/Mac/Dashboard health LEDs.

## Installation and deployment

This section is intentionally detailed. HermesiOS is only fully functional when the iOS app, Hermes Agent, the Hermes API server, the dashboard, HermesHostCompanion, Tailscale Serve, and the Office/Claw3D bridge are all configured consistently.

### 1. Prerequisites

On the Mac host:

1. Install Xcode and open this project once so signing and simulator runtimes are available.
2. Install Homebrew, Node.js, npm, Python 3.11, Git, and Tailscale.
3. Install and configure Hermes Agent using the official quickstart:
   https://hermes-agent.nousresearch.com/docs/getting-started/quickstart
4. Install Hermes Agent in the expected workspace, normally `~/.hermes/hermes-agent`.
5. Run the Hermes setup wizard and configure at least one provider/model:
   `hermes setup`
6. Verify Hermes itself:
   `hermes doctor`
   `hermes status --all`
7. Make sure the Mac and the iPhone/iPad are on the same Tailscale tailnet.

### 2. Required local services and ports

The current app expects these services to exist on the Mac host. The Mac hostname and Host Companion WebSocket port/API key are configured in HermesiOS Settings; the API gateway, Dashboard, and Office TCP ports are configured in HermesHostCompanion and fetched by HermesiOS after Host Companion verification.

| Purpose | Local endpoint | Tailscale endpoint used by iOS | Required for |
| --- | --- | --- | --- |
| Hermes API server | `http://127.0.0.1:8642/v1` | `https://mac-studio.tail4d2ab4.ts.net:8642/v1` | Ask Hermes, Chat, profiles, status LED |
| Hermes dashboard | `http://127.0.0.1:9119` | `https://mac-studio.tail4d2ab4.ts.net:9119` | History/search/session resume |
| Dashboard host-rewriting proxy | `http://127.0.0.1:9120` | exposed as dashboard `:9119` | Tailscale dashboard access without Host-header errors |
| Hermes Office / Studio | `http://127.0.0.1:9116` | `https://mac-studio.tail4d2ab4.ts.net:9116` | Office tab and Claw3D WebView |
| HermesHostCompanion WebSocket | `ws://127.0.0.1:9312/ws` in Laurent's current setup; code default is `ws://127.0.0.1:9112/ws` | `wss://mac-studio.tail4d2ab4.ts.net:9312/ws` | Agent Runtime, Settings service controls, Hermes installation controls |
| Claw3D Hermes adapter | `ws://127.0.0.1:18790` | proxied through Office at `:9116/api/gateway/ws` | Claw3D/OpenClaw bridge |
| OpenClaw gateway | `ws://127.0.0.1:18789` | optional root Tailscale Serve endpoint | OpenClaw gateway compatibility |

Open or serve these TCP ports through Tailscale for full iOS functionality. Keep `8642`, `9119`/proxy `9120`, and `9116` in sync with the Hermes Service Ports section in HermesHostCompanion; do not enter those ports or derived service URLs in HermesiOS Settings anymore.

- `8642`: Hermes OpenAI-compatible API server.
- `9119`: public dashboard URL, forwarded to the local host-rewriting proxy on `127.0.0.1:9120`.
- `9116`: Hermes Office / Studio web app.
- `9312`: HermesHostCompanion WebSocket API in Laurent's current deployment.
- Optional: `9120` if you want direct access to the dashboard proxy for debugging.
- Optional: root HTTPS/443 or the OpenClaw gateway endpoint if you use OpenClaw directly from other devices.

Legacy note: older Host Companion builds used `9112` for API and `9212` for enrollment. Current Host Companion authentication is a single 256-character API key over plain WebSocket behind Tailscale Serve; no TLS certificates, QR enrollment, pairing IDs, or enrollment port should be needed.

### 3. Hermes Agent API server and gateway

HermesiOS talks to Hermes through the gateway's API Server platform.

1. Configure Hermes Agent:
   `hermes setup`
2. Enable/configure the API Server platform:
   `hermes gateway setup`
3. Set an API key in `~/.hermes/.env` if the API server binds beyond loopback. The iOS app must use the same value in Settings → Gateway → Bearer token.
4. Install and start the macOS LaunchAgent:
   `hermes gateway install`
   `hermes gateway start`
5. Verify the service:
   `hermes gateway status`
   `lsof -nP -iTCP:8642 -sTCP:LISTEN`
6. Verify from the Mac:
   `curl -i http://127.0.0.1:8642/v1/models`
   A `401 Invalid API key` still proves the route is reachable; a `200` requires the configured bearer token.

LaunchAgent:

- Label: `ai.hermes.gateway`
- Plist: `~/Library/LaunchAgents/ai.hermes.gateway.plist`
- Logs: `~/.hermes/logs/gateway.log` and `~/.hermes/logs/gateway.error.log`
- Program: `~/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run --replace`

In HermesHostCompanion, set the API gateway service port to the API Server port, usually `8642`. HermesiOS fetches this port from Host Companion and derives the API base URL as `https://<Mac host>:<API port>/v1`; the base URL is no longer typed in HermesiOS Settings.

In HermesiOS Settings, only configure the Gateway bearer token: the value of `API_SERVER_KEY`, if configured.

### 4. Tailscale Serve

Tailscale Serve must forward the Mac's tailnet HTTPS endpoints to the local services.

Typical commands:

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 8642 http://127.0.0.1:8642
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9116 http://127.0.0.1:9116
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9119 http://127.0.0.1:9120
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9312 http://127.0.0.1:9312
```

Optional debug route:

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9120 http://127.0.0.1:9120
```

Verify:

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
lsof -nP -iTCP:8642 -iTCP:9116 -iTCP:9119 -iTCP:9120 -iTCP:9312 -sTCP:LISTEN
```

Expected important routes:

- `https://mac-studio.tail4d2ab4.ts.net:8642` → `http://127.0.0.1:8642`
- `https://mac-studio.tail4d2ab4.ts.net:9116` → `http://127.0.0.1:9116`
- `https://mac-studio.tail4d2ab4.ts.net:9119` → `http://127.0.0.1:9120`
- `https://mac-studio.tail4d2ab4.ts.net:9312` → `http://127.0.0.1:9312`

If the app gets `502` from a Tailscale URL, the local backend is not reachable from Tailscale Serve. If `/v1/models` returns `401`, the network path is working and authentication is the remaining issue.

### 5. Hermes dashboard and dashboard proxy

History search uses the Hermes dashboard server, not the OpenAI-compatible API server. Dashboard `/api/*` routes require the session token injected into the dashboard HTML; the iOS app fetches `/`, extracts `window.__HERMES_SESSION_TOKEN__`, then calls the JSON search endpoint.

Required pieces:

1. Start the Hermes dashboard locally on `127.0.0.1:9119`:
   `~/.hermes/hermes-agent/venv/bin/python3 ~/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open`
2. Start the host-rewriting proxy on `127.0.0.1:9120` so Tailscale dashboard requests do not fail Host-header validation:
   `~/.hermes/hermes-agent/venv/bin/python3 ~/.hermes/scripts/hermes_dashboard_host_proxy.py`
3. Prefer the LaunchAgent below for persistence instead of leaving those commands in a terminal.
4. Forward Tailscale `:9119` to `http://127.0.0.1:9120`.
5. Set the Dashboard service port in HermesHostCompanion to the public dashboard port, usually `9119`. HermesiOS derives the dashboard URL as `https://<Mac host>:<Dashboard port>`; the dashboard URL is no longer typed in HermesiOS Settings.

LaunchAgent for the proxy:

- Label: `fr.dubertrand.hermes-dashboard-host-proxy`
- Plist: `~/Library/LaunchAgents/fr.dubertrand.hermes-dashboard-host-proxy.plist`
- Script: `~/.hermes/scripts/hermes_dashboard_host_proxy.py`
- Local proxy: `127.0.0.1:9120`
- Local dashboard backend: `127.0.0.1:9119`
- Logs: `~/.hermes/logs/hermes-dashboard-host-proxy.log` and `~/.hermes/logs/hermes-dashboard-host-proxy.err.log`

Verify:

```sh
launchctl print gui/$(id -u)/fr.dubertrand.hermes-dashboard-host-proxy
lsof -nP -iTCP:9119 -iTCP:9120 -sTCP:LISTEN
curl -I http://127.0.0.1:9120/
curl -I https://mac-studio.tail4d2ab4.ts.net:9119/
```

### 6. HermesHostCompanion for host operations

HermesHostCompanion is required for Agent Runtime panels, macOS service controls, allowlisted file edits, Hermes installation status/update, and host log access.

1. In Xcode, build the `HermesHostCompanion` scheme.
2. Launch the built macOS app.
3. In the Host Companion window, set the Network Target:
   - Advertised host: `mac-studio.tail4d2ab4.ts.net` for physical devices, or `127.0.0.1` for simulator-only use.
   - API port: `9312` for Laurent's current Tailscale setup, unless you intentionally use the code default `9112` locally.
4. Click Apply Network Target.
5. In Hermes Service Ports, set the TCP ports for the services HermesiOS should use:
   - API gateway: usually `8642`.
   - Hermes Dashboard: usually `9119` when Tailscale forwards it to the local dashboard proxy on `9120`.
   - Hermes Office: usually `9116`.
6. Click Save Service Ports. These values are now the source of truth for HermesiOS service URLs.
7. Start or restart the server.
8. Copy the displayed API URL into HermesiOS Settings → Host Companion.
9. Copy the displayed 256-character API key into HermesiOS Settings → Host Companion.
10. Tap Verify API Key in HermesiOS. After verification, HermesiOS fetches the API gateway, Dashboard, and Office ports from Host Companion and rebuilds its service URLs automatically.
11. Do not paste the API key into logs, README files, screenshots, or commits.

Expected URLs:

- Simulator/local: `ws://127.0.0.1:9312/ws` or `ws://127.0.0.1:9112/ws`, depending on the configured port.
- Physical device through Tailscale: `wss://mac-studio.tail4d2ab4.ts.net:9312/ws`.

Verify on the Mac:

```sh
lsof -nP -iTCP:9312 -sTCP:LISTEN
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status | grep 9312
```

Host Companion currently uses API-key authentication only. If an old README, setting, or QR code mentions `wss://...:9113/enroll`, `9212/enroll`, pinned certificates, fingerprints, CAs, or enrollment IDs, treat it as stale and replace it with the WebSocket URL plus API key flow.

### 7. macOS services managed from HermesiOS Settings

The Settings tab can query/start/stop/restart these allowlisted services through Host Companion:

| Service ID | Display name | Control method |
| --- | --- | --- |
| `hermesd` | Hermes Gateway / API Server | `hermes gateway status/start/stop/restart` |
| `hermes-dashboard` | Hermes Dashboard | LaunchAgent `fr.dubertrand.hermes-dashboard-host-proxy` |
| `claw3d-adapter` | Claw3D Hermes Adapter | LaunchAgent `fr.dubertrand.hermes-office-adapter` |
| `openclaw-gateway` | OpenClaw Gateway | LaunchAgent `ai.openclaw.gateway` |

Verify all service definitions exist:

```sh
test -f ~/Library/LaunchAgents/ai.hermes.gateway.plist
test -f ~/Library/LaunchAgents/fr.dubertrand.hermes-dashboard-host-proxy.plist
test -f ~/Library/LaunchAgents/fr.dubertrand.hermes-office-adapter.plist
test -f ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

Check live state:

```sh
hermes gateway status
launchctl print gui/$(id -u)/fr.dubertrand.hermes-dashboard-host-proxy
launchctl print gui/$(id -u)/fr.dubertrand.hermes-office-adapter
launchctl print gui/$(id -u)/ai.openclaw.gateway
```

### 8. Hermes Office, Claw3D adapter, and OpenClaw

The Office tab embeds Hermes Office / Studio. It is separate from the Hermes API server.

Required pieces:

1. Hermes Office web app listening on `127.0.0.1:9116`:
   `cd ~/.hermes/hermes-office && npm start`
2. Claw3D Hermes adapter listening on `127.0.0.1:18790`:
   `cd ~/.hermes/hermes-office && npm run hermes-adapter`
3. Prefer the LaunchAgent below for the adapter so it survives logout/reboot.
4. Tailscale Serve forwarding `https://mac-studio.tail4d2ab4.ts.net:9116` to `http://127.0.0.1:9116` for physical devices.
5. HermesHostCompanion → Hermes Service Ports → Hermes Office set to `9116`. HermesiOS derives the Office URL as `https://<Mac host>:9116` for physical devices or the matching local host URL for simulator use; the Office URL is no longer typed in HermesiOS Settings.
6. Office tab Claw3D WebView switch turned on when you want the WebView loaded.

LaunchAgent for the adapter:

- Label: `fr.dubertrand.hermes-office-adapter`
- Plist: `~/Library/LaunchAgents/fr.dubertrand.hermes-office-adapter.plist`
- Working directory: `~/.hermes/hermes-office`
- Command: `npm run hermes-adapter`
- Local adapter endpoint: `ws://127.0.0.1:18790`
- Studio proxy path: `:9116/api/gateway/ws`

OpenClaw gateway, if used:

- Label: `ai.openclaw.gateway`
- Plist: `~/Library/LaunchAgents/ai.openclaw.gateway.plist`
- Typical local endpoint: `ws://127.0.0.1:18789`

Verify:

```sh
launchctl print gui/$(id -u)/fr.dubertrand.hermes-office-adapter
launchctl print gui/$(id -u)/ai.openclaw.gateway
lsof -nP -iTCP:9116 -iTCP:18790 -iTCP:18789 -sTCP:LISTEN
curl -I http://127.0.0.1:9116/
```

Do not point Claw3D gateway fields at `http://127.0.0.1:8642/v1`; that is the OpenAI-compatible HTTP API, not the Claw3D WebSocket adapter.

### 9. Build and install HermesiOS

1. Open `HermesiOS.xcodeproj`.
2. Select the `HermesiOS` scheme.
3. Build for an iOS Simulator or a signed physical device.
4. In HermesHostCompanion, configure and save the Hermes Service Ports for API gateway, Dashboard, and Office before verifying the iOS app.
5. In HermesiOS Settings, configure only the client-side values:
   - Mac host, e.g. the Tailscale hostname for a physical device.
   - Host Companion TCP port, WebSocket API URL, and 256-character API key.
   - Gateway bearer token, if `API_SERVER_KEY` is configured.
   - Hermes workspace path, usually `/Volumes/WDBlack4TB/Code/HermesiOS/.hermes` for this project setup or `~/.hermes` for the default Hermes workspace.
6. Tap Verify API Key under Host Companion. Successful verification fetches the API gateway, Dashboard, and Office ports from the Mac companion. Do not type API base URLs, Dashboard URLs, Office URLs, or their service ports in HermesiOS Settings; those are derived from the Mac host plus Host Companion-provided ports.
7. Confirm the top status band shows reachable API, Mac Companion, and Dashboard states.
8. Test each major tab:
   - Ask Hermes: load profiles, send a short prompt.
   - Chat: send a short prompt and confirm debug/tool events stay out of the assistant bubble.
   - History: search a known term and open a session.
   - Agent Runtime: refresh a harmless panel such as Observability or Profiles.
   - Settings: refresh service status.
   - Office: turn the WebView on and load the Office URL.

Command-line build check:

```sh
xcodebuild -project HermesiOS.xcodeproj -scheme HermesiOS -destination 'generic/platform=iOS Simulator' build
```

Host Companion build check:

```sh
xcodebuild -project HermesiOS.xcodeproj -scheme HermesHostCompanion build
```

### 10. End-to-end deployment checklist

Before considering the iOS app fully functional, verify every item:

- Hermes Agent installed from the official quickstart and `hermes doctor` passes enough for the chosen provider.
- `hermes gateway status` reports the gateway/API service running.
- Local API listens on `8642` and Tailscale serves `:8642`.
- `API_SERVER_KEY` is configured if required and copied to HermesiOS as the bearer token.
- Dashboard listens on `9119`.
- Dashboard host-rewriting proxy listens on `9120`.
- Tailscale `:9119` forwards to `127.0.0.1:9120`.
- HermesHostCompanion is built, running, listening on the configured port, and reachable through Tailscale `:9312` for physical devices.
- The 256-character Host Companion API key is copied into HermesiOS and never committed.
- LaunchAgents exist and are loaded for `ai.hermes.gateway`, `fr.dubertrand.hermes-dashboard-host-proxy`, `fr.dubertrand.hermes-office-adapter`, and `ai.openclaw.gateway` if OpenClaw is used.
- Office web app listens on `9116` and Tailscale serves `:9116`.
- Claw3D adapter listens on `18790`.
- OpenClaw gateway listens on `18789` if that workflow is needed.
- HermesHostCompanion has the correct API gateway, Dashboard, and Office service ports saved; HermesiOS Settings no longer stores those service URLs or ports.
- The app status band reports API, Mac Companion, and Dashboard as reachable.

## Project layout

- `HermesiOS/ContentView.swift`: app shell, tab/sidebar orchestration, status polling, parallel Ask Hermes screens, and Office preload gating.
- `HermesiOS/HermesResponsesAPI.swift`: Responses API models, requests, profiles, attachments, and API settings.
- `HermesiOS/HermesChatCompletionsAPI.swift`: Chat Completions requests and streaming status-pill handling.
- `HermesiOS/HermesDashboardHistorySearch.swift`: dashboard-backed search client.
- `HermesiOS/HermesAgentConfigView.swift`: Agent Runtime panels.
- `HermesiOS/HermesSettingsView.swift`: Settings, service controls, Hermes installation controls, and Host Companion verification.
- `HermesiOS/HermesOfficeView.swift`: Office status, reload, and WebView switch; its URL is derived from Host Companion-provided service ports.
- `HermesiOS/HermesCompanionClient.swift`: iOS Host Companion client.
- `HermesHostCompanion/`: macOS helper app, WebSocket server, protocol, service-port source of truth, and host-side registries.

## Development rules

- Keep the README concise outside installation/deployment.
- Do not expose actual secret values in logs, UI, docs, commits, or final summaries.
- Do not create local branches for HermesiOS app changes unless explicitly requested.
- Build successfully before committing completed HermesiOS changes.
- Commit titles should stay under 49 characters and commit bodies under 50 words.

Useful verification commands:

```sh
swiftc -typecheck HermesHostCompanion/*.swift
xcodebuild -project HermesiOS.xcodeproj -scheme HermesHostCompanion build
xcodebuild -project HermesiOS.xcodeproj -scheme HermesiOS -destination 'generic/platform=iOS Simulator' build
```
