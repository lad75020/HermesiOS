# HermesiOS Installation and Deployment Guide

This guide is intentionally detailed. HermesiOS is fully useful only when the iOS
app, Hermes Agent, the Hermes API gateway, the dashboard proxy, Hermes Host
Companion, Tailscale Serve, and the optional Office/Claw3D bridge all agree on
hosts, ports, credentials, and service state.

## Deployment model

HermesiOS does not run Hermes Agent on iOS. It connects to services running on
the Mac.

```text
iPhone / iPad
  |-- HTTPS  --> Hermes API gateway on the Mac, usually :8642/v1
  |-- HTTPS  --> Hermes dashboard proxy on the Mac, usually :9120
  |-- WS/WSS --> HermesHostCompanion on the Mac, usually :9112 or :9312
  |-- HTTPS  --> Hermes Office / Studio on the Mac, usually :9116

Mac host
  |-- Hermes Agent workspace, normally ~/.hermes/hermes-agent
  |-- Hermes API gateway LaunchAgent
  |-- Hermes dashboard and host-rewriting proxy
  |-- HermesHostCompanion macOS app
  |-- Tailscale Serve HTTPS forwards for physical devices
  |-- Optional Office / Claw3D services
```

The iOS Simulator can usually use Mac-local loopback endpoints. A physical
iPhone or iPad needs the Mac services exposed through Tailscale Serve or another
trusted HTTPS/WSS path.

## 1. Prerequisites

On the Mac host:

1. Install Xcode (16 or newer) and open this project once so signing, schemes,
   and simulator runtimes are available.
2. Install Homebrew, Node.js/npm, Python 3.11 or newer, Git, and Tailscale.
3. Install and configure Hermes Agent from the official quickstart at
   <https://hermes-agent.nousresearch.com/docs/getting-started/quickstart>.
4. Install Hermes Agent in the expected workspace, normally
   `~/.hermes/hermes-agent`.
5. Run the Hermes setup wizard and configure at least one provider/model:

   ```sh
   hermes setup
   ```

6. Verify Hermes itself:

   ```sh
   hermes doctor
   hermes status --all
   ```

7. Put the Mac and the iPhone/iPad on the same Tailscale tailnet if you deploy
   to a physical device.
8. Configure Xcode signing for the `HermesiOS` target for physical-device
   deployment.

Build targets: the iOS client targets `IPHONEOS_DEPLOYMENT_TARGET = 26.4` and the
macOS companion targets `MACOSX_DEPLOYMENT_TARGET = 26.0` (Swift 5.0).

## 2. Required services and ports

HermesHostCompanion is the source of truth for the API gateway, Dashboard, and
Office ports that HermesiOS uses after device approval. The iOS app stores the
Mac host and companion WebSocket port, then fetches service ports from the Mac
companion.

| Purpose | Local endpoint on Mac | Typical device endpoint | Required for |
| --- | --- | --- | --- |
| Hermes API gateway | `http://127.0.0.1:8642/v1` | `https://your-mac.ts.net:8642/v1` | Ask Hermes, Chat, profiles, API status |
| Hermes dashboard proxy | `http://127.0.0.1:9120` | `https://your-mac.ts.net:9120` | History, TUI Gateway bootstrap, dashboard APIs |
| Legacy dashboard backend | `http://127.0.0.1:9119` | Prefer proxy `:9120` for devices | Local dashboard behind the proxy |
| Hermes Office / Studio | `http://127.0.0.1:9116` | `https://your-mac.ts.net:9116` | Office tab and Claw3D WebView |
| Host Companion WebSocket | `ws://127.0.0.1:9112/ws` (or `:9312`) | `ws://your-mac.ts.net:9112/ws` or `:9312` on tailnet | Runtime panels, service controls, pairing, install/update |
| Claw3D Hermes adapter | `ws://127.0.0.1:18790` | proxied through Office at `/api/gateway/ws` | Claw3D/OpenClaw bridge |
| OpenClaw gateway | `ws://127.0.0.1:18789` | optional | OpenClaw compatibility |

Recommended Host Companion service-port values: API gateway `8642`, Hermes
Dashboard `9120`, Hermes Office `9116`.

Older deployments used dashboard port `9119` externally. Current HermesiOS
treats `9119` as the legacy local backend and prefers `9120` for device-facing
access; it rewrites `9119` to `9120` automatically for non-loopback hosts.

## 3. Start the Hermes API gateway

1. Configure Hermes Agent if not already done:

   ```sh
   hermes setup
   ```

2. Enable/configure the API Server platform:

   ```sh
   hermes gateway setup
   ```

3. If the gateway is reachable beyond loopback, configure a gateway bearer
   secret in the Hermes workspace environment, and enter the same value in
   HermesiOS Settings under Gateway. Treat this value as a password: do not paste
   it into shared terminals or scripts where it can leak.

4. Install and start the macOS LaunchAgent:

   ```sh
   hermes gateway install
   hermes gateway start
   ```

5. Verify on the Mac:

   ```sh
   hermes gateway status
   lsof -nP -iTCP:8642 -sTCP:LISTEN
   curl -i http://127.0.0.1:8642/v1/models
   ```

   A `401 Invalid API key` response still proves the route is reachable; a `200`
   requires a valid bearer value.

Typical LaunchAgent details:

- Label: `ai.hermes.gateway`
- Plist: `~/Library/LaunchAgents/ai.hermes.gateway.plist`
- Logs: `~/.hermes/logs/gateway.log`, `~/.hermes/logs/gateway.error.log`
- Program: `~/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run --replace`

HermesiOS derives the API base URL as `https://<Mac host>:<API port>/v1` after
Host Companion approval.

## 4. Start the dashboard and proxy

History and the TUI Gateway use the dashboard, not the OpenAI-compatible gateway.
Dashboard JSON routes need a session token injected into dashboard HTML, so
HermesiOS loads the dashboard root, extracts the token, then calls dashboard
APIs.

1. Start the dashboard locally on `127.0.0.1:9119`:

   ```sh
   ~/.hermes/hermes-agent/venv/bin/python3 ~/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open
   ```

2. Start the host-rewriting proxy on `127.0.0.1:9120` so device requests pass
   dashboard Host-header validation:

   ```sh
   ~/.hermes/hermes-agent/venv/bin/python3 ~/.hermes/scripts/hermes_dashboard_host_proxy.py
   ```

3. Prefer the LaunchAgent below for persistence.
4. Set Host Companion Hermes Dashboard port to `9120`.
5. Expose `:9120` to devices with Tailscale Serve.

Proxy LaunchAgent details:

- Label: `fr.dubertrand.hermes-dashboard-host-proxy`
- Plist: `~/Library/LaunchAgents/fr.dubertrand.hermes-dashboard-host-proxy.plist`
- Script: `~/.hermes/scripts/hermes_dashboard_host_proxy.py`
- Local proxy `127.0.0.1:9120`, local backend `127.0.0.1:9119`
- Logs: `~/.hermes/logs/hermes-dashboard-host-proxy.log` and `.err.log`

Verify:

```sh
launchctl print gui/$(id -u)/fr.dubertrand.hermes-dashboard-host-proxy
lsof -nP -iTCP:9119 -iTCP:9120 -sTCP:LISTEN
curl -I http://127.0.0.1:9120/
curl -I https://your-mac.ts.net:9120/
```

If local `:9120` works but the Tailscale URL returns `502`, Tailscale Serve
cannot reach the local proxy.

## 5. Configure Tailscale Serve for physical devices

```sh
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 8642 http://127.0.0.1:8642
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9120 http://127.0.0.1:9120
/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --bg --https 9116 http://127.0.0.1:9116
```

Expose the Host Companion port you actually configured (default `9112`, some
deployments `9312`):

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

Expected routes:

- `https://your-mac.ts.net:8642` to `http://127.0.0.1:8642`
- `https://your-mac.ts.net:9120` to `http://127.0.0.1:9120`
- `https://your-mac.ts.net:9116` to `http://127.0.0.1:9116`
- `https://your-mac.ts.net:9112` or `:9312` to the matching companion port

HermesiOS allows plaintext `ws://` only for loopback and tailnet hosts. Use
TLS/WSS for any other remote network.

## 6. Build and run HermesHostCompanion

HermesHostCompanion is required for QR onboarding/approval, Runtime panels,
macOS service status/start/stop/restart, service-port discovery, the Hermes
installation Refresh Lag and Update actions, and allowlisted host file/log
access.

1. Open the project:

   ```sh
   open HermesiOS.xcodeproj
   ```

2. Select the `HermesHostCompanion` scheme and run the macOS target.
3. Configure Network Target:
   - Advertised host: `127.0.0.1` for simulator-only use, or your Tailscale
     hostname such as `your-mac.ts.net` for physical devices.
   - API port: `9112` by default, or `9312` if that is your deployment port.
4. Click Apply Network Target.
5. Configure Hermes Service Ports: API gateway `8642`, Dashboard `9120`, Office
   `9116`. Save Service Ports.
6. Start or restart the Host Companion server and keep the macOS app running
   while HermesiOS uses runtime/service/install features.

Command-line build check:

```sh
xcodebuild -project HermesiOS.xcodeproj -scheme HermesHostCompanion build
```

Expected WebSocket URLs:

- Simulator/local default: `ws://127.0.0.1:9112/ws`
- Simulator/local alternate: `ws://127.0.0.1:9312/ws`
- Physical device on Tailscale: `ws://your-mac.ts.net:9112/ws` or `:9312/ws`
- Non-tailnet TLS reverse proxy: `wss://your-host.example:port/ws`

Legacy note: older docs mentioning a shared API key, `9212/enroll`, pinned
certificates, fingerprints, CAs, or enrollment IDs are stale. Current access
uses QR device onboarding with a unique device ID and device secret per iOS
device.

## 7. Pair HermesiOS with Host Companion

1. Launch HermesiOS on the simulator or device.
2. Open Settings and then Host Companion.
3. Enter the Mac host (`127.0.0.1` for local simulator use, or
   `your-mac.ts.net` for a physical device over Tailscale).
4. Enter the Host Companion port, normally `9112` (or `9312`).
5. Scan the QR code shown by the macOS Host Companion app.
6. Approve the device on the Mac. The iOS app polls approval and stores a
   per-device ID and secret in its Keychain.

The device secret is a credential. It is stored only in the device Keychain;
never share it or paste it into logs.

## 8. Verification checklist

- Gateway reachable: `curl -i http://127.0.0.1:8642/v1/models` returns `401` or
  `200`.
- Dashboard proxy reachable locally and over Tailscale (`curl -I`).
- Companion listening on the configured port (`lsof`).
- Device shows approved in the app after Mac-side approval.
- Ask Hermes returns a streamed response with a valid model and token.

## 9. Updates and rollback

Use the in-app Hermes installation controls (Settings):

- Refresh Lag reports how far local `main` is behind official `main`.
- Update Hermes fetches official `main`, merges it into local `main`, stops on
  conflicts without pushing, and pushes clean merges to your fork.

If an update stops on conflicts, resolve them directly on the Mac, then refresh
status. Because the update stops before pushing on conflict, the remote fork is
not advanced until the merge is clean, which provides a natural rollback point
(reset local `main` to the previous commit on the Mac if needed).
