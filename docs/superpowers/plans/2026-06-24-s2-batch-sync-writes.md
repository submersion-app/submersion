# S2 — Batch the Sync Row Writes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Task 4 (measurement) is optional/interactive.

**Goal:** Collapse `_mergeEntity`'s N per-row `fetchRecord` reads + N per-row `upsertRecord` writes into one batched read + one Drift `batch()` write per merge-batch, with byte-identical LWW/HLC/conflict results.

**Architecture:** Add `fetchRecords` (batched read) and `upsertRecords` (Drift `batch()` write) to `SyncDataSerializer` as mechanical mirrors of the existing per-entity `fetchRecord`/`upsertRecord` switches. Restructure `_mergeEntity` into read-decide-write: batch-fetch locals, run every existing decision in memory against the pre-fetched rows (collecting winners), then batch-upsert the winners.

**Tech Stack:** Drift (`batch`, `insertAllOnConflictUpdate`, `isIn`), the existing `SyncDataSerializer` switches, `flutter_test`.

## Global Constraints

- **TDD**; **`dart format .`** before push; **no `Co-Authored-By`** trailer.
- **Parity is the gate:** the byte-for-byte `sync_base_streaming_parity_test` and the full sync suite (335 tests) must stay green — LWW/HLC/conflict decisions and `applied`/`conflicts`/`failed` counts must be identical.
- **Unique ids per batch** (changeset invariant) — no decision in the merge loop may read a value written earlier in the same loop; the batched design relies on this.
- Spec: `docs/superpowers/specs/2026-06-24-s2-batch-sync-writes-design.md`.

## File Structure

- Modify `lib/core/services/sync/sync_data_serializer.dart` — add `fetchRecords` (after `fetchRecord` ~975) and `upsertRecords` (after `upsertRecord` ~1204).
- Modify `lib/core/services/sync/sync_service.dart:1342-1510` — `_mergeEntity` read-decide-write.
- Tests: a focused serializer test (`test/core/services/sync/sync_data_serializer_batch_test.dart`) + the existing parity/sync suite as the regression gate.

---

### Task 1: `upsertRecords` — batched write

**Files:** Modify `sync_data_serializer.dart`; test `test/core/services/sync/sync_data_serializer_batch_test.dart`.

**Interfaces:**
- Produces: `Future<void> upsertRecords(String entityType, List<Map<String, dynamic>> records)` — writes all `records` in one Drift `batch()`, in list order, with the same conflict semantics as `upsertRecord`.

- [ ] **Step 1: Write the failing test** — two records written in one call equal two `upsertRecord` calls.

```dart
// sync_data_serializer_batch_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import '../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('upsertRecords writes all records (== per-row upsert)', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('divers', [
      {'id': 'a', 'name': 'A', 'isDefault': false, 'createdAt': 1, 'updatedAt': 1},
      {'id': 'b', 'name': 'B', 'isDefault': false, 'createdAt': 1, 'updatedAt': 1},
    ]);
    expect((await s.fetchRecord('divers', 'a'))?['name'], 'A');
    expect((await s.fetchRecord('divers', 'b'))?['name'], 'B');

    // Conflict-update: re-upsert 'a' with a new name updates in place.
    await s.upsertRecords('divers', [
      {'id': 'a', 'name': 'A2', 'isDefault': false, 'createdAt': 1, 'updatedAt': 2},
    ]);
    expect((await s.fetchRecord('divers', 'a'))?['name'], 'A2');
  });
}
```

(Use the exact `divers` column set the existing `upsertRecord`/parity tests use; copy from `sync_base_streaming_parity_test.dart:57-65` if fields differ.)

- [ ] **Step 2: Run to verify it fails** — `flutter test test/core/services/sync/sync_data_serializer_batch_test.dart` → FAIL (`upsertRecords` undefined).

- [ ] **Step 3: Implement** — mirror the existing `upsertRecord` switch (lines ~976-1204), wrapping each case's insert in one `_db.batch`. The mechanical transform per case:

`upsertRecord`: `await _db.into(_db.X).insertOnConflictUpdate(Y.fromJson(data));`
→ `upsertRecords`: `batch.insertAllOnConflictUpdate(_db.X, records.map((r) => Y.fromJson(r)).toList());`

```dart
Future<void> upsertRecords(
  String entityType,
  List<Map<String, dynamic>> records,
) async {
  if (records.isEmpty) return;
  await _db.batch((batch) {
    switch (entityType) {
      case 'divers':
        batch.insertAllOnConflictUpdate(
          _db.divers,
          records.map((r) => Diver.fromJson(r)).toList(),
        );
      case 'dives':
        batch.insertAllOnConflictUpdate(
          _db.dives,
          records.map((r) => Dive.fromJson(r)).toList(),
        );
      // ... one case PER entity, mirroring upsertRecord's switch exactly
      // (same _db.<table> and <Type>.fromJson for each entityType). For any
      // case in upsertRecord that does more than a bare insertOnConflictUpdate,
      // reproduce that logic inside the batch the same way.
      default:
        throw ArgumentError('upsertRecords: unknown entityType $entityType');
    }
  });
}
```

Enumerate every `case` present in `upsertRecord` (lines 976-1204). Do not invent or omit entities — the set must match exactly (a missing case silently drops a table on apply).

- [ ] **Step 4: Run to verify it passes** — PASS.

- [ ] **Step 5: Commit** — `feat(sync): SyncDataSerializer.upsertRecords batched write`.

---

### Task 2: `fetchRecords` — batched read

**Files:** Modify `sync_data_serializer.dart`; extend the batch test.

**Interfaces:**
- Produces: `Future<Map<String, Map<String, dynamic>>> fetchRecords(String entityType, Iterable<String> ids)` — local rows keyed by id, for the single-id (`hasUpdatedAt`) entities `_mergeEntity` reads. Composite-key junctions are clockless and never fetched.

- [ ] **Step 1: Write the failing test** — batched read returns the same rows as per-id `fetchRecord`.

```dart
test('fetchRecords returns rows keyed by id (== per-id fetchRecord)', () async {
  final s = SyncDataSerializer();
  await s.upsertRecords('divers', [
    {'id': 'a', 'name': 'A', 'isDefault': false, 'createdAt': 1, 'updatedAt': 1},
    {'id': 'b', 'name': 'B', 'isDefault': false, 'createdAt': 1, 'updatedAt': 1},
  ]);
  final got = await s.fetchRecords('divers', ['a', 'b', 'missing']);
  expect(got.keys.toSet(), {'a', 'b'}); // absent ids simply absent
  expect(got['a'], await s.fetchRecord('divers', 'a'));
  expect(got['b'], await s.fetchRecord('divers', 'b'));
});
```

- [ ] **Step 2: Run to verify it fails** — FAIL (`fetchRecords` undefined).

- [ ] **Step 3: Implement** — mirror `fetchRecord`'s single-id cases (lines ~761-975) with `isIn` instead of `equals`, building a map by id. The mechanical transform per single-id case:

`fetchRecord`: `final row = await (_db.select(_db.X)..where((t) => t.id.equals(recordId))).getSingleOrNull(); return row?.toJson();`
→ `fetchRecords`: `final rows = await (_db.select(_db.X)..where((t) => t.id.isIn(idList))).get(); return {for (final r in rows) r.id: r.toJson()};`

```dart
Future<Map<String, Map<String, dynamic>>> fetchRecords(
  String entityType,
  Iterable<String> ids,
) async {
  final idList = ids.toList();
  if (idList.isEmpty) return {};
  switch (entityType) {
    case 'divers':
      final rows =
          await (_db.select(_db.divers)..where((t) => t.id.isIn(idList))).get();
      return {for (final r in rows) r.id: r.toJson()};
    case 'dives':
      final rows =
          await (_db.select(_db.dives)..where((t) => t.id.isIn(idList))).get();
      return {for (final r in rows) r.id: r.toJson()};
    // ... one case per SINGLE-ID entity that appears in SyncService.entityHasUpdatedAt
    // with value true (those are the only entities _mergeEntity fetches). The
    // composite-key junctions in fetchRecord (those using _splitCompositeId) are
    // clockless and never reach the LWW fetch, so they are NOT needed here.
    default:
      throw ArgumentError('fetchRecords: unexpected entityType $entityType');
  }
}
```

(Confirm the single-id set against `SyncService.entityHasUpdatedAt`. If unsure whether an entity is single-id, mirror its `fetchRecord` case verbatim with `isIn`.)

- [ ] **Step 4: Run to verify it passes** — PASS.

- [ ] **Step 5: Commit** — `feat(sync): SyncDataSerializer.fetchRecords batched read`.

---

### Task 3: `_mergeEntity` read-decide-write

**Files:** Modify `sync_service.dart:1342-1510`.

**Interfaces:**
- Consumes: `fetchRecords`, `upsertRecords` (Tasks 1-2).

- [ ] **Step 1: The parity tests already exist and currently pass** (`sync_base_streaming_parity_test`) — they are the failing/guard test for this refactor: they must stay green after it. Run them first to confirm the baseline: `flutter test test/core/services/sync/sync_base_streaming_parity_test.dart` → PASS (pre-refactor).

- [ ] **Step 2: Restructure `_mergeEntity`** to read-decide-write. Replace the per-record `fetchRecord` + per-record `upsertRecord` with:

(a) Before the loop, for `hasUpdatedAt` entities, batch-fetch locals:
```dart
final localById = hasUpdatedAt
    ? await _serializer.fetchRecords(entityType, [
        for (final r in records)
          if (_recordIdForEntity(entityType, r) case final id?) id,
      ])
    : const <String, Map<String, dynamic>>{};
final toUpsert = <Map<String, dynamic>>[];
```

(b) In the loop, replace `final local = await _serializer.fetchRecord(entityType, recordId);` with `final local = localById[recordId];`, and replace each `await _serializer.upsertRecord(entityType, recordToApply); applied += 1;` with `toUpsert.add(recordToApply); applied += 1;`. Every guard, `SyncClock.receive`, conflict-marking, and the clockless blind-win branch stay exactly as-is (the clockless branch also does `toUpsert.add(...)`).

(c) After the loop, flush once:
```dart
if (toUpsert.isNotEmpty) {
  await _serializer.upsertRecords(entityType, toUpsert);
}
return _MergeResult(recordsApplied: applied, conflictsFound: conflicts, recordsFailed: failed);
```

Keep `removeDeletion`/`markRecordConflict` per-record (unchanged). Keep the per-record `try/catch` that counts `failed`; additionally, wrap the final `upsertRecords` so a batch-write failure is surfaced (counts toward `failed` rather than throwing past the merge) — mirror how the per-row catch counted failures.

- [ ] **Step 3: Run the parity + full sync dir** — `flutter test test/core/services/sync/` → all green (parity byte-for-byte, counts identical, convergence/LWW/HLC/#347 junction all unchanged).

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze lib/core/services/sync/
git add lib/core/services/sync/ test/core/services/sync/
git commit -m "perf(sync): _mergeEntity read-decide-write (batched fetch + upsert)"
```

---

### Task 4: Measure (optional, interactive)

- [ ] `flutter test` (full pre-push gate) → green.
- [ ] Optionally, with `scratchpad/vmcap.dart` during a delta-heavy sync, confirm fewer `sqlite3VdbeExec`/Drift-call invocations per apply. (Like S3, the win is partly structural — N→1 statements — so a clean live capture is secondary.)

---

## Self-Review

**Spec coverage:** batched read (spec §Design.1) → Task 2. batched write (§Design.3) → Task 1. read-decide-write loop (§Design.2) → Task 3. Parity gate (§Testing) → Task 3 Step 1/3 (existing byte-for-byte test) + Task 1/2 unit tests. Error-handling-counts-failed (§Correctness) → Task 3 Step 2 note. Out-of-scope (deletions/FK-repair) honored.

**Placeholder scan:** Tasks 1-2 give the exact mechanical transform + runnable representative cases + an explicit "enumerate every case of the existing switch, set must match exactly" instruction (the existing switch is the complete source-of-truth, not a TODO). Task 3 gives the exact before/after edits to the named lines. The one judgement call (which entities are single-id) is pinned to `SyncService.entityHasUpdatedAt` with a fallback rule, not left vague.

**Type/name consistency:** `fetchRecords(String, Iterable<String>) -> Map<String, Map<String,dynamic>>` and `upsertRecords(String, List<Map<String,dynamic>>)` are used identically in Task 3. `localById`/`toUpsert` names consistent. The clockless branch and the LWW branch both append to the same `toUpsert`.
