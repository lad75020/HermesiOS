# Settings and Reachability Contract

## Settings Contract

- Users can view and edit host, port, profile, and credential-related settings from a dedicated Settings surface.
- Sensitive values are accepted through explicit input controls but are not shown in plain summaries after saving.
- Clearing a credential removes the active value used by future requests.
- QR onboarding can populate supported host and companion fields, but the resulting endpoints still pass normal validation.

## Endpoint Security Contract

- Loopback development endpoints may use plaintext when they do not leave the device/Mac development boundary.
- Non-loopback plaintext endpoints that would carry tokens, prompts, files, session data, or host-control data are rejected or require a safer transport.
- Malformed URLs, missing hosts, invalid ports, and unsupported schemes return actionable user-facing errors.

## Reachability Contract

- Each configured core service can be represented as unknown, checking, reachable, unreachable, or degraded.
- Reachability checks do not block the shell or the ability to correct settings.
- Status messages do not echo credentials or raw secret-bearing headers.
