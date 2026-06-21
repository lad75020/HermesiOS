# Contract: Host Services and Installation

## User-Facing Contract

- The feature is reachable from the HermesiOS app shell when relevant navigation is available.
- The feature shows clear loading, empty, success, unavailable, and failure states where applicable.
- The feature avoids displaying raw secrets, bearer values, private file contents, or raw debug payloads in normal summaries.
- The feature preserves expected local context when the user navigates away and returns.

## Scope Contract

- Source or resource changes stay within: HermesHostCompanion/CompanionServiceRegistry.swift, HermesHostCompanion/CompanionLogRegistry.swift, HermesHostCompanion/CompanionTailscaleServeRegistry.swift, HermesHostCompanion/CompanionGitRegistry.swift, scripts/deploy-hermesios.mjs, scripts/deploy_hermesios_stack.py.
- Unrelated Time Machine feature areas remain unchanged.
- Any future source fix must preserve the existing successful Xcode build baseline.
