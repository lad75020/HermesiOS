# HermesiOS

HermesiOS is the SwiftUI iOS/iPadOS companion app for Laurent's Hermes Agent environment. It provides mobile access to Hermes API chat surfaces, dashboard history, host-side Hermes Agent configuration, and the Hermes Office web experience.

The app is intentionally split into two sides:

- HermesiOS: the iOS/iPadOS SwiftUI client in `HermesiOS/`.
- HermesHostCompanion: the macOS helper in `HermesHostCompanion/` that performs trusted host operations over an authenticated WebSocket protocol.

Most host file edits, service controls, git operations, and secret-aware configuration changes must go through HermesHostCompanion. The iOS app should not directly read or mutate arbitrary macOS files.

## Main product areas

### Ask Hermes and Chat

HermesiOS exposes both OpenAI-compatible Hermes API surfaces:

- `/v1/responses` through the Ask Hermes / Responses console.
- `/v1/chat/completions` through the Chat console.

Current behavior and conventions:

- The app uses Hermes profiles as the user-facing execution context selector, not raw provider/model selection per request.
- Profiles come from `GET /v1/profiles`.
- Requests send the selected profile through `X-Hermes-Profile`.
- The request `model` remains the Hermes API compatibility id, normally `hermes-agent` unless centralized elsewhere.
- The selected profile is locked into a session once a request starts. Switching profile should start a fresh session or clear continuation state.
- Chat and Responses can resume stored Hermes sessions where server support exists; use the persisted Hermes `SessionDB` id as the universal resume key, not transient TUI runtime ids or `resp_...` ids.
- Ask Hermes supports up to four parallel Responses screens. The `+` control creates a new screen, numbered title-area buttons switch between screens, and each screen owns its own transcript, selected profile/session state, attachments, and request lifecycle.
- Keep Ask Hermes busy/disabled state scoped to the active screen where possible. A sending screen must not block unrelated screens except for shared global actions that truly cannot run concurrently.

### Prompt attachments

The prompt composers support local attachments:

- A paperclip button sits next to the prompt area.
- Selected attachments appear as removable chips.
- Images are sent as inline base64 data URLs in OpenAI/Hermes multimodal image shapes.
- Text, source, and document files are appended to prompt text with filename, MIME, size metadata, and content when possible.
- The Hermes API server currently accepts inline images but rejects `file` / `input_file` parts, so document-style attachments are represented in prompt text rather than sent as file parts.

### Console bubbles and copy affordances

The Chat and Responses consoles share bubble styling helpers where possible. Copy controls should copy the real adjacent message content to the platform pasteboard (`UIPasteboard` on iOS, `NSPasteboard` where relevant), not a rendered approximation.

### Streaming debug and observability events

Hermes chat-completions streaming can emit Hermes-specific debug SSE events in addition to normal OpenAI text chunks:

- `hermes.tool.progress`
- `Hermes.reasoning.summary`
- `Hermes.tool.output`

Normal assistant text must remain in unnamed OpenAI-compatible `data:` chunks. Debug information should not be injected into `delta.content`.

Chat must keep tool/event/debug logs out of the assistant bubble. Stream events should update a concise status pill instead, with a meaningful label capped at 40 characters. The chat SSE handler should give the UI a chance to repaint after status updates before appending further logs or assistant content.

## History and dashboard search

HermesiOS includes dashboard-backed History and search views for Hermes sessions.

Important conventions:

- Dashboard HTTP JSON endpoints live in the Hermes dashboard server, not the OpenAI-compatible API server.
- Dashboard `/api/*` routes require the injected `X-Hermes-Session-Token`.
- Native clients can fetch `/`, extract `window.__HERMES_SESSION_TOKEN__`, then call the JSON endpoints.
- Full-conversation search expands grouped `SessionDB.search_messages()` hits into session summaries and messages.
- Resume actions should use the persisted Hermes `session_id`.
- Resume into Responses may require explicit bridge support such as `X-Hermes-Session-Id`, synthesized response-store state, or client-supplied conversation history.
- Friendly titles should be propagated into destination session pills from `title`, `display_title`, `friendly_name`, `name`, `summary`, or metadata variants before falling back to prompt/session-id labels.

History search resume controls should be destination-tab aware:

- Disable Resume in Responses while the Responses session is sending.
- Disable Resume in Chat while the Chat session is sending.
- Guard both expanded-row buttons and compact menu actions at handler level to prevent races.

## Sidebar completion indicators

On iPad, the sidebar can show completion/attention indicators:

- Store unread/completion state in `ContentView`.
- Set indicators when relevant sessions complete.
- Clear the green state when the sidebar row is tapped.
- Preserve the selected row background; only the icon background should turn green.
- Ask Hermes and Chat indicators are driven by their session `connectionStatus == "Completed"` transitions.
- History search indicators are driven by `isSearching` transitioning from `true` to `false`, unless status is `Cancelled`.

## Hermes Office

`HermesOfficeView` embeds the Hermes Office / Studio web experience.

Current behavior:

- The Office header includes a persisted `Claw3D WebView` switch next to the title.
- The switch uses `hermes.office.webView.enabled` and defaults to on.
- When the switch is off, the Office tab shows a disabled-state placeholder, reload is disabled, background preload is skipped, and the shared `WKWebView` is stopped and blanked so Claw3D is cleared from memory.
- Turning the switch back on triggers a fresh reload using the configured Office URL.
- The Office URL remains configured in Settings through `hermes.office.url`, defaulting to `http://localhost:9116`.

Environment notes:

- The dashboard is served through Tailscale at `https://mac-studio.tail4d2ab4.ts.net:9119`.
- On Laurent's Mac, that URL reaches a Host-rewriting proxy LaunchAgent, `fr.dubertrand.hermes-dashboard-host-proxy`, on `127.0.0.1:9120`, forwarding to dashboard `127.0.0.1:9119`.
- Hermes Office / Claw3D gateway traffic is not the same as the OpenAI-compatible API server.
- The Claw3D Hermes adapter LaunchAgent is `fr.dubertrand.hermes-office-adapter` and listens on `127.0.0.1:18790`.
- Studio proxies the adapter at `:9116/api/gateway/ws`.

Do not point Claw3D gateway fields at the HTTP API server on port `8642`. Use the Hermes Office adapter WebSocket path instead.

## Host Companion architecture

Host Companion is the trusted macOS bridge for operations the iOS app cannot safely perform directly.

Primary files:

- `HermesHostCompanion/CompanionProtocol.swift`: shared Codable request/result types.
- `HermesHostCompanion/CompanionServer.swift`: WebSocket dispatch and advertised capabilities.
- `HermesiOS/HermesCompanionClient.swift`: matching iOS client models and request helpers.
- Focused registries such as `CompanionMemoryRegistry`, `CompanionProviderRegistry`, `CompanionProfileRegistry`, `CompanionGatewayRegistry`, `CompanionScheduleRegistry`, `CompanionGitRegistry`, `CompanionTargetRegistry`, and related registry files.

When adding a host-backed feature:

1. Add Codable payload/result types to the shared protocol.
2. Encapsulate host logic in a focused registry.
3. Advertise the capability in `CompanionServer` hello/capabilities.
4. Dispatch the request in `CompanionServer`.
5. Add matching iOS client structs and methods.
6. Render the SwiftUI panel using the client state.
7. Verify the Host Companion with `swiftc -typecheck HermesHostCompanion/*.swift`.
8. Verify the iOS side with an iPhone/iPad simulator SDK typecheck or Xcode build.

### Enrollment and TLS

Enrollment uses a pinned Host Companion certificate. If enrollment fails with a generic TLS error:

- Verify URL and port ownership before changing certificate logic.
- Stale `wss://...:9113/enroll` settings can hit Tailscale/IPNExtension and present a Let's Encrypt tailnet cert rather than the pinned Host Companion cert.
- The actual companion enrollment listener has used `:9212`, while API traffic used `:9112`.
- Check `lsof`, app defaults, PKI cert/fingerprint, and unified logs before patching trust code.

## Agent Runtime panels

The Agent Runtime area mirrors Hermes Desktop configuration surfaces through Host Companion APIs.

Current major panels and concepts:

- Memory: edits `memories/MEMORY.md` and `memories/USER.md`, preserving `§` delimiters and size limits.
- Providers: reads/writes provider environment and config safely; secret values are write-only and should never be echoed back to iOS logs or UI.
- Models: manages saved model inventory and runtime routing separately. Runtime routing belongs in `config.yaml` slots such as `model`, `delegation`, and `auxiliary`, not just `models.json`.
- Profiles: lists/creates/edits/deletes/activates Hermes profiles. Default profile lives at `HERMES_HOME`; named profiles live under `profiles/<name>/`.
- Gateway: shows config/env, platform toggles, process status, and service controls without exposing secrets.
- Tools/toolsets: lists and toggles Hermes toolsets through host-side config.
- MCP servers: manages MCP server definitions through Host Companion.
- Skills: lists and toggles Hermes skills.
- Knowledge Eraser: uses a two-phase scan/review/erase workflow for memory/profile/skill knowledge deletion. Scans cover `memories/MEMORY.md`, `memories/USER.md`, and text-oriented files under `skills/`; erase actions must stay Host Companion mediated and should not bypass the review step.
- Schedules: manages Hermes cron schedules and trigger/pause/resume/remove actions.
- Observability: reads bounded host logs for diagnostics.
- Allowlisted Targets: displays targets from Host Companion's persisted target registry, not necessarily from Settings → Host Companion → Hermes workspace path.

Important runtime-panel rules:

- Mirror desktop semantics when possible.
- Do not use direct iOS file access for host Hermes config.
- Use allowlists for writable env keys.
- Preserve unrelated lines and comments when editing `.env` files.
- Avoid logging or summarizing actual secret values.
- For YAML validation, prefer PyYAML from the workspace venv, then the default Hermes venv, then system Python. If PyYAML is unavailable, skip strict validation rather than fabricating YAML errors.

## Settings → Hermes Installation

The Settings tab contains a Hermes Installation section for inspecting and updating the host Hermes Agent checkout.

Core behavior:

- Status compares the local branch with official Hermes Agent main, not arbitrary `origin/main`.
- Official upstream is fetched directly from `https://github.com/NousResearch/hermes-agent.git` into `refs/remotes/hermes-official/main`.
- The current local branch is displayed so Laurent can see which local Hermes Agent change branch is active.
- Pending update state is stored in local git config keys such as:
  - `hermesios.pendingUpdateBranch`
  - `hermesios.pendingUpdateCommit`
  - `hermesios.pendingUpdateConflicts`
  - `hermesios.lastUpdateOutput`

Update workflow:

1. Before fetching official main, the Hermes Update button preserves local working-tree changes on the current local branch.
2. If the target repo is dirty, the companion requires a non-detached branch, runs `git add -A`, and commits with `chore: save local changes before Hermes update`.
3. It then asserts the working tree is clean and no merge is in progress.
4. It fetches official main into `refs/remotes/hermes-official/main`.
5. It probes conflicts with `git merge-tree --write-tree` without touching the working tree.
6. It persists pending review state and disables the update button until the pending update is resolved.

Merge workflow:

- If no conflicts were reported, `Merge Reviewed Update` performs a real merge of the pinned official commit after requiring a clean tree, no merge in progress, and matching branch.
- If conflicts were reported, `Review Conflicts with Hermes` is enabled instead.

Conflict review workflow:

1. The companion starts a real `git merge --no-ff --no-commit <pending-official-commit>`.
2. It enumerates unresolved files with `git diff --name-only --diff-filter=U`.
3. For each conflicted file, it runs `hermes chat -q` from the Hermes Agent repo with the required prompt:
   `Merge those two files in git conflict. They belong to the hermes agent source code. Review the merged file for syntax correctness. Run relevant tests on the hermes agent`
4. The prompt also includes the file path, the `HEAD:<file>` local branch version, and the pending official commit version.
5. After each agent run, the companion verifies conflict markers are gone, stages the file, checks that no unresolved conflicts remain, commits the merge, and clears pending state.

This workflow is implemented primarily in `CompanionGitRegistry.swift`, with protocol/client/UI wiring in `CompanionProtocol.swift`, `CompanionServer.swift`, `HermesCompanionClient.swift`, and `HermesSettingsView.swift`.

## Network and service endpoints

Common endpoints in Laurent's setup:

- Hermes API server: `http://127.0.0.1:8642/v1` locally.
- Tailscale API access: `https://mac-studio.tail4d2ab4.ts.net:8642/v1` when Tailscale Serve is correctly forwarding to `http://127.0.0.1:8642`.
- Dashboard: `https://mac-studio.tail4d2ab4.ts.net:9119` through the Host-rewriting proxy.
- Dashboard local backend: `127.0.0.1:9119`.
- Dashboard Host-rewriting proxy: `127.0.0.1:9120`.
- Host Companion API/enrollment ports may differ; verify with settings/defaults and `lsof` rather than assuming.
- Hermes Office / Claw3D adapter: `127.0.0.1:18790`.

When `/v1/models` returns `401 Invalid API key`, the route/backend is reachable and the issue is authentication. When Tailscale Serve returns `502`, inspect `tailscale serve status` and prefer forwarding explicitly to `http://127.0.0.1:8642` if Hermes is not listening on `::1`.

## Project layout

- `HermesiOS/ContentView.swift`: high-level app composition, tab/sidebar orchestration, parallel Ask Hermes screen state, and Office preload gating.
- `HermesiOS/HermesWorkspaceNavigation.swift`: workspace navigation/sidebar components.
- `HermesiOS/HermesConsoleViews.swift`: shared console UI pieces.
- `HermesiOS/HermesResponsesAPI.swift`: Responses API request/response models.
- `HermesiOS/HermesChatCompletionsAPI.swift`: Chat Completions API request/response models and streaming status-pill event handling.
- `HermesiOS/HermesOfficeView.swift`: embedded Office/Claw3D WebView, persisted URL, reload, and WebView on/off toggle.
- `HermesiOS/HermesDashboardHistorySearch.swift`: dashboard-backed history search.
- `HermesiOS/HermesHistoryView.swift`: history UI.
- `HermesiOS/HermesAgentConfigView.swift`: Agent Runtime surface.
- `HermesiOS/HermesSettingsView.swift`: Settings, Host Companion, service controls, and Hermes Installation controls.
- `HermesiOS/HermesCompanionClient.swift`: iOS client for Host Companion requests.
- `HermesHostCompanion/`: macOS helper, protocol, server, and host-side registries.

## Development conventions

- Swift/iOS builds should be run through Xcode when possible.
- Command-line verification can use `xcodebuild` or `swiftc` with the simulator SDK.
- Host Companion verification:
  `swiftc -typecheck HermesHostCompanion/*.swift`
- iOS typecheck example:
  `SDK=$(xcrun --sdk iphonesimulator --show-sdk-path) && swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios26.0-simulator HermesiOS/*.swift`
- Some existing warnings in `HermesConsoleViews.swift` and `HermesOfficeView.swift` may be unrelated to a focused Settings/Companion change.
- Check `git status --short` after changes and mention any untracked files.
- Do not create local git branches for HermesiOS app source changes unless Laurent explicitly asks.

## Security and privacy rules

- Treat Host Companion as the only trusted bridge for host mutations.
- Do not expose actual secret values in API responses, logs, UI summaries, or final messages.
- Env/secret panels should show present/missing/redacted metadata and write new values without echoing them.
- Validate workspace paths on the host before reading/writing.
- For destructive or stateful operations, keep the scope narrow and report exact files/services affected.

## Getting started

1. Open the Xcode project from `/Volumes/WDBlack4TB/Code/HermesiOS/HermesiOS`.
2. Configure Hermes API settings in the Settings tab.
3. Enroll/authenticate Host Companion before using Agent Runtime panels or host service controls.
4. Use Ask Hermes or Chat for API interactions.
5. Use History to search and resume past Hermes sessions.
6. Use Agent Runtime to manage host Hermes configuration through Companion-backed panels.
7. Use Settings → Hermes Installation to inspect, update, review, and merge the host Hermes Agent checkout safely.
