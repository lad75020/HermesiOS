# Agent Runtime native workspace

## Outcome

`HermesAgentConfigView` is now a category workspace rather than an accordion wall.
On iPhone and narrow iPad multitasking widths it presents an overview that pushes one
detail at a time through the parent `NavigationStack`. At 720pt and above on regular
width iPad it uses a persistent category rail beside the detail, implemented as an
`HStack` rather than a nested `NavigationSplitView`.

The workspace has a local **Runtime edit scope** selector populated only from the
authenticated `list_profiles` response. Selecting it derives a copy of the companion
settings with that listed profile path, resets runtime section data/load state, and
does not change Hermes' sticky host-wide active profile. Profiles management itself
continues to use the root workspace. The header distinguishes device approval from a
successful request; approval is not presented as a live connection.

Each category now has its own load-error state. A failed request is explicitly shown
as **Load failed**, while a zero count is only shown after that category loaded.

As part of the safety pass, gateway and provider password fields no longer offer a
"Show" control: secret values stay in `SecureField` inputs and are only submitted to
the Host Companion. Save/remove operations keep their existing response-driven state
updates and explicit success feedback without echoing secret material.

## Desktop control parity

Desktop evidence was read from `web/src/pages/{ProfilesPage,ChannelsPage,SkillsPage,
McpPage,CronPage,ModelsPage}.tsx` and the iOS panels and Host Companion client were
checked before changing the shell. The table records functional parity through the
existing Host Companion protocol rather than a visual imitation.

| Primary area | Desktop controls evidenced | Native panel and current behavior | Scope / safety notes |
| --- | --- | --- | --- |
| Profiles | Create, select active, edit model/description/SOUL, rename, delete | `HermesProfilesPanel`: lists, creates, edits model settings, selects and deletes with confirmation | Active profile appears in the workspace header and every detail header. |
| Messaging gateways | Configure fields, enable/disable, test, restart gateway, channel onboarding | `HermesGatewayPanel`: platform enablement, gateway lifecycle, host field saves and explicit post-save state | Sensitive fields use the existing `SecureField` flow and no displayed value is read back. |
| Tools | Toolset configuration and enablement | `HermesToolsPanel`: searchable list and live toggle | Loaded marker prevents an unloaded toolset list being presented as zero. |
| Skills | Search, create/edit SKILL.md, enable/disable | `HermesSkillsPanel`: full-text filtered list and live enabled-state toggle | The companion discovers the selected profile through Hermes helpers and persists enablement through `skills.disabled`; skill creation/editing is not exposed. |
| MCP servers | Add stdio/HTTP, OAuth, enable/disable, test, delete | `HermesMCPServersPanel`: searchable list, add stdio/streamable HTTP/OpenAPI, bearer-token input, remove confirmation | List/add/remove are scoped to the selected Hermes profile and return only sanitized metadata. OAuth, enabled-state, catalog install, and live test remain desktop-only. |
| Provider API keys | Provider/config selection and credential pool | `HermesProvidersPanel`: write-only provider env inputs, removal, credential-pool management, default model | Secret values are never read or echoed; only configured/present metadata is surfaced. |
| Scheduled cron jobs | Create/edit schedule, prompt, provider/model, skills/tools, trigger/pause/resume/delete | `HermesSchedulesPanel`: create/edit raw schedule, prompt, name, delivery and provider/model pins; trigger/pause/resume/delete | Skill/toolset editing is not exposed. Base-URL mutation is rejected explicitly because the wrapped CLI does not support that flag. |
| Models | Main model and auxiliary routing, model picker, reset/configure slots | `HermesModelsPanel`: main, delegation, and all exposed auxiliary provider/model/base-URL slots | Base URL is persisted for each slot; empty delegation/auxiliary providers preserve inherit semantics. Custom is the endpoint route rather than inventing an auxiliary OpenAI provider. |

## Secondary areas retained

Host Companion enrollment/connection is always reachable from the header and secondary
navigation. Existing Memory, Knowledge Eraser, and Observability panels are retained
as secondary utilities; none of their host operations were replaced by placeholders.

## Verification

- Focused `XCTest` coverage in `HermesiOSTests/HermesRuntimeWorkspaceTests.swift` verifies the exact eight primary categories, companion/utility placement, human-facing category labels, and the 720pt adaptive layout boundary.
- `swiftc -parse` is used for the touched app sources and the full Host Companion source set.
- XCodeMCP: all 20 HermesiOS tests passed on each connected physical device (iPhone and iPad); all 14 Host Companion tests passed on My Mac.
- HermesiOS was installed and launched on both devices, with running processes independently confirmed using devicectl.
- The signed Host Companion build was installed and launched; its listener was verified on 127.0.0.1:9312. The previous application bundle is backed up at `/tmp/HermesHostCompanion-before-runtime-redesign.app`.
- Full visual and interactive device verification remains unconfirmed: Xcode interaction rejected the physical device and the screenshotr service was unavailable. Passing tests and launch checks do not establish end-to-end control behavior against live profiles.

## Known limitations

### Safety follow-up

The corrected Host Companion is installed, its signature and binary hash verified against the tested build, and its listener confirmed on 127.0.0.1:9312. Verification: 22 host XCTest tests, 20 iOS XCTest tests, and 3 fixture-only YAML tests in `docs/test_runtime_yaml_safety.py` pass.

- Legacy credential-pool writes are disabled server-side; use Hermes auth on the host. API-key environment fields remain supported and return presence metadata only.
- Tool toggles preserve other platforms through structured YAML edits. Missing/composite CLI toolset configuration and ambiguous YAML are rejected rather than guessed or overwritten.
- Gateway toggles preserve sibling configuration; restart failures are reported explicitly.
- Profile optional-file toggles no longer delete existing `.env` or `SOUL.md`, and creating optional files creates empty files rather than cloning root secrets.
- These tests use fixtures, not live credentials. End-to-end authenticated device mutation tests remain unverified.

The UI preserves existing host protocol capabilities. Desktop-only controls need a
separate, additive protocol/registry change before they can be claimed on iOS: skill
file editor/create, MCP OAuth/catalog/test/enable, messaging platform live test and
guided QR onboarding, and cron's per-job skills/toolsets editor.
