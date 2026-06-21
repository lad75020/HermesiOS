# Quickstart: Validate App Shell and Design System

## Prerequisites

- Xcode installed with the configured iOS/iPadOS simulator or device runtime.
- Repository opened at `/Volumes/WDBlack4TB/Code/HermesiOS/HermesiOS`.
- `HermesiOS` scheme available in the Xcode project.

## Build Validation

1. Build the `HermesiOS` target for a simulator or configured device.
2. Confirm the build succeeds or record the exact compiler/resource/signing blocker.
3. If Xcode user-state files change during inspection, treat them as incidental UI state and do not include them as feature artifacts.

## Runtime Shell Smoke Check

1. Launch HermesiOS.
2. Confirm the app transitions from launch/splash to the primary workspace shell in under 5 seconds on a normally responsive device.
3. Confirm the main navigation area and content area are visible before any successful Hermes host connection is required.
4. Select at least three workspace sections and confirm selected state and content transitions remain clear.

## Offline Host Scenario

1. Run the app with Hermes host services unreachable or with invalid/unavailable host endpoints.
2. Confirm the shell remains navigable.
3. Confirm service-specific unavailability is contained to status indicators or panel content rather than blocking the shell.

## Appearance Scenario

1. Validate the shell in light appearance.
2. Validate the shell in dark appearance.
3. If an app-level theme setting is available, switch through supported theme choices.
4. Confirm navigation labels, selected states, shared cards, status rows, and brand assets remain legible.

## Localization Scenario

1. Run the app using each supported localization represented in project resources when feasible: English, French, German, Spanish, and Simplified Chinese.
2. Confirm app metadata and shell-level labels are non-empty and understandable.
3. Confirm longer localized labels do not break the primary navigation layout.

## Shared Component Scenario

1. Visit at least three panels that use shared shell components.
2. Confirm headers, cards, status rows, status pills, and message surfaces use consistent spacing, typography, and state treatment.
3. Confirm long text uses intentional wrapping, truncation, or marquee behavior.
