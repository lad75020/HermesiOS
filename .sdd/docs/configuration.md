# HermesiOS Configuration Reference

This reference documents the user-configurable settings HermesiOS persists, where
each value is stored, and the default endpoints. Secrets are described in prose;
no real token or key values appear here.

## Storage model

Configuration is owned by the `HermesSettingsPersistence` enum
(`HermesiOS/HermesSettingsPersistence.swift`). Non-secret settings are stored as
structured `Codable` values in `UserDefaults`. Secrets are stored in the
Keychain and are never written to `UserDefaults`. The API key is stripped from
the persisted `HermesAPISettings` blob before saving, then stored separately in
the Keychain.

## UserDefaults keys

| Key | Contents |
| --- | --- |
| `hermes.apiSettings` | `HermesAPISettings`: Mac host, API/dashboard/office/companion ports, selected model, selected profile, streaming flag, theme (API key excluded) |
| `hermes.responsesDraft` | In-progress Ask Hermes prompt draft |
| `hermes.chatDraft` | In-progress Chat prompt draft |
| `hermes.lastResponsesSessionID` | Last Ask Hermes session id for resume |
| `hermes.lastResponsesSessionTitle` | Last Ask Hermes session title |
| `hermes.lastChatSessionID` | Last Chat session id for resume |
| `hermes.lastChatSessionTitle` | Last Chat session title |
| `hermes.companionSettings` | Host Companion host/port configuration |
| `hermes.companionIdentityState` | Device identity/onboarding state |
| `hermes.companionConnections` | Saved companion connections |
| `hermes.activeCompanionConnectionID` | Currently active companion connection |
| `hermes.terminalSettings` | SSH terminal connection settings (non-secret) |

Additional endpoint-related keys are defined in `HermesHostEndpoints.swift`,
including `hermes.mac.host`, `hermes.runtime.tab.enabled`, and
`hermes.tailscale.serve.selected.port`.

## Keychain secrets

| Purpose | Keychain service | Account |
| --- | --- | --- |
| Hermes API bearer token | `com.hermesios.api` | `bearerToken` |
| Companion device secret | `com.hermesios.companion` | `deviceSecret` (legacy `authenticationToken`) |
| Terminal SSH private key | `com.hermesios.terminal` | `sshPrivateKey` |

Enter these values in the app (Settings and Host Companion onboarding). They are
never displayed back in full and never leave the device except as the
appropriate credential on an authorized request.

## Default endpoints and ports

Defaults come from `HermesHostEndpoints.swift`:

| Setting | Default | Notes |
| --- | --- | --- |
| Mac host | tailnet host suffix | Set to your Mac's reachable host |
| API gateway port | `8642` | OpenAI-compatible `/v1` gateway |
| Dashboard port | `9120` | Host-rewriting proxy for devices |
| Legacy local dashboard port | `9119` | Local backend behind the proxy |
| Office port | `9116` | Hermes Office / Studio web app |
| Companion WebSocket port | `9112` | Some deployments use `9312` |

The dashboard helper rewrites the legacy port `9119` to `9120` for non-loopback
hosts (`remoteDashboardPort`), so remote devices reach the proxy rather than the
raw local backend.

## Behavioral toggles

| Setting | Default | Effect |
| --- | --- | --- |
| Streaming enabled | on | Ask Hermes consumes `/v1/responses` as SSE |
| Selected profile | `default` | Sent as `X-Hermes-Profile` on API calls |
| Office WebView enabled | off | Loads the Claw3D/Office WebView in the Office tab |
| Runtime tab enabled | off | Shows the Hermes Agent Runtime workspace |
| Theme | `system` | Light/dark/system appearance |
| Tailscale Serve port | unset | Selected port for Tailscale Serve helpers |

## Transport policy

HermesiOS refuses to send credentials over plaintext `http`/`ws` unless the host
is loopback (`127.*`, `localhost`, `::1`) or a Tailscale tailnet host
(`*.ts.net`, the `100.64.0.0/10` range, or the `fd7a:115c:a1e0:` IPv6 prefix).
For every other remote host, configure HTTPS/WSS endpoints. This policy is
enforced by `HermesEndpointSecurity` and cannot be bypassed through settings.
