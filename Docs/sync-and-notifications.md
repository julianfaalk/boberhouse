# Sync & Notifications Blueprint

## Goals
- Keep two personal devices in near-real-time sync while maintaining full offline capability.
- Support alternating task assignment deterministically on every device.
- Deliver timely reminders and updates for new or reassigned occurrences via APNs.

## Data Flow Overview
1. **Local-first**: SwiftData is the source of truth on-device. Every change increments `syncRevision` and records `updatedAt`.
2. **Sync Envelope**: Devices exchange batched updates with the server using the DTOs in `SyncService.swift`.
3. **Conflict Resolution**:
   - Templates & Members: latest `updatedAt` wins.
   - Occurrences: latest `dueDate`/`status` pair wins unless there is a terminal state (`completed` or `skipped`), which is immutable once recorded.
   - Completion Events: append-only, deduplicated by UUID.
4. **Assignment Engine**: Each device deterministically assigns future tasks using the alternation engine + completion history, ensuring consistent results after sync.

## Server Responsibilities
- Persist the same schema (SQLite or Postgres) with monotonic `revision` numbers.
- Expose REST endpoints:
  - `GET /sync?since=<revision>` → returns `SyncEnvelope`.
  - `POST /sync` → accepts client delta (with `baseRevision`) and responds with new server revision.
- Authenticate with signed API key (simple header, no full auth needed).
- Validate:
  - Preserve UUIDs from clients.
  - Reject occurrence updates that downgrade a terminal status.
  - Ensure alternating assignments stay consistent by echoing server-side recomputed values when conflicts are detected.

## Push Notification Flow
1. App registers for APNs and POSTs device token to server (`POST /devices` with member UUID + token).
2. Server triggers pushes when:
   - A new occurrence is created or reassigned.
   - A completion or skip is recorded by the other device.
   - Lead-time reminder window opens (`dueDate - leadTimeHours`).
3. Payload includes occurrence ID, template title, due timestamp, and assigned member ID so the app can deep-link directly to the task.

## Suggested Stack
- **Server**: Vapor 4 (Swift) or Fastify (Node) – choose whichever matches operator comfort. Both pair cleanly with SQLite/Postgres.
- **Database**: SQLite if load is minimal; migrate to Postgres for better concurrency and revision tracking.
- **APNs**: Use `apns` package (Node) or `APNSwift` (Vapor) with a token-based (.p8) auth key.

## Sync Cadence
- Foreground pull on app launch and after significant user actions.
- Background fetch every 2–3 hours via `BGAppRefreshTask`.
- Push-triggered pull: notification with `content-available = 1` to kick off silent refresh.

## Open Questions
- How aggressively should we prune historical occurrences? (Consider server-side archival policy.)
- Do we need manual reassignment tools when alternation logic is overridden?
- Should reminders respect quiet hours or shared calendar availability?
