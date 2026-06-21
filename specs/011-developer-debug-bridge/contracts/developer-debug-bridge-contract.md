# Contract: Developer Debug Bridge

## User-Facing Contract

- The feature is reachable from the HermesiOS app shell when relevant navigation is available.
- The feature shows clear loading, empty, success, unavailable, and failure states where applicable.
- The feature avoids displaying raw secrets, bearer values, private file contents, or raw debug payloads in normal summaries.
- The feature preserves expected local context when the user navigates away and returns.

## Scope Contract

- Source or resource changes stay within: HermesiOS/GstackDebugBridges.swift, HermesiOS/GstackDebugStateServer.swift.
- Unrelated Time Machine feature areas remain unchanged.
- Any future source fix must preserve the existing successful Xcode build baseline.
