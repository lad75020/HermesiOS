# Quickstart: Host Companion Service

## Objective

Validate host companion protocol, authorization, target editing, file access, and runtime-management operation flows from a fresh build without altering unrelated app logic.

## Prerequisites

- Branch: `feature/time-machine-host-companion`
- `HermesiOS` app and `HermesHostCompanion` app installed for local simulation or device testing.
- Valid `.hermes` workspace available on host.

## 1) Start companion host and verify onboarding surface

1. Open `HermesHostCompanion` app and start the server.
2. Confirm:
   - state is `Running`.
   - endpoint and host/port controls match expected values.
   - current onboarding QR and onboarding code are visible.
3. Note API URL from the server details.

## 2) Onboard and enroll an iOS device

1. On iOS, open Host Companion pairing path and scan the QR.
2. Confirm companion enrollment request succeeds and appears in the Mac device list as pending.
3. Approve the device in host UI.
4. On iOS, verify identity status updates to approved.

Expected result:

- Device moves from pending to approved.
- Polling check of approval (`check_device_approval`) succeeds.

## 3) Exercise target browsing, validation, save, backup

1. In iOS companion panel, load target list (`list_targets`).
2. Open a target (for example `hermes-config`) and capture its revision.
3. Trigger target validation; assert diagnostic list is returned and success state is stable.
4. Edit target content with a non-breaking change and save with create-backup enabled.
5. Confirm returned revision advances and backup is recorded.

Expected result:

- Revision changes on successful write.
- Backup list contains a new backup entry.

## 4) Test stale write and validation failures

1. Re-open an older revision ID and attempt `write_target`.
2. Confirm response is `revisionMismatch` or equivalent error.
3. Introduce malformed YAML and call validate/write.
4. Confirm operation returns typed validation diagnostics and write is blocked.

Expected result:

- No file write on stale/malformed content.
- Client receives clear error status.

## 5) Backups and restore

1. List backups for a target.
2. Restore a known backup.
3. Re-open target and verify restored content and updated revision.

Expected result:

- Restored payload is valid and applied.
- Revision updates after restore.

## 6) Directory and file retrieval flow

1. Browse path(s) from a valid workspace location.
2. For a small file, call download and inspect content payload and byte count.
3. For a large file, call `download_file_info`, then iterate `download_file_chunk` until `isComplete=true`.

Expected result:

- Directory entries include names, type, optional size.
- Chunk metadata (offset/byteCount/totalByteCount/isComplete) is consistent.

## 7) Service status and lifecycle controls

1. Query linked services list and call:
   - `service_status`
   - `service_restart`
2. Confirm status and output reflect post-operation state.

Expected result:

- Service status transitions are returned and no session drop occurs on failed operations.

## 8) Tailscale serve and service ports

1. Query tailscale status for the API/dashboard port.
2. Toggle serve state.
3. Reload service ports and verify UI values are reflected.

Expected result:

- Tailscale status output/boolean reflect toggle.
- ports persist and can be read from companion.

## 9) Runtime management smoke checks

1. Refresh companion runtime sections in iOS:
   - skills
   - tools
   - provider/model
   - memory
   - schedules
   - gateway config/status
   - logs
2. Execute one safe non-destructive action per section (for example: list-only or status query).

Expected result:

- Runtime session fields update without UI deadlock.
- Non-mutating operations succeed and populate corresponding arrays/state markers.

## 10) Negative security checks

1. Send an unsupported operation type manually (if your test harness allows it).
2. Send a malformed envelope.
3. Use unapproved device credentials on a protected operation.

Expected result:

- Protected operations return error envelope without connection teardown.
- `invalid_request` / authorization code returned with stable request/response shape.
