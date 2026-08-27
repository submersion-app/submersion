# iCloud Sync — Phase 0 Diagnosis (Findings)

## Root cause (one sentence)

On a *receiving* device, `SyncService._mergeEntity` catches an exception thrown while applying an incoming record (inside `SyncDataSerializer.upsertRecord` / `fetchRecord`) and silently **relabels it as a "conflict"** instead of applying it — so a device that does not already have the record applies nothing, which presents to the user as "sync does nothing."

## How it was found (no hardware required)

The no-op was reproduced entirely in pure Dart with an in-memory fake `CloudStorageProvider`, ruling out iCloud, entitlements, the Simulator, and provider selection as the cause.

Artifacts (on branch `feat/icloud-sync-diagnostic`):
- `test/helpers/fake_cloud_storage_provider.dart` — in-memory provider shared by two simulated devices.
- `test/core/services/sync/sync_serializer_round_trip_test.dart` — PASSES: export -> serialize -> deserialize -> checksum is healthy.
- `test/core/services/sync/sync_round_trip_test.dart` — FAILS at the A->B propagation assertion (the reproducing test for Phase 1).

## Evidence

| Stage | Measurement | Verdict |
| --- | --- | --- |
| Device A export/upload | `afterPush cloud.dives == 1` | Healthy — the dive is uploaded |
| Device B apply (pull) | `pull.status == hasConflicts`, `pull.recordsSynced == 14`, `pull.conflictsFound == 1` | The incoming dive is routed to the conflict path, not applied |
| Device B re-upload | final `cloud.dives == 0` | The receiving DB never got the dive |

Narrowing within `_mergeEntity` (`lib/core/services/sync/sync_service.dart`):
- The normal conflict branch cannot fire here: it requires `localUpdatedAt != null && remoteUpdatedAt != null && lastSyncMs != null`, but a fresh receiving device has `localUpdatedAt == null` and `lastSyncMs == null`.
- `_recordIdForEntity('dives', record)` returns `record['id']` = `'dive-xfer-1'` (non-null), so the `recordId == null` conflict path is not it.
- That leaves only the **catch block**: an exception during `_serializer.upsertRecord(entityType, record)` (or `fetchRecord`) is caught and converted to `markRecordConflict(...)` with `conflicts += 1`.

## Why this matches "it simply didn't sync anything"

Every incoming record that triggers the upsert/fetch error becomes a "conflict" rather than applying. Conflicts are not written to the real tables, and the conflict-resolution UI is currently orphaned/unreachable — so a second device shows no new data and no error. The first device appears to work (its own data is intact); only cross-device propagation silently fails.

## Two defects, not one

1. **The apply error** itself: `upsertRecord`/`fetchRecord` throws for a normally-deserialized record. Most likely a JSON <-> Drift shape/type mismatch in a deserialized field (int vs double, enum/bool encoding, or a column the upsert path does not handle). Exact exception is unknown because the catch block swallows it.
2. **The masking**: converting *any* apply exception into a "conflict" turns a hard error into silent data loss. Even after fixing defect 1, apply errors should surface (log + fail the sync), not be relabeled as conflicts.

## Recommended Phase 1 (the fix — not done yet)

1. Start from the failing test `sync_round_trip_test.dart` (already red).
2. Surface the swallowed exception: temporarily rethrow/log inside the `_mergeEntity` catch, or add a focused unit test that calls `SyncDataSerializer.upsertRecord('dives', <deserialized dive map>)` directly. Capture the exact error.
3. Fix the deserialization/upsert mismatch (root cause).
4. Stop masking apply errors as conflicts; let genuine failures fail the sync visibly.
5. Re-run `sync_round_trip_test.dart` to green, then extend the same harness to every entity type (this is also the natural home for spec Phase 2's data-coverage + drift-guard work).

Note: the on-device hardware verification (spec Phase 4) is still wanted eventually to validate the real iCloud transport, but it is no longer on the critical path for *this* bug — the no-op is fixable and verifiable entirely in Dart.
