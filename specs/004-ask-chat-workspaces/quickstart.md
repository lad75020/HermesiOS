# Quickstart: Validate Ask and Chat Workspaces

## Static Validation

1. Confirm each scoped path exists: HermesiOS/HermesResponsesAPI.swift, HermesiOS/HermesChatCompletionsAPI.swift, HermesiOS/HermesConsoleViews.swift, HermesiOS/HermesResponsesWorkspace.swift, HermesiOS/HermesPromptHistoryStore.swift, HermesiOS/HermesApprovalsInboxView.swift.
2. Inspect the scoped files for feature-relevant state, recovery, and user-facing labels.
3. Confirm normal summaries avoid raw secrets or private payloads.
4. Confirm generated docs contain no unresolved placeholders.

## Build Validation

1. Use XCodeMCP or Xcode to build the HermesiOS scheme.
2. Confirm the build succeeds or record the exact blocker.
3. Because this retrospective pass changes documentation only, a successful build on the same source tree remains the compile baseline unless a future source fix is added.

## Runtime Validation

1. Open HermesiOS and navigate to the Ask and Chat Workspaces surface if available.
2. Exercise the primary success path.
3. Exercise unavailable or invalid-input state.
4. Confirm the feature remains consistent with shared shell, appearance, and localization behavior.
