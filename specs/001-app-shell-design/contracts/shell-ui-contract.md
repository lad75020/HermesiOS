# Shell UI Contract: App Shell and Design System

This contract describes observable behavior for the HermesiOS shell. It is intentionally UI-facing rather than an HTTP or service API contract.

## Launch Contract

- Opening the app presents the launch/splash experience, then reaches the primary workspace shell without indefinite blocking.
- If launch media cannot play or is delayed, the user still reaches the shell.
- The shell can render before Hermes host service reachability is known.

## Navigation Contract

- The shell exposes all configured primary workspace sections in one stable navigation structure.
- Selecting a workspace section updates visible selection state and replaces or updates the primary content area.
- Attention/status decoration can coexist with selection state and follows documented precedence for the shell-level indicator.
- Long section labels or statuses do not break the navigation layout.

## Shared Component Contract

- Shell-level headers, cards, status rows, pills, message surfaces, and navigation elements use consistent hierarchy and spacing.
- Status treatments use consistent meanings across representative shell surfaces.
- Shared components preserve readable text and tappable controls under supported dynamic type and appearance settings.

## Theme and Brand Contract

- Supported appearance modes preserve contrast for primary navigation, cards, status surfaces, and branding.
- Brand assets appear in launch and shell contexts using the appropriate variant or a readable fallback.
- Custom fonts improve presentation but do not become a hard dependency for readability.

## Localization Contract

- Supported locale resources provide localized app metadata and shell-level user-facing labels where translations exist.
- Missing translations fall back to a non-empty default language value.
- Localized labels that expand significantly remain readable or intentionally truncated without layout breakage.

## Offline Host Contract

- If Hermes gateway, dashboard, companion, or office services are unreachable at launch, the shell remains navigable.
- Service-dependent panels may report unavailable status in their own content, but the shell does not crash or hide all navigation.
