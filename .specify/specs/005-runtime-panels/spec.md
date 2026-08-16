# Specification: Agent Runtime Panels

Feature ID: `runtime-panels`

## Summary

The Agent Runtime Panels feature provides a unified control plane in the iOS app to inspect and configure Hermes runtime behavior on the paired macOS Host Companion.

Users can configure memory, model routing, provider credentials/configuration, profiles, toolsets, MCP servers, schedules, observability, and skills directly from their iOS device once the host companion is approved.

## User Stories

- As a user, I can inspect current companion enrollment, connection state, and runtime health from the Runtime Panels section.
- As a user, I can read and edit memory settings, user profile content, and memory provider configuration for the host workspace.
- As a user, I can configure primary and auxiliary model routing (provider/model/base URL) and quickly apply updates.
- As a user, I can manage provider credentials and environment configuration for model integrations.
- As a user, I can view and edit runtime profiles, create new profiles, and switch active profile context.
- As a user, I can enable or disable Hermes toolsets used by the assistant runtime.
- As a user, I can add, remove, and inspect MCP servers (stdio and streamable HTTP) from the host list.
- As a user, I can manage scheduled jobs (create, trigger, pause/resume, delete), and monitor schedule health.
- As a user, I can inspect live observability logs and adjust log window size.
- As a user, I can enable/disable skills that runtime should expose to the agent.
- As a user, all panel actions should clearly indicate busy states and errors when host companion is unavailable or enrollment is missing.

## Functional Requirements

- The UI shall require host companion enrollment before exposing sensitive edit actions in all runtime panels.
- The feature shall expose the following panel groups, each with clear read-and-write entry points:
  - Memory panel
  - Model panel
  - Provider panel
  - Profiles panel
  - Tools panel
  - MCP Servers panel
  - Schedules panel
  - Observability panel
  - Skills panel
- The feature shall display live counts/summaries (sessions, messages, configured models, active jobs, enabled skills, etc.) where available.
- The feature shall support refreshing data from the host companion for each panel section.
- The feature shall surface actionable results and errors returned from companion commands, preserving actionable text for user diagnostics.
- The feature shall provide guardrails when unauthenticated (authentication required placeholders/messages) and not perform privileged writes until approved.
- The feature shall support creating and editing profile, model, and provider settings with validation-friendly controls.
- The feature shall support MCP server operations including adding, listing, and deleting.
- The feature shall support scheduled-task lifecycle controls and observability log viewing with configurable line limits.
- The feature shall synchronize toggles/commands back to host-side runtime registries through existing companion session operations.

## Success Criteria

- Companion enrollment gating is enforced and user-visible across all runtime sub-panels.
- Core settings are readable and updatable in all supported sub-panels without crashes.
- Memory/model/provider/profile/toolset/tool/MCP/schedule/observability/skills sections update in response to host-side state changes.
- User-friendly status messaging and error surfaces are present for failed commands and invalid inputs.
- No UI path crashes when lists are empty or when host returns partial/empty payloads.

## Files in Scope

- `HermesiOS/HermesiOS/HermesMemoryPanel.swift`
- `HermesiOS/HermesiOS/HermesModelsPanel.swift`
- `HermesiOS/HermesiOS/HermesProvidersPanel.swift`
- `HermesiOS/HermesiOS/HermesProfilesPanel.swift`
- `HermesiOS/HermesiOS/HermesToolsPanel.swift`
- `HermesiOS/HermesiOS/HermesMCPServersPanel.swift`
- `HermesiOS/HermesiOS/HermesSchedulesPanel.swift`
- `HermesiOS/HermesiOS/HermesObservabilityPanel.swift`
- `HermesiOS/HermesiOS/HermesSkillsPanel.swift`

## Assumptions

- Host Companion pairing has been completed in Settings.
- Companion runtime endpoint returns compatible response payloads for the relevant management operations.
- Companion-side storage and registries are writable when the session is approved.

## Edge Cases

- Empty lists (no memories, no profiles, no MCP servers, no schedules, no skills) should render clear empty states.
- Companion-unenrolled state should block edits and show explicit guidance.
- API/command failures should be surfaced and recoverable via refresh.
- Invalid cron-like schedule inputs should be normalized or rejected before execution.
- Environment key entries should preserve secret-like values safely in UI controls and update host keys correctly.
- Concurrent operations should not leave stale output states in visible rows.
