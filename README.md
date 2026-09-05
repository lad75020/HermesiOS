# HermesiOS

HermesiOS is a SwiftUI iOS/iPadOS companion for Laurent's Hermes Agent setup. It gives an iPhone or iPad native access to Ask Hermes, Chat with Hermes, the dashboard-backed TUI Gateway, dashboard history, Host Companion runtime controls, macOS service controls, Hermes Agent installation updates, and the Hermes Office / Claw3D web experience.

The repository contains two app targets:

- `HermesiOS/`: the iOS/iPadOS client.
- `HermesHostCompanion/`: the macOS helper that performs trusted host operations over an authenticated WebSocket.

Host file edits, service controls, git operations, and secret-aware configuration changes should go through HermesHostCompanion. The iOS app should not directly mutate arbitrary macOS files.

## What changed recently

- The TUI Gateway navigation icon now mirrors the strongest attention state across all TUI workspaces:
  - red when at least one workspace failed;
  - green when at least one workspace completed;
  - blinking orange when at least one workspace is streaming;
  - default when every workspace is idle/default.
- Attention precedence is red > green > orange > default.
- TUI Gateway workspace top buttons keep their own per-workspace colors while the sidebar tab shows the aggregate state.
- Hermes Installation controls now use two actions:
  - `Refresh Lag`: fetches official Hermes Agent `main` and reports how far local `main` is behind.
  - `Update Hermes`: fetches official `main` into local `upstream-latest`, merges it into local `main`, stops on conflicts without pushing, and pushes clean merges to Laurent's fork.
- The old separate conflict-review and merge buttons are no longer part of the Settings UI. Resolve merge conflicts directly on the Mac, then refresh status.

## Features

- Ask Hermes through the OpenAI-compatible `/v1/responses` endpoint, with parallel independent workspaces.
- Chat with Hermes through `/v1/chat/completions`, with tool/event/debug stream output kept out of assistant chat bubbles.
- TUI Gateway tab for dashboard WebSocket sessions, streamed events, attachments, clarifications, in-conversation tool approvals, secret prompts, sudo prompts, session resume, and multiple workspaces.
- iPhone navigation uses TUI and More tabs. Tool decisions remain inside the requesting TUI conversation; there is no standalone cross-session approval inbox or background queue polling. Host Companion device authorization remains required.
- Sidebar status indicators for API, Mac Companion, Dashboard, active work, unread completion, and unread failure states.
- Profile selection through `GET /v1/profiles` and `X-Hermes-Profile`.
- Prompt attachments for images, documents, text, and source files.
- Dashboard-backed history search and session resume actions.
- Agent Runtime panels for memory, providers, models, profiles, gateway/messaging, tools, MCP servers, skills, schedules, observability, allowlisted targets, and knowledge erasure.
- Settings for the Hermes API bearer token, QR-based Host Companion onboarding, macOS service controls, Hermes installation status/update, host endpoints, workspace path, and theme.
- Office tab with a persisted Claw3D WebView On/Off switch.

## Installation and deployment

This section is intentionally detailed. HermesiOS is fully useful only when the iOS app, Hermes Agent, Hermes API gateway, dashboard/proxy, HermesHostCompanion, Tailscale Serve, and the Office/Claw3D bridge all agree on hosts, ports, credentials, and service state.

### Deployment model

HermesiOS does not run Hermes Agent locally on iOS. It connects to services running on the Mac:

```text
iPhone/iPad
  │
  ├─ HTTPS → Hermes API gateway on the Mac, usually :8642/v1
  ├─ HTTPS → Hermes dashboard/proxy on the Mac, usually :9120
  ├─ WS/WSS → HermesHostCompanion on the Mac, usually :9112 or :9312
  └─ HTTPS → Hermes Office / Studio on the Mac, usually :9116

Mac host
  ├─ Hermes Agent workspace, normally ~/.hermes
  ├─ Hermes API gateway LaunchAgent
  ├─ Hermes dashboard and dashboard host-rewriting proxy
  ├─ HermesHostCompanion macOS app
  ├─ Tailscale Serve HTTPS forwards for physical devices
  └─ Optional Office / Claw3D / OpenClaw services
```

For the iOS Simulator, loopback and Mac-local endpoints can be enough. For a physical iPhone or iPad, use Tailscale Serve or another trusted HTTPS/WSS path from the device to the Mac.

### 1. Prerequisites

On the Mac host:

1. Install Xcode and open this project once so signing, schemes, and simulator runtimes are available.
2. Install Homebrew, Node.js/npm, Python 3.11+, Git, and Tailscale.
3. Install and configure Hermes Agent from the official quickstart: <https://hermes-agent.nousresearch.com/docs/getting-started/quickstart>
4. Install Hermes Agent in the expected workspace, normally `~/.hermes/hermes-agent`.
5. Run the Hermes setup wizard and configure at least one provider/model:

   ```sh
   hermes setup
   ```

6. Verify Hermes itself:

   ```sh
   hermes doctor
   hermes status --all
   ```

7. Make sure the Mac and the iPhone/iPad are on the same Tailscale tailnet if you deploy to a physical device.
8. Configure Xcode signing for the `HermesiOS` target if you deploy to a physical device.

### 2. Required services and ports

HermesHostCompanion is the source of truth for the API gateway, Dashboard, and Office ports that HermesiOS uses after device approval. The iOS app stores the Mac host and companion WebSocket port, then fetches service ports from the Mac companion.

| Purpose | Local endpoint on Mac | Typical device endpoint | Required for |
| --- | --- | --- | --- |
| Hermes API gateway | `http://127.0.0.1:8642/v1` | `https://your-mac.ts.net:8642/v1` | Ask Hermes, Chat, profiles, API status |
| Hermes dashboard proxy | `http://127.0.0.1:9120` | `https://your-mac.ts.net:9120` | History, TUI Gateway session bootstrap, dashboard APIs |
| Legacy dashboard backend | `http://127.0.0.1:9119` | Prefer proxy `:9120` for devices | Local dashboard server behind the proxy |
| Hermes Office / Studio | `http://127.0.0.1:9116` | `https://your-mac.ts.net:9116` | Office tab and Claw3D WebView |
| HermesHostCompanion WebSocket | `ws://127.0.0.1:9112/ws` by default; Laurent's deployment may use `:9312` | `ws://your-mac.ts.net:9112/ws` or `ws://your-mac.ts.net:9312/ws` on tailnet hosts | Runtime panels, service controls, pairing, install/update |
| Claw3D Hermes adapter | `ws://127.0.0.1:18790` | proxied through Office at `/api/gateway/ws` | Claw3D/OpenClaw bridge |
| OpenClaw gateway | `ws://127.0.0.1:18789` | optional | OpenClaw gateway compatibility |

Recommended Host Companion service-port values:

| Host Companion field | Recommended value | Notes |
| --- | ---: | --- |
| API gateway | `8642` | Hermes OpenAI-compatible API server. |
| Hermes Dashboard | `9120` | Dashboard host-rewriting proxy. Use this for remote devices. |
| Hermes Office | `9116` | Hermes Office / Studio web app. |

> [!NOTE]
> Older deployments used dashboard port `9119` externally. Current HermesiOS treats `9119` as the legacy local dashboard backend and prefers `9120` for device-facing dashboard/proxy access.

### 3. Start the Hermes API gateway

HermesiOS talks to Hermes through the gateway API Server platform.

1. Configure Hermes Agent if it has not been configured yet:

   ```sh
   hermes setup
   ```

2. Enable/configure the API Server platform:

   ```sh
   hermes gateway setup
   ```

3. If the API gateway is reachable beyond loopback, configure a gateway bearer secret in the Hermes workspace environment. Use the same value in HermesiOS Settings → Gateway → Bearer token.

4. Install and start the macOS LaunchAgent:

   ```sh
   hermes gateway install
   hermes gateway start
   ```

5. Verify the service on the Mac:

   ```sh
   hermes gateway status
   lsof -nP -iTCP:8642 -sTCP:LISTEN
   curl -i http://127.0.0.1:8642/v1/models
   ```

A `401 Invalid API key` response still proves the route is reachable. A `200` response requires a valid bearer value.

Typical LaunchAgent details:

- Label: `ai.hermes.gateway`
- Plist: `~/Library/LaunchAgents/ai.hermes.gateway.plist`
- Logs: `~/.hermes/logs/gateway.log` and `~/.hermes/logs/gateway.error.log`
- Program: `~/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run --replace`

In HermesHostCompanion, set the API gateway service port to `8642` unless your Hermes gateway listens elsewhere. HermesiOS derives the API base URL as `https://<Mac host>:<API port>/v1` after Host Companion approval.

### 4. Start the dashboard and dashboard proxy

History search and the TUI Gateway use the Hermes dashboard, not the OpenAI-compatible API gateway. Dashboard JSON routes need the session token injected into dashboard HTML, so HermesiOS first loads the dashboard root, extracts the session token, then calls dashboard APIs.

Recommended setup:

1. Start the Hermes dashboard locally on `127.0.0.1:9119`:

   ```sh
   ~/.hermes/hermes-agent/venv/bin/python3 ~/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open
   ```

2. Start the host-rewriting proxy on `127.0.0.1:9120` so device requests do not fail dashboard Host-header validation:

   ```sh
   ~/.hermes/hermes-agent/venv/bin/python3 ~/.hermes/scripts/hermes_dashboard_host_proxy.py
   ```

3. Prefer the LaunchAgent below for persistence instead of terminal sessions.
4. Set HermesHostCompanion → Hermes Service Ports → Hermes Dashboard to `9120`.
5. Use Tailscale Serve to expose `:9120` to physical devices.

Proxy LaunchAgent details:

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
curl -I https://your-mac.ts.net:9120/
```

If local `:9120` works but the Tailscale URL returns `502`, Tailscale Serve cannot reach the local proxy.

### 5. Configure Tailscale Serve for physical devices

The iOS Simulator can often use local Mac endpoints. A physical device needs the Mac services exposed through Tailscale Serve or an equivalent trusted network path.

Typical Tailscale Serve commands:

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 8642 http://127.0.0.1:8642
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9120 http://127.0.0.1:9120
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9116 http://127.0.0.1:9116
```

Expose the Host Companion port that you actually configured. The code default is `9112`; Laurent's current deployment may use `9312`:

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9112 http://127.0.0.1:9112
# or, if Host Companion is configured for 9312:
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9312 http://127.0.0.1:9312
```

Verify routes and listeners:

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve status
lsof -nP -iTCP:8642 -iTCP:9120 -iTCP:9116 -iTCP:9112 -iTCP:9312 -sTCP:LISTEN
```

Expected important routes:

- `https://your-mac.ts.net:8642` → `http://127.0.0.1:8642`
- `https://your-mac.ts.net:9120` → `http://127.0.0.1:9120`
- `https://your-mac.ts.net:9116` → `http://127.0.0.1:9116`
- `https://your-mac.ts.net:9112` or `https://your-mac.ts.net:9312` → matching Host Companion local port

HermesiOS allows plaintext `ws://` only for loopback and tailnet hosts. Use TLS/WSS for other remote networks.

### 6. Build and run HermesHostCompanion

HermesHostCompanion is required for:

- QR device onboarding and approval;
- Agent Runtime panels;
- macOS service status/start/stop/restart;
- service-port discovery for API, Dashboard, and Office;
- Hermes Installation `Refresh Lag` and `Update Hermes`;
- allowlisted host file reads/writes and log access.

Steps:

1. Open the project:

   ```sh
   open HermesiOS.xcodeproj
   ```

2. Select the `HermesHostCompanion` scheme.
3. Build and run the macOS target.
4. In the Host Companion window, configure Network Target:
   - Advertised host: `127.0.0.1` for simulator-only use, or your Tailscale hostname such as `your-mac.ts.net` for physical devices.
   - API port: `9112` by default, or `9312` if that is the configured deployment port.
5. Click Apply Network Target.
6. Configure Hermes Service Ports:
   - API gateway: `8642`.
   - Hermes Dashboard: `9120`.
   - Hermes Office: `9116`.
7. Click Save Service Ports.
8. Start or restart the Host Companion server.
9. Keep the macOS app running while HermesiOS uses runtime/service/install features.

Command-line build check:

```sh
xcodebuild -project HermesiOS.xcodeproj -scheme HermesHostCompanion build
```

Expected WebSocket URLs:

- Simulator/local default: `ws://127.0.0.1:9112/ws`
- Simulator/local alternate: `ws://127.0.0.1:9312/ws`
- Physical device on a Tailscale hostname: `ws://your-mac.ts.net:9112/ws` or `ws://your-mac.ts.net:9312/ws`
- Non-tailnet TLS reverse proxy: `wss://your-host.example:port/ws`

Legacy note: older Host Companion docs/settings may mention a shared API key, `9212/enroll`, pinned certificates, fingerprints, CAs, or enrollment IDs. Treat those as stale. Current Host Companion access uses QR device onboarding with a unique device ID and device secret per iOS device.

### 7. Pair HermesiOS with Host Companion

1. Launch HermesiOS on the simulator or device.
2. Open Settings → Host Companion.
3. Enter the Mac host:
   - `127.0.0.1` for local simulator use when Host Companion listens locally.
   - `your-mac.ts.net` for a physical device over Tailscale.
4. Enter the Host Companion port, normally `9112` or the configured deployment port such as `9312`.
5. In HermesHostCompanion, show the QR code.
6. Scan the QR code from HermesiOS Settings.
7. Approve the pending device in HermesHostCompanion.
8. In HermesiOS, tap Check Approval if it does not update automatically.
9. Confirm the Mac Companion indicator turns reachable.
10. Confirm HermesiOS fetched the API gateway, Dashboard, and Office ports from Host Companion.

After approval, do not manually type API base URLs, Dashboard URLs, Office URLs, or their service ports into HermesiOS. Host Companion is the source of truth for those ports, and HermesiOS derives URLs from the approved Mac host.

Revoke or forget devices from HermesHostCompanion when an iPhone/iPad should lose access.

### 8. Configure HermesiOS Settings

In the iOS app, configure only client-side values:

| Setting | Value |
| --- | --- |
| Mac host | `127.0.0.1` for simulator/local, or the Tailscale hostname for physical devices. |
| Host Companion port | `9112` by default, or the configured port such as `9312`. |
| Gateway bearer token | The same bearer value expected by the Hermes API gateway, if one is configured. |
| Hermes workspace path | Usually `~/.hermes`; Laurent's project setups may use a workspace under `/Volumes/WDBlack4TB`. |
| Theme/UI preferences | Optional. |

Then verify the top status band:

- API should be reachable after gateway/Tailscale/bearer token setup.
- Mac Companion should be reachable after QR onboarding and approval.
- Dashboard should be reachable after proxy/Tailscale/service-port setup.

### 9. Install and update Hermes Agent from Settings

HermesiOS Settings includes a Hermes Installation panel backed by HermesHostCompanion. It expects the selected Hermes workspace to contain a `hermes-agent` git repository.

Expected repository layout:

```text
<workspace>/
  hermes-agent/
    .git/
```

The current workflow is:

1. Tap `Refresh Lag`.
   - Host Companion fetches official `NousResearch/hermes-agent` `main`.
   - It compares local `main` with the official main ref.
   - The UI shows local commit, upstream commit, branch, remote, and behind count.
2. Tap `Update Hermes` when local `main` should be updated.
   - Host Companion requires no merge in progress.
   - Host Companion requires a clean Hermes Agent working tree.
   - It switches to local `main` if needed.
   - It fetches official `main` into local `upstream-latest`.
   - It merges `upstream-latest` into local `main`.
   - If the merge is clean, it pushes local `main` to `lad75020/hermes-agent` `main`.
   - If conflicts occur, it stops before push and reports the conflicted files.
3. If conflicts occur, resolve them directly on the Mac in the Hermes Agent repository, complete or abort the merge, then tap `Refresh Lag` again.

Important behavior:

- `Update Hermes` does not push when git reports unresolved conflicts.
- The old `Review Conflicts with Hermes` and `Merge Reviewed Update` controls were removed.
- Local uncommitted Hermes Agent changes must be committed, stashed, or discarded before updating.
- Restart/reopen HermesHostCompanion after changing Host Companion code so the app exposes the latest update workflow.

Useful Mac-side checks:

```sh
cd ~/.hermes/hermes-agent
git status --short
git branch --show-current
git rev-list --count main..hermes-official/main 2>/dev/null || true
git diff --name-only --diff-filter=U
```

### 10. macOS services managed from HermesiOS Settings

The Settings tab can query/start/stop/restart allowlisted Mac services through Host Companion.

| Service ID | Display name | Control method |
| --- | --- | --- |
| `hermesd` | Hermes Gateway / API Server | `hermes gateway status/start/stop/restart` |
| `hermes-dashboard` | Hermes Dashboard | LaunchAgent `fr.dubertrand.hermes-dashboard-host-proxy` |
| `claw3d-adapter` | Claw3D Hermes Adapter | LaunchAgent `fr.dubertrand.hermes-office-adapter` |
| `openclaw-gateway` | OpenClaw Gateway | LaunchAgent `ai.openclaw.gateway` |

Verify definitions:

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

### 11. Hermes Office, Claw3D adapter, and OpenClaw

The Office tab embeds Hermes Office / Studio. It is separate from the Hermes API gateway.

Required pieces:

1. Hermes Office web app listening on `127.0.0.1:9116`:

   ```sh
   cd ~/.hermes/hermes-office
   npm start
   ```

2. Claw3D Hermes adapter listening on `127.0.0.1:18790`:

   ```sh
   cd ~/.hermes/hermes-office
   npm run hermes-adapter
   ```

3. Prefer the LaunchAgent below for the adapter so it survives logout/reboot.
4. Tailscale Serve forwarding `https://your-mac.ts.net:9116` to `http://127.0.0.1:9116` for physical devices.
5. HermesHostCompanion → Hermes Service Ports → Hermes Office set to `9116`.
6. Office tab Claw3D WebView switch turned on when you want the WebView loaded.

Adapter LaunchAgent details:

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

### 12. Build and install HermesiOS

Xcode workflow:

1. Open `HermesiOS.xcodeproj`.
2. Select the `HermesiOS` scheme.
3. Select an iOS Simulator or a signed physical device.
4. Build and run.
5. Configure Settings as described above.
6. Pair and approve the device with HermesHostCompanion.
7. Confirm API, Mac Companion, and Dashboard status indicators are reachable.

Command-line simulator build check:

```sh
xcodebuild -project HermesiOS.xcodeproj -scheme HermesiOS -destination 'generic/platform=iOS Simulator' build
```

Command-line Host Companion build check:

```sh
xcodebuild -project HermesiOS.xcodeproj -scheme HermesHostCompanion build
```

End-to-end smoke test after installation:

1. Ask Hermes: load profiles and send a short prompt.
2. Chat: send a short prompt and confirm debug/tool/event stream output stays out of the assistant bubble.
3. TUI Gateway: connect, create or resume a session, send a short prompt, and verify workspace/top-button attention states.
4. TUI Gateway sidebar: leave one workspace streaming/completed/failed and confirm the navigation icon follows red > green > orange > default precedence.
5. History: search a known term and open a session.
6. Agent Runtime: refresh a harmless panel such as Observability or Profiles.
7. Settings: refresh macOS service status and Hermes Installation lag.
8. Office: turn the WebView on and load the Office URL.

### 13. End-to-end deployment checklist

Before considering the deployment ready, verify every item:

- Hermes Agent is installed from the official quickstart.
- `hermes doctor` passes enough for the configured provider/model.
- Hermes gateway/API service is running.
- Local API listens on `8642`.
- Tailscale Serve exposes `:8642` for physical devices.
- Gateway bearer value is configured consistently, if required.
- Dashboard backend listens locally on `9119`.
- Dashboard proxy listens locally on `9120`.
- Tailscale Serve exposes `:9120` for physical devices.
- HermesHostCompanion is built, running, and listening on the configured port.
- Tailscale Serve exposes the configured Host Companion port for physical devices.
- HermesHostCompanion service ports are saved: API `8642`, Dashboard `9120`, Office `9116` unless intentionally changed.
- The iOS device scanned the QR code and is approved in HermesHostCompanion.
- HermesiOS fetched service ports from Host Companion after approval.
- LaunchAgents exist and are loaded for gateway, dashboard proxy, Office adapter, and OpenClaw if used.
- Office web app listens on `9116`.
- Claw3D adapter listens on `18790`.
- OpenClaw gateway listens on `18789` if that workflow is needed.
- The app status band reports API, Mac Companion, and Dashboard as reachable.
- Ask, Chat, TUI Gateway, History, Agent Runtime, Settings, and Office smoke tests pass.

### Troubleshooting deployment

| Symptom | Likely cause | Check/fix |
| --- | --- | --- |
| Tailscale URL returns `502` | Local service is not listening or Serve points at the wrong local port. | Run `Tailscale serve status` and `lsof -nP -iTCP:<port> -sTCP:LISTEN`. |
| API `/v1/models` returns `401` | Network path works, bearer value is missing or wrong. | Update HermesiOS Settings → Gateway → Bearer token. |
| Dashboard works locally but not on device | Device is hitting the backend directly or Host-header validation is failing. | Use dashboard proxy `:9120` and expose that through Tailscale. |
| Mac Companion stays unreachable | Wrong host/port, Host Companion stopped, or QR approval incomplete. | Recheck Network Target, listener port, Tailscale Serve route, and device approval. |
| Runtime panels fail after Host Companion update | Old macOS helper process is still running. | Rebuild, quit, and relaunch HermesHostCompanion. |
| `Update Hermes` refuses to run | Merge in progress or dirty Hermes Agent working tree. | Resolve/abort merge or clean the Hermes Agent repo on the Mac. |
| `Update Hermes` reports conflict files | Official main did not merge cleanly into local main. | Resolve conflicts in the Mac repo, complete or abort merge, then tap `Refresh Lag`. |
| Office loads but Claw3D fails | Office web app is reachable but adapter is down or wrong WebSocket path. | Check `fr.dubertrand.hermes-office-adapter` and port `18790`. |

## Project layout

- `HermesiOS/ContentView.swift`: app shell, tab/sidebar orchestration, status polling, workspace attention aggregation, parallel Ask Hermes screens, and Office preload gating.
- `HermesiOS/HermesWorkspaceNavigation.swift`: sidebar sections, status band, unread/completion/failure indicators, and tab icon coloring.
- `HermesiOS/HermesTUIGatewayView.swift`: TUI Gateway store, workspace controls, workspace button colors, dashboard WebSocket session handling, attachments, and streamed event UI.
- `HermesiOS/HermesResponsesAPI.swift`: Responses API models, requests, profiles, attachments, and API settings.
- `HermesiOS/HermesChatCompletionsAPI.swift`: Chat Completions requests and streaming status-pill handling.
- `HermesiOS/HermesDashboardHistorySearch.swift`: dashboard-backed search client.
- `HermesiOS/HermesAgentConfigView.swift`: Agent Runtime panels.
- `HermesiOS/HermesSettingsView.swift`: Settings, service controls, Hermes installation controls, and Host Companion QR onboarding.
- `HermesiOS/HermesOfficeView.swift`: Office status, reload, and WebView switch; URL is derived from Host Companion-provided service ports.
- `HermesiOS/HermesCompanionClient.swift`: iOS Host Companion client.
- `HermesHostCompanion/`: macOS helper app, WebSocket server, QR onboarding, service-port source of truth, service registries, and host-side git/runtime registries.

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
