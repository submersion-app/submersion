# iCloud Sync for All Structured Data — Design

- Date: 2026-06-01
- Status: Approved (design); implementation not started
- Owner: Eric
- Related: replaces the abandoned encrypted multi-device sync effort (dropped 2026-06-01). This work revives and completes the existing plaintext v1.5 cloud sync.

## 1. Background

Submersion already contains a substantial, mostly-complete cloud sync engine for a
single user's data across their own devices. It serializes the database to a single
JSON snapshot (`submersion_sync.json`, SHA-256 checksummed) and merges remote changes
using record-level last-write-wins keyed on each row's `updatedAt`. An iCloud storage
provider is fully implemented over a native ubiquity-container bridge (iOS/macOS); a
Google Drive provider also exists behind the same `CloudStorageProvider` abstraction.

Two problems block it today:

1. **It is not reachable in the UI.** `CloudSyncPage` exists but is orphaned: there is
   no `/settings/cloud-sync` route and no Settings tile/section wiring it up.
2. **It did not actually sync.** Per the owner, an earlier attempt "simply didn't sync
   anything" — the round-trip (export -> upload -> discover -> download -> merge -> apply)
   is a no-op or dies at some stage. The cause is not yet known. Note: iCloud ubiquity
   containers do not propagate on the iOS Simulator, so a Simulator-only test could
   produce "nothing synced" with no underlying code defect — this must be ruled in or out.

Key source files (to be re-verified during implementation):

- Serializer: `lib/core/services/sync/sync_data_serializer.dart`
- Orchestrator: `lib/core/services/sync/sync_service.dart`
- Launch checks: `lib/core/services/sync/sync_initializer.dart`
- Change bus / prefs: `lib/core/services/sync/sync_event_bus.dart`, `sync_preferences.dart`
- Sync state repo: `lib/core/data/repositories/sync_repository.dart`
- Provider abstraction: `lib/core/services/cloud_storage/cloud_storage_provider.dart`
- iCloud provider + native bridge: `lib/core/services/cloud_storage/icloud_storage_provider.dart`, `icloud_native_service.dart`
- Riverpod + UI: `lib/features/settings/presentation/providers/sync_providers.dart`, `lib/features/settings/presentation/pages/cloud_sync_page.dart`
- Settings/router wiring: `lib/features/settings/presentation/pages/settings_page.dart`, `settings_list_content.dart`, `lib/core/router/app_router.dart`

## 2. Goals and non-goals

### Goals

- Reliably move all **structured** database records between a user's Apple devices.
- Find and fix the root cause of the no-op round-trip before re-exposing the feature.
- Close data-coverage gaps so every structured table that should sync, does.
- Make it impossible for a future table to silently fall out of sync.
- Re-surface the feature in the UI on iOS/macOS.
- Prove the round-trip on real hardware.

### Non-goals (explicitly out of scope)

- **Media file binaries** (photo/video files referenced by `filePath`). Only their
  structured metadata rows sync. Blob sync is a separate, larger subsystem.
- **Google Drive / Android / Windows / Linux.** iCloud (Apple) only for now. The
  `CloudStorageProvider` abstraction keeps Drive addable later without rework.
- **Encrypted multi-device sync.** Abandoned; not revived here.
- **Rewriting the merge/conflict engine.** We fix and complete the existing design.

## 3. Success criteria

On two Apple devices signed into the same iCloud account, with sync configured on both:

- A create / edit / delete of **any** structured entity on device A appears correctly on
  device B after a sync, for every structured entity type.
- No duplicate records, no lost edits.
- Deletions propagate (a record removed on A is removed on B).
- No crashes or silent failures during sync.
- Verified on **real hardware** (not the Simulator), across a documented entity matrix.

## 4. Architecture (retained)

We keep the current model and do not replace it:

- **Payload:** one `submersion_sync.json` snapshot, SHA-256 checksummed, in the
  "Submersion Sync" folder of the iCloud ubiquity container.
- **Merge:** record-level last-write-wins via `updatedAt`. Rows without `updatedAt`
  (junction tables) accept remote upserts. Conflicts recorded in `SyncRecords`.
- **Transport:** `CloudStorageProvider` -> `ICloudStorageProvider` -> native bridge.
- **Triggers:** manual "Sync Now"; on-launch check; on-change (debounced) and on-resume
  when enabled in `SyncPreferences`.

Conscious limitation: two edits to the **same** record on two devices between syncs will
keep the later write and drop the earlier. This is acceptable for single-user
multi-device use and will be documented rather than engineered around.

## 5. Plan

### Phase 0 — Diagnose the no-op (evidence before any fix)

Add structured, leveled logging at each round-trip boundary and read where it stops:

- export: per-entity record counts, payload size, checksum
- provider: which provider type is selected, whether it is actually persisted across
  relaunch, resolved iCloud container path
- upload: success/failure and the resulting file URL
- remote discovery: what `listFiles` returns (does it find the canonical file?)
- download: byte count and checksum match
- merge: records compared, upserts applied, conflicts, deletions

Make sync triggerable on a real device (temporary dev entry point is acceptable in this
phase). Reproduce on real hardware and explicitly rule the Simulator-propagation
limitation in or out.

Leading hypotheses to check (candidates, not commitments):

- selected provider never persisted/initialized (a provider-persistence gap of the same
  shape known to have existed on the abandoned encrypted path)
- pending-change tracking never populated, so there is "nothing to upload"
- iCloud entitlement / container not provisioned -> silent local-fallback directory that
  never propagates
- remote filename mismatch in discovery
- auto-sync disabled by default with no reachable manual trigger

**Deliverable:** a precise statement of where and why the round-trip fails.
**Checkpoint:** regroup with the owner on findings before coding the fix.

### Phase 1 — Fix the root cause

Determined by Phase 0. Test-driven: write a failing test that reproduces the no-op at the
unit level, make it pass, confirm no regressions. One root cause at a time.

### Phase 2 — Complete data coverage + drift guard

- Add export / upsert / delete handling for the structured tables currently missing it.
  Candidates identified (verify against the serializer): `DiveCustomFields`,
  `DiveDataSources`, `Courses`, `MediaEnrichment`, `MediaSpecies`,
  `PendingPhotoSuggestions`, `MediaSubscriptions` (its schema comment already says
  "synced across devices").
- Classify **every** Drift table as either synced or explicitly excluded, with a reason.
  Proposed exclusions:
  - Sync-control (never sync): `SyncMetadata`, `SyncRecords`, `DeletionLog`.
  - Per-device / local-only: `CachedRegions`, `MediaSubscriptionState`,
    `ConnectorAccounts`, `NetworkCredentialHosts`, `MediaFetchDiagnostics`,
    `ScheduledNotifications`.
  - Judgment calls to confirm during this phase (user preferences that arguably should
    follow the diver): `ViewConfigs`, `FieldPresets`, `CsvPresets`.
- **Drift-guard test:** enumerate all Drift tables and assert each is either in the sync
  registry or in an explicit excluded-set. This converts the hand-maintained parallel
  list into a test-time contract so no future table can silently drop out of sync.
- Per-entity round-trip tests: export -> import -> equal.

### Phase 3 — Re-surface the UI (iOS/macOS)

- Register the `/settings/cloud-sync` route.
- Add a Cloud Sync tile in the Settings Data section, gated to iOS/macOS.
- Honor the existing `isCloudSyncDisabledByCustomFolderProvider` gate.
- Provider selection that is correctly persisted; status / last-sync display; "Sync Now";
  surfacing of conflicts.

### Phase 4 — Verify on hardware

Two-device A<->B verification matrix across every synced entity type plus deletions, on
real Apple hardware. The Simulator cannot validate iCloud propagation.

## 6. Testing strategy

- Unit + per-entity round-trip tests in the serializer (Phase 2).
- The drift-guard coverage test (Phase 2).
- A failing-then-passing regression test for the Phase 1 root cause.
- Integration test exercising the merge/conflict path where feasible.
- Manual hardware verification checklist (Phase 4): for each entity type, create/edit/
  delete on A, sync both, confirm on B; repeat A<->B; confirm deletions propagate.

## 7. Risks and open questions

- **Hardware dependency:** the only authoritative proof needs two Apple devices.
- **iCloud configuration:** entitlement and container identifier must be correct, or
  writes silently land in a local fallback that never propagates.
- **Schema drift:** two devices on different app versions may disagree on the payload
  shape; note behavior and fail safe.
- **LWW data loss edge:** concurrent edits to the same record between syncs lose one;
  documented, not engineered around.
- **Coverage classification:** the synced/excluded list above is from a fast exploration
  pass; the drift-guard test and Phase 2 review establish the authoritative classification.

## 8. Sequencing and checkpoints

Phase 0 -> (checkpoint) -> Phase 1 -> Phase 2 -> Phase 3 -> Phase 4. The Phase 0->1
checkpoint is mandatory: no fix is designed or written until the diagnosis is in hand.
Implementation will occur on a dedicated feature branch/worktree, not on `main`.
