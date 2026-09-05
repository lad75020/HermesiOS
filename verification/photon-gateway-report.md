# Photon gateway — bounded implementation evidence

## Outcome

- Added `photon` / Photon iMessage to Host Companion's catalog, distinct from BlueBubbles.
- Allowlisted eight verified runtime env fields: `PHOTON_PROJECT_ID`, `PHOTON_PROJECT_SECRET`, `PHOTON_ALLOWED_USERS`, `PHOTON_HOME_CHANNEL`, `PHOTON_HOME_CHANNEL_NAME`, `PHOTON_SIDECAR_PORT`, `PHOTON_REQUIRE_MENTION`, `PHOTON_MENTION_PATTERNS`.
- Secret uses password UI metadata; every returned env value remains `[configured]`, including text fields. No real config, env or auth file was read/written for this work.
- Matched raw YAML precedence: `gateway.platforms.<key>` → `platforms.<key>` → `gateway.<key>`. Toggle the highest-precedence existing block, preserving unrelated values; explicit false survives plugin env auto-enablement. Existing safe-loader rejection, round-trip checking and atomic persistence remain. YAML formatting/comments are not round-tripped by the existing PyYAML safe-dump design.
- No iOS production/layout changes: HermesGatewayPanel already renders host-provided platform/field catalogs and uses empty local drafts.
- No commits, deployment, gateway starts/stops/restarts, or real credential changes.

## Contract sources (read-only)

Under `/Volumes/WDBlack4TB/.hermes/hermes-agent/`:

- `plugins/platforms/photon/adapter.py:1590–1604`: plugin registration, required env, allowed users, cron home channel.
- `plugins/platforms/photon/adapter.py:280–290,485–494,526–541`: credential/home seeding, port and mention settings.
- `gateway/config_loader.py:122–153`: YAML merge precedence and explicit-enabled marker.
- `gateway/config_env.py:382–393`: explicit-disabled guard before credential probing.
- `website/docs/user-guide/messaging/photon.md`: setup, Node sidecar prerequisites and env documentation.

## Changed by this task

- `HermesHostCompanion/CompanionGatewayRegistry.swift`: Photon catalog/fields and injectable lifecycle command runner for safe fixture execution.
- `HermesHostCompanion/CompanionRuntimeConfigSafety.swift`: only listPlatforms/setPlatform branch. Concurrent STT edits in this same file were preserved.
- `HermesHostCompanionTests/CompanionPhotonGatewayTests.swift`: four fixture tests exercising real registry reads/writes, field allowlist, metadata redaction, profile isolation, traversal/symlink rejection and malformed YAML preservation.
- `HermesiOSTests/HermesPhotonGatewayTests.swift`: two catalog/payload compatibility tests.
- `Tests/test_photon_gateway.py`: five exact embedded-transformer/catalog tests.
- This report.

## Verification

XCodeMCP workspace: `windowtab-mLWQGVnGiC`.

### Host

BuildProject(buildForTesting: true), HermesHostCompanion / My Mac: successful, zero errors.

`/var/folders/gq/fj68kcfn2t1fb21qqrt6b44h0000gn/T/ActionArtifacts/default/BuildProject/BuildProject-Log-20260905-074414.txt`

RunSomeTests, CompanionPhotonGatewayTests: **4 passed, 0 failed, 0 skipped, 0 not run**.

- Summary: `/var/folders/gq/fj68kcfn2t1fb21qqrt6b44h0000gn/T/ActionArtifacts/default/RunSomeTests/95DF147E-F739-459F-9B91-56096D5DAE0F.txt`
- Result: `/var/folders/gq/fj68kcfn2t1fb21qqrt6b44h0000gn/T/ActionArtifacts/default/RunSomeTests/Test-HermesHostCompanion-2026.09.05_07-45-05-+0200.xcresult`

First fixture attempt had two failures (URL trailing-slash comparison and symlinked venv losing PyYAML lookup). Fixed test harness by comparing paths and execing the original venv Python from a fixture launcher; final four all executed and passed.

### iOS

BuildProject(buildForTesting: true), HermesiOS / iPhone 17 simulator: successful, zero errors.

`/var/folders/gq/fj68kcfn2t1fb21qqrt6b44h0000gn/T/ActionArtifacts/default/BuildProject/BuildProject-Log-20260905-074551.txt`

RunSomeTests, HermesPhotonGatewayTests: **2 selected, 0 passed, 0 failed, 2 not run** on both iPhone 17 and already-booted iPhone 17 Pro. Infrastructure error: "Failed to clone device ... Device was allocated but was stuck in creation state."

- Latest completed summary: `/var/folders/gq/fj68kcfn2t1fb21qqrt6b44h0000gn/T/ActionArtifacts/default/RunSomeTests/9012DD49-BF23-41D3-B614-BCF2335AF726.txt`
- Console: `/var/folders/gq/fj68kcfn2t1fb21qqrt6b44h0000gn/T/ActionArtifacts/default/RunSomeTests/test-console-log-2026-09-05T07-46-34+02-00.txt`
- Result: `/var/folders/gq/fj68kcfn2t1fb21qqrt6b44h0000gn/T/ActionArtifacts/default/RunSomeTests/Test-HermesiOS-2026.09.05_07-46-34-+0200.xcresult`

A serial retry (temporarily disabling scheme test parallelization) timed out at the MCP 60-second limit; no test result was returned. The scheme flag was restored and `git diff` for the scheme is empty. A sibling agent was also modifying the scheme during this retry; parent should serialize further Xcode verification and inspect any still-running test session. No iOS passing-test claim is made.

### Other checks

- `swiftc -parse HermesHostCompanion/*.swift`: exit 0.
- Python: five new Photon tests and three existing YAML safety tests pass. Evidence `/tmp/hermes-photon-green.txt`; expected initial red evidence `/tmp/hermes-photon-red.txt` (three failures proving missing catalog/nested semantics).
- `git diff --check`: exit 0.
- SHA-256 comparison against start: all five pre-existing dirty attachment/keyboard files unchanged. Other concurrent STT changes left untouched.

## Remaining deployment/acceptance

1. Parent must complete the two iOS XCTests after resolving simulator/Xcode test infrastructure; do not count No result or timeout as passing.
2. Deploy/relaunch the updated Host Companion to expose the catalog to the existing iOS panel. No production iOS source change is required for Photon listing.
3. If Photon is not yet provisioned, the user must run `hermes photon setup` on the intended host/profile (device login, account/line registration and sidecar installation). This task does not perform that setup.
4. Gateway restart after runtime env edits is required as described by the field hints; catalog deployment itself does not change the Python gateway source. No live Photon send/receive or visual QA was attempted.
