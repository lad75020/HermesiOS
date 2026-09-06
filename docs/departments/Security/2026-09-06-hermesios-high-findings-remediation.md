# HermesiOS High-Severity Review Remediation

**Date:** 2026-09-06  
**Mode:** Incident remediation  
**Scope:** HermesiOS iOS app and Hermes Host Companion  
**Status:** Remediated and verified

## Incident summary

A read-only security/correctness review identified high-severity weaknesses in authenticated endpoint polling, attachment resource limits, Host Companion workspace/profile containment, configuration backup targeting, and subprocess execution. No secret material was recorded in this audit.

## Remediation scope

### HermesiOS iOS

- Route status polling through the validated API endpoint policy so bearer credentials cannot be sent to an arbitrary plaintext remote host.
- Enforce a 25 MiB attachment invariant at construction and bounded file-read boundaries.
- Keep image attachments bounded and reject unsafe binary or oversized inline HTTP document payloads while preserving normal text/image and TUI attachment workflows.

### Hermes Host Companion

- Restrict file-download roots to trusted configured Hermes roots rather than caller-provided workspace paths.
- Validate profile names and resolved direct-child containment, including symlink rejection.
- Keep configuration-target selection request-scoped, bind backups to their original target, and migrate only legacy records that can be associated safely.
- Prevent backup identifier collisions and revision-check races around asynchronous validation.
- Route child-process execution through bounded asynchronous capture with timeout and process-tree cleanup so Host requests cannot block the main actor or consume unbounded output storage.

## Test-oracle record

Regression tests were introduced for the unsafe variants before the corresponding hardening. Negative controls reproduced plaintext endpoint rejection gaps, oversized attachment construction/read paths, profile traversal/symlink paths, unsafe backup association/collision, revision races, and subprocess output/timeout behavior.

## Verification record

Completed verification:

- HermesiOS: 163 tests passed; build-for-testing succeeded through XcodeMCP.
- Hermes Host Companion: 48 tests passed with zero failures; build-for-testing succeeded through XcodeMCP.
- Python verification: 25 tests passed.
- Static Host scan found no direct `Process`, `Pipe`, `waitUntilExit`, or `readDataToEndOfFile` usage; subprocess execution is centralized in the bounded POSIX runner.
- `git diff --check` passed.
- Codebase-memory index refreshed.

- Live Host reload: the new debug build (PID 42002) owns `127.0.0.1:9312`.
- Tailscale Serve forwards tailnet-only TCP 9312 to `127.0.0.1:9312`; a TCP probe to the tailnet IPv4 address succeeded after the operator restarted proxying.

## Release note

Internal security hardening only. No navigation, controls, settings, protocol names, or normal user workflows are intentionally changed. Unsafe remote plaintext credential delivery, out-of-scope filesystem access, ambiguous backup restore, stale concurrent writes, and unbounded child-process behavior now fail closed.
