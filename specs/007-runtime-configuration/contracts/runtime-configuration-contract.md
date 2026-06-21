# Contract: Agent Runtime Configuration

## User-Facing Contract

- The feature is reachable from the HermesiOS app shell when relevant navigation is available.
- The feature shows clear loading, empty, success, unavailable, and failure states where applicable.
- The feature avoids displaying raw secrets, bearer values, private file contents, or raw debug payloads in normal summaries.
- The feature preserves expected local context when the user navigates away and returns.

## Scope Contract

- Source or resource changes stay within: HermesiOS/HermesRuntimeComponents.swift, HermesiOS/HermesAgentConfigView.swift, HermesiOS/HermesMemoryPanel.swift, HermesiOS/HermesProvidersPanel.swift, HermesiOS/HermesModelsPanel.swift, HermesiOS/HermesProfilesPanel.swift, HermesiOS/HermesGatewayPanel.swift, HermesiOS/HermesToolsPanel.swift, HermesiOS/HermesMCPServersPanel.swift, HermesiOS/HermesSkillsPanel.swift, HermesiOS/HermesSchedulesPanel.swift, HermesiOS/HermesObservabilityPanel.swift, HermesiOS/HermesKnowledgeEraserPanel.swift, HermesHostCompanion/CompanionMemoryRegistry.swift, HermesHostCompanion/CompanionProviderRegistry.swift, HermesHostCompanion/CompanionModelRegistry.swift, HermesHostCompanion/CompanionProfileRegistry.swift, HermesHostCompanion/CompanionGatewayRegistry.swift, HermesHostCompanion/CompanionToolsetRegistry.swift, HermesHostCompanion/CompanionMCPRegistry.swift, HermesHostCompanion/CompanionScheduleRegistry.swift, HermesHostCompanion/CompanionTargetRegistry.swift, HermesHostCompanion/CompanionKnowledgeEraserRegistry.swift, HermesHostCompanion/CompanionFileDownloadRegistry.swift.
- Unrelated Time Machine feature areas remain unchanged.
- Any future source fix must preserve the existing successful Xcode build baseline.
