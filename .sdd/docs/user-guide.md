# HermesiOS User Guide

HermesiOS is an iPhone and iPad app that gives you a full command center for your
self-hosted Hermes Agent. From the app you can chat with the agent, manage
models and providers, drive the gateway, review history, approve or deny
dangerous commands, and control a paired Mac. This guide explains each feature
and how to get started.

## First-run setup

1. Make sure your Mac is running Hermes Agent, the API gateway, the dashboard
   proxy, and (for host features) the Hermes Host Companion. See the deployment
   guide if these are not set up yet.
2. Open HermesiOS and go to Settings.
3. Enter your Mac host and the API bearer token for the gateway.
4. Pair the Host Companion: in Settings open Host Companion and scan the QR code
   shown by the Mac app, then approve the device on the Mac.
5. Pick a profile and a model. The selected profile is applied to your agent
   requests; the selected model is used for Ask Hermes and Chat.
6. Leave streaming on for live, incremental responses, or turn it off to receive
   whole responses at once.

## Workspaces

The sidebar lists every workspace. Status dots on the sidebar show whether the
API, Mac companion, and dashboard channels are active, and highlight unread
completions, unread failures, and in-progress streaming.

### Ask Hermes

Send a prompt to the agent through the responses endpoint. Responses stream in
live when streaming is enabled, and each new turn chains onto the previous one so
the agent keeps context. Your in-progress prompt is saved as a draft, and your
last session can be resumed.

### Chat with Hermes

A separate chat transcript using the chat-completions endpoint. It is
independent from Ask Hermes, so you can keep two lines of conversation.

### TUI Gateway

Talk to Hermes through the dashboard TUI Gateway over a live WebSocket. This
workspace handles streamed events, attachments, clarification prompts, approval
prompts, secret prompts, sudo prompts, session resume, and multiple parallel
workspaces. The sidebar icon reflects the strongest attention state across all
TUI workspaces: red if any failed, green if any completed, blinking orange if
any is streaming, and default when all are idle.

### Approvals Inbox

When the agent requests a dangerous command, it appears here. You can approve or
deny pending requests across sessions and profiles from one place.

### History

Search saved requests and final responses, grouped by session, using the
dashboard. You can resume a session directly from a history entry.

### Web

Browse a web page inside HermesiOS without leaving the app.

### Terminal

Open an SSH terminal to your configured Mac host for quick command-line access.

### Utilities

Local helpers, including a clipboard history.

### Hermes Agent Runtime

Companion-backed panels for operating the agent on the Mac: memory, providers,
models, profiles, gateway and messaging, tools, MCP servers, skills, schedules,
observability, allowlisted targets, and knowledge erasure. This workspace
requires a paired, approved Host Companion. Enable it from Settings if it is
hidden.

### Office

Opens the Hermes Office / Claw3D web experience. Toggle the WebView on or off;
the choice is remembered.

### Settings

Configure the gateway bearer token, Host Companion onboarding, macOS service
controls, Hermes installation status and update, host endpoints, workspace path,
selected model and profile, streaming, and theme.

## Prompt attachments

Ask Hermes and Chat accept attachments:

- Images: `png`, `jpg`, `jpeg`, `gif`, `webp`.
- Documents: `pdf`, `docx`, `pptx`, `xlsx`.
- Text and source: `txt`, `text`, `json`, `yaml`, `yml`, `toml`, `swift`.

Text and source files are embedded inline with your prompt. Other files are
passed as encoded data the agent can decode. Unsupported file types are
rejected with a clear message.

## Managing the Mac from your device

With the Host Companion paired and approved you can, from the Runtime panels and
Settings: start, stop, and restart Mac services; view and edit agent memory;
switch models and providers; enable or disable skills and toolsets; add or
remove MCP servers; manage the gateway configuration and platforms; control
Tailscale Serve; tail logs; erase knowledge; and run the Hermes installation
controls.

Hermes installation has two actions in Settings:

- Refresh Lag: fetches the official Hermes Agent `main` and reports how far your
  local `main` is behind.
- Update Hermes: fetches official `main`, merges it into your local `main`,
  stops on conflicts without pushing, and pushes clean merges to your fork.

If an update stops on conflicts, resolve them on the Mac, then refresh status.

## Troubleshooting

- Plaintext blocked: HermesiOS refuses plaintext `http`/`ws` to hosts that are
  not localhost or a Tailscale tailnet host. Use HTTPS/WSS, or reach the Mac
  over Tailscale, for any other network.
- Tailscale returns 502: if a local Mac endpoint works but the Tailscale URL
  returns 502, Tailscale Serve cannot reach the local service. Recheck the
  Serve mapping and that the local service is listening.
- Host features unavailable: Runtime panels, service controls, pairing, and
  install/update require the macOS Host Companion to be running and this device
  to be approved. Reopen the companion on the Mac and re-approve if needed.
- 401 from the gateway: the gateway is reachable but the bearer token is missing
  or wrong. Re-enter the token in Settings.
- No models listed: confirm the gateway is running and a provider/model is
  configured on the Mac, then refresh models.
