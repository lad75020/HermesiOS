# HermesiOS Developer Guide

This guide covers the local development workflow for HermesiOS: repository
layout, building the two targets, debugging aids, and the main extension points.

## Prerequisites

- macOS with Xcode 16 or newer (project targets modern OS versions).
- Apple Silicon Mac recommended for building and running the macOS companion.
- A running Hermes Agent backend on the Mac for end-to-end testing (see the
  deployment guide).

Deployment targets and toolchain (from `HermesiOS.xcodeproj/project.pbxproj`):

- `IPHONEOS_DEPLOYMENT_TARGET = 26.4` (HermesiOS iOS client)
- `MACOSX_DEPLOYMENT_TARGET = 26.0` (HermesHostCompanion)
- `SWIFT_VERSION = 5.0`, `MARKETING_VERSION = 1.0`
- Bundle identifiers `fr.dubertrand.HermesiOS` and
  `fr.dubertrand.HermesHostCompanion`

## Repository layout

```text
HermesiOS/                     (git root)
  HermesiOS.xcodeproj
  HermesiOS/                   iOS/iPadOS client sources
    HermesiOSApp.swift         @main entry point
    ContentView.swift          root view / sidebar host
    HermesWorkspaceNavigation.swift  WorkspaceSection model
    HermesResponsesAPI.swift   /v1/responses client + attachments
    HermesChatCompletionsAPI.swift   /v1/chat/completions client
    HermesTUIGatewayView.swift dashboard TUI Gateway client
    HermesCompanionClient.swift companion WebSocket client
    HermesHostEndpoints.swift  endpoint builders + transport security
    HermesSettingsPersistence.swift  UserDefaults + Keychain storage
    Hermes*Panel.swift         runtime panels (models, providers, ...)
    Assets.xcassets, Fonts/, Resources/, *.lproj (localizations)
  HermesHostCompanion/         macOS helper sources
    HermesHostCompanionApp.swift
    CompanionServer.swift      NWListener WebSocket server + routing
    CompanionProtocol.swift    wire envelopes and payload types
    Companion*Registry.swift   one handler per operation prefix
  README.md                    detailed install/deploy reference
```

Localizations exist for English, French, Spanish, German, and Simplified Chinese
(`*.lproj` plus `Localizable.xcstrings`).

## Building

Open the project in Xcode:

```sh
open HermesiOS.xcodeproj
```

- Select the `HermesiOS` scheme to build and run the iOS client on a simulator
  or device.
- Select the `HermesHostCompanion` scheme to build and run the macOS helper.

Command-line build checks:

```sh
xcodebuild -project HermesiOS.xcodeproj -scheme HermesiOS build
xcodebuild -project HermesiOS.xcodeproj -scheme HermesHostCompanion build
```

When deploying the iOS client to a physical device, configure Xcode signing for
the `HermesiOS` target first.

## Debugging aids

The iOS app wires debug-only instrumentation under `#if DEBUG` in
`HermesiOSApp.init()`:

- `StateServer.shared.start()` exposes a local debug state server.
- `DebugBridgeUIWiring.installAll()` installs UI element bridges (UIKit).

These are compiled out of release builds. The related sources are
`GstackDebugStateServer.swift` and `GstackDebugBridges.swift`.

Runtime visibility during development also comes from the in-app Observability
panel, Background Activity, Schedules, the Approvals Inbox, and the companion
`log.tail` operation.

## Testing

There is no automated XCTest suite in the repository at documentation time; the
code graph contains no test nodes. Validate changes by building both schemes and
exercising the affected workspace against a live Hermes backend and companion.
When adding tests, create a standard XCTest target in the Xcode project.

## Extension points

### Add a companion operation

1. Choose or add a registry prefix. Existing prefixes are registered in
   `CompanionServer.registryPrefixes` and backed by a `Companion*Registry`.
2. In the target registry's `handle(...)` switch, add a `case "<prefix>.<verb>"`
   that decodes its payload type and returns a result payload.
3. Define the request/result `Codable` payload structs in
   `CompanionProtocol.swift`.
4. Add a client call in `HermesCompanionClient` (or the relevant panel) that
   sends a `CompanionIncomingEnvelope` with the new `type`.
5. If the operation must work before device approval, add it to
   `CompanionProtocol.isUnauthenticatedOperation` (only do this for onboarding
   or capability-negotiation operations).

### Add a workspace section

1. Add a case to `WorkspaceSection` and provide its `title`, `subtitle`, and
   `systemImage`.
2. Render the new section in `ContentView`/the sidebar and wire any attention or
   unread state it should surface.

### Add an endpoint or transport rule

Endpoint URL building and the plaintext-transport policy live in
`HermesHostEndpoints.swift` (`HermesHostEndpoints` and `HermesEndpointSecurity`).
Extend those helpers rather than constructing URLs ad hoc, so the loopback and
tailnet transport rules stay enforced.

## Coding conventions

- SwiftUI with `@MainActor` view models and `Observable`/`ObservableObject`
  stores.
- Networking through `URLSession` with typed `Codable` request/response models.
- Never send credentials over plaintext to non-loopback, non-tailnet hosts; use
  the `HermesEndpointSecurity` helpers.
- Keep privileged host mutations in the companion, not the iOS client.
