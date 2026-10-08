# Incremental Sync — Phase 2: Serialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and parse the changeset/base payloads — the serialization layer between the DB and the on-storage files. After this phase a device can compute an HLC-watermark *delta* (`exportChangeset`) and a chunked *base*, serialize both, and parse them back — with zero transport wiring yet (that's Phase 4).

**Architecture:** Builds on Phase 1's foundation. Two row taxonomies: **mutable entities** carry their own `hlc` and are filtered by `hlc > watermark`; **write-once children** are gathered by their HLC parent's `hlc`. This phase first makes the taxonomy total by adding `hlc` to the last three mutable tables (`media`, `species`, `field_presets`), then adds a delta export (`exportChangeset`) alongside the untouched full export (`exportData(since: null)`, used for the base). The existing HLC/LWW merge core and `exportData` base path are not disturbed.

**Tech Stack:** Flutter, Drift (codegen via build_runner), `crypto` (sha256), `flutter_test`.

**Key facts established by exploration (Phase 2 prep):**
- The write-once child helpers ALREADY parent-gather: e.g. `_exportDiveProfiles` selects `diveId.isIn(<dives where updatedAt >= since>)`. Phase 2 re-keys that gather from `dives.updatedAt` to `dives.hlc`.
- **Five child tables are currently exported in FULL** regardless of `since` — `diveDataSources` (holds raw dive-computer BLOBs), `diveCustomFields`, `sightings`, `siteSpecies`, `equipmentSetItems`. Converting these to parent-gathered is the biggest volume win and the correctness crux of this phase.
- `exportData` is only ever called with `since: null` today (`sync_service.dart:516`, `:1621`), so the helpers' `updatedAt`-filter branches are effectively dead code — safe to re-key to HLC. **Task 3 Step 1 verifies this before relying on it.**
- HLC packed form is zero-padded (`hlc.dart` `toString()`), so `hlc > '<packed>'` is a valid SQL string comparison for HLC ordering.
- `_hlcTargets` (sync_repository.dart:29) maps entityType → (table, pk); `_hlcTables` (database.dart) lists HLC tables; `markRecordPending` → `_stampHlc` stamps on write.

**Phase roadmap:** Phase 1 (foundation) ✅ → **Phase 2 (serialization) ← this plan** → 3 (write path) → 4 (read path) → 5 (resumability + compaction) → 6 (restore + coexistence).

---

### Task 1: Add HLC to `media`, `species`, `field_presets` (schema v85 + registration)

**Files:**
- Modify: `lib/core/database/database.dart` (add `hlc` to 3 table classes; add 3 names to `_hlcTables`; bump `currentSchemaVersion` to 85; add `85` to `migrationVersions`; add v85 migration block)
- Modify: `lib/core/data/repositories/sync_repository.dart` (add 3 entries to `_hlcTargets`)
- Modify (if needed): the field-preset repository write path
- Test: `test/core/database/migration_v85_test.dart`, `test/core/data/repositories/sync_repository_hlc_media_test.dart`

- [ ] **Step 1: Write the failing schema test**

```dart
// test/core/database/migration_v85_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  Future<Set<String>> cols(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v85 adds hlc to media, species, field_presets', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await cols(db, 'media'), contains('hlc'));
    expect(await cols(db, 'species'), contains('hlc'));
    expect(await cols(db, 'field_presets'), contains('hlc'));
  });
}
```

- [ ] **Step 2: Run it — expect FAIL** (`flutter test test/core/database/migration_v85_test.dart`): the `media` etc. have no `hlc` yet.

- [ ] **Step 3: Add the `hlc` column to the three table classes**

In `database.dart`, add to the `Media`, `Species`, and `FieldPresets` table classes (next to their other columns):

```dart
  TextColumn get hlc => text().nullable()();
```

- [ ] **Step 4: Register version + migration + HLC table list**

- `currentSchemaVersion` → `85`.
- Append `85,` to the `migrationVersions` list (after `84,`).
- Add `'media'`, `'species'`, `'field_presets'` to the `_hlcTables` list.
- Add the v85 migration after the `if (from < 84) await reportProgress();` line, using the PRAGMA-guarded pattern already used by v82/v83:

```dart
      if (from < 85) {
        // media, species, field_presets become first-class HLC entities so
        // they delta by their own hlc instead of being exported in full.
        for (final table in const ['media', 'species', 'field_presets']) {
          final cols = await customSelect(
            "PRAGMA table_info('$table')",
          ).get();
          final existing = cols.map((c) => c.read<String>('name')).toSet();
          if (cols.isNotEmpty && !existing.contains('hlc')) {
            await customStatement('ALTER TABLE $table ADD COLUMN hlc TEXT');
          }
        }
      }
      if (from < 85) await reportProgress();
```

- [ ] **Step 5: Register the three entities in `_hlcTargets`**

In `sync_repository.dart`, add to the `_hlcTargets` map (after `'viewConfigs'`):

```dart
    'media': (table: 'media', pk: 'id'),
    'species': (table: 'species', pk: 'id'),
    'fieldPresets': (table: 'field_presets', pk: 'id'),
```

- [ ] **Step 6: Verify the field-preset write path stamps HLC**

`media` and `species` writes already call `_syncRepository.markRecordPending(entityType: 'media'|'species', ...)`, so registering them in `_hlcTargets` (Step 5) makes `_stampHlc` stamp them automatically — no change needed. Confirm `field_presets` is the same:

Run: `grep -rn "markRecordPending" lib/features/*/data/repositories/*field_preset*`
- If it calls `markRecordPending(entityType: 'fieldPresets', recordId: <id>)` after each insert/update → nothing to do.
- If NOT, add that call after each create/update in the field-preset repository (match the pattern in `species_repository.dart:114`), so edits stamp `hlc`.

- [ ] **Step 7: Run codegen** (`dart run build_runner build --delete-conflicting-outputs`).

- [ ] **Step 8: Write the failing stamping test**

```dart
// test/core/data/repositories/sync_repository_hlc_media_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';

void main() {
  test('markRecordPending stamps hlc on a media row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SyncRepository(db);

    // Insert a bare media row via raw SQL (avoids the full media repo).
    final now = 1000;
    await db.customStatement(
      "INSERT INTO media (id, file_type, created_at) VALUES ('m1', 'photo', $now)",
    );
    await repo.markRecordPending(entityType: 'media', recordId: 'm1');

    final row = await db
        .customSelect("SELECT hlc FROM media WHERE id = 'm1'")
        .getSingle();
    expect(row.read<String?>('hlc'), isNotNull);
  });
}
```

> NOTE: confirm `SyncRepository`'s constructor signature (`SyncRepository(db)` or named) and the exact required columns of `media` for a minimal INSERT (adjust the raw INSERT to satisfy NOT NULL columns — check the `Media` table definition). `markRecordPending` may require the sync clock be configurable; if the test throws "clock not configured", call `await repo.ensureSyncClockConfigured()` first.

- [ ] **Step 9: Run both tests — expect PASS.** (`flutter test test/core/database/migration_v85_test.dart test/core/data/repositories/sync_repository_hlc_media_test.dart`)

- [ ] **Step 10: analyze, format, commit**

```bash
flutter analyze
dart format lib/core/database/database.dart lib/core/data/repositories/sync_repository.dart test/core/database/migration_v85_test.dart test/core/data/repositories/sync_repository_hlc_media_test.dart
git add -A
git commit -m "feat(sync): make media, species, field_presets first-class HLC entities (v85)"
```

---

### Task 2: Changeset/base header fields on `SyncPayload`

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`SyncPayload` class)
- Test: `test/core/services/sync/sync_payload_header_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/sync_payload_header_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

void main() {
  test('changeset header fields round-trip through json', () {
    const payload = SyncPayload(
      version: 2,
      exportedAt: 5,
      deviceId: 'dev',
      checksum: 'c',
      data: SyncData(),
      deletions: {},
      seq: 14,
      baseSeq: 12,
      sinceHlc: 'A',
      toHlc: 'B',
    );
    final back = SyncPayload.fromJson(payload.toJson());
    expect(back.seq, 14);
    expect(back.baseSeq, 12);
    expect(back.sinceHlc, 'A');
    expect(back.toHlc, 'B');
  });

  test('a base/legacy payload without header fields parses with nulls', () {
    final back = SyncPayload.fromJson(const {
      'version': 2,
      'exportedAt': 1,
      'deviceId': 'd',
      'checksum': 'c',
      'data': <String, dynamic>{},
      'deletions': <String, dynamic>{},
    });
    expect(back.seq, isNull);
    expect(back.baseSeq, isNull);
  });
}
```

- [ ] **Step 2: Run it — expect FAIL** (compile error: `seq` etc. not defined).

- [ ] **Step 3: Add the four optional fields to `SyncPayload`**

In the `SyncPayload` class: add fields, constructor params, `toJson` entries, and `fromJson` reads (all nullable/optional so existing base + legacy payloads are unaffected):

```dart
  final int? seq;       // changeset sequence (null for a base/full payload)
  final int? baseSeq;   // the base this changeset layers on (optional)
  final String? sinceHlc; // watermark this delta starts after
  final String? toHlc;    // watermark this delta advances to (== publishedHlcHigh)
```
Add to the constructor: `this.seq, this.baseSeq, this.sinceHlc, this.toHlc,`.
Add to `toJson`: `'seq': seq, 'baseSeq': baseSeq, 'sinceHlc': sinceHlc, 'toHlc': toHlc,`.
Add to `fromJson`: `seq: json['seq'] as int?, baseSeq: json['baseSeq'] as int?, sinceHlc: json['sinceHlc'] as String?, toHlc: json['toHlc'] as String?,`.

> The checksum is still computed over the `data` section only (unchanged), so adding header fields does not affect existing checksum validation.

- [ ] **Step 4: Run it — expect PASS.**

- [ ] **Step 5: analyze, format, commit**

```bash
flutter analyze && dart format lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/sync_payload_header_test.dart
git add -A && git commit -m "feat(sync): add changeset header fields to SyncPayload"
```

---

### Task 3: Re-key export helpers to an HLC watermark; add `exportChangeset`

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart`
- Test: `test/core/services/sync/export_changeset_test.dart`

- [ ] **Step 1: Verify the safe-to-re-key assumption**

Run: `grep -rn "exportData(" lib | grep -v "since: null"`
Expected: no hits (every caller passes `since: null`). If any caller passes a non-null `since`, STOP and reconcile — re-keying the helpers' filter would change that caller's behavior. (Per exploration this should be empty.)

- [ ] **Step 2: Write the failing test**

```dart
// test/core/services/sync/export_changeset_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    serializer = SyncDataSerializer(db);
  });
  tearDown(() => db.close());

  // Helper: insert a diver + a dive with an hlc and one profile sample.
  Future<void> insertDive(String id, String hlc) async {
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, entry_time, updated_at, created_at, hlc) "
      "VALUES ('$id', 'dvr', 0, 0, 0, '$hlc')",
    );
    await db.customStatement(
      "INSERT INTO dive_profiles (id, dive_id, timestamp, depth) "
      "VALUES ('p_$id', '$id', 0, 1.0)",
    );
  }

  test('exportChangeset includes only dives with hlc > watermark, plus their '
      'write-once children', () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) VALUES ('dvr','D',0,0)",
    );
    await insertDive('old', '000000000000100:000000:n'); // below watermark
    await insertDive('new', '000000000000300:000000:n'); // above watermark

    final payload = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: '000000000000200:000000:n',
      deletions: const [],
    );

    final diveIds = payload.data.dives.map((d) => d['id']).toSet();
    expect(diveIds, {'new'});
    final profileDiveIds =
        payload.data.diveProfiles.map((p) => p['diveId']).toSet();
    expect(profileDiveIds, {'new'},
        reason: 'unchanged dive\'s profile must NOT be re-sent');
  });

  test('null watermark exports everything (degenerate full delta)', () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) VALUES ('dvr','D',0,0)",
    );
    await insertDive('a', '000000000000100:000000:n');
    final payload = await serializer.exportChangeset(
      deviceId: 'dev',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(payload.data.dives.length, 1);
    expect(payload.data.diveProfiles.length, 1);
  });
}
```

- [ ] **Step 3: Re-key the HLC-table helpers from `updatedAt` to `hlc`**

Change the filter in each HLC-table helper. **Pattern** (worked example for `_exportDives`):

```dart
// BEFORE
Future<List<Map<String, dynamic>>> _exportDives(int? since) async {
  final query = _db.select(_db.dives);
  if (since != null) {
    query.where((t) => t.updatedAt.isBiggerOrEqualValue(since));
  }
  final rows = await query.get();
  return rows.map((r) => r.toJson()).toList();
}

// AFTER — filter param is now the HLC watermark (String?)
Future<List<Map<String, dynamic>>> _exportDives(String? hlcSince) async {
  final query = _db.select(_db.dives);
  if (hlcSince != null) {
    query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
  }
  final rows = await query.get();
  return rows.map((r) => r.toJson()).toList();
}
```

Apply the identical change (`int? since` → `String? hlcSince`; `t.updatedAt.isBiggerOrEqualValue(since)` → `t.hlc.isBiggerThanValue(hlcSince)`) to every **HLC-table** helper:
`_exportDivers`, `_exportDiverSettings`, `_exportDives`, `_exportDiveSites`, `_exportEquipment`, `_exportEquipmentSets`, `_exportBuddies`, `_exportCertifications`, `_exportCourses`, `_exportServiceRecords`, `_exportDiveCenters`, `_exportTrips`, `_exportLiveaboardDetails`, `_exportItineraryDays`, `_exportTags`, `_exportDiveTypes` (keep its extra `isBuiltIn.equals(false)` clause — combine with `&`), `_exportTankPresets`, `_exportDiveComputers`, `_exportSettings`, `_exportCsvPresets`, `_exportViewConfigs`, plus the three newly-HLC ones `_exportMedia` (drop the `takenAt` filter — replace with `hlc`), `_exportSpecies` (keep `isBuiltIn.equals(false)`, add `hlc` clause), `_exportFieldPresets` (keep `isBuiltIn.equals(false)`, add `hlc` clause).

For helpers that retain a content filter (`_exportDiveTypes`, `_exportSpecies`, `_exportFieldPresets`), combine clauses, e.g.:
```dart
query.where((t) =>
    t.isBuiltIn.equals(false) &
    (hlcSince == null ? const Constant(true) : t.hlc.isBiggerThanValue(hlcSince)));
```

- [ ] **Step 4: Re-key the parent-gather (write-once child) helpers to `dives.hlc`**

**Pattern** (worked example for `_exportDiveProfiles`):
```dart
// AFTER — gather by parent dives.hlc instead of dives.updatedAt
Future<List<Map<String, dynamic>>> _exportDiveProfiles(String? hlcSince) async {
  final query = _db.select(_db.diveProfiles);
  if (hlcSince != null) {
    final changedDiveIds = _db.selectOnly(_db.dives)
      ..addColumns([_db.dives.id])
      ..where(_db.dives.hlc.isBiggerThanValue(hlcSince));
    query.where((t) => t.diveId.isInQuery(changedDiveIds));
  }
  final rows = await query.get();
  return rows.map((r) => r.toJson()).toList();
}
```
Apply the same parent-gather-by-`dives.hlc` change to the dive children that already parent-gather:
`_exportDiveTanks`, `_exportDiveEquipment`, `_exportDiveWeights`, `_exportDiveBuddies`, `_exportDiveTags`, `_exportTankPressureProfiles`, `_exportTideRecords`, `_exportDiveProfileEvents`, `_exportGasSwitches`.

> Use the project's existing subquery idiom for the "changed dive ids" set — match how the current helpers express `diveId.isIn(<subquery>)` (the exploration shows they already build this; keep that exact form, just swap the parent predicate to `dives.hlc.isBiggerThanValue(hlcSince)`).

- [ ] **Step 5: Convert the five always-full children to parent-gather**

These currently ignore `since` and export all rows; give them the same parent-gather treatment so unchanged parents' children (and `diveDataSources` BLOBs!) are not re-sent:
- `_exportDiveCustomFields`, `_exportDiveDataSources`, `_exportSightings` → parent-gather by `dives.hlc` (parent = dive).
- `_exportSiteSpecies` → parent-gather by `dive_sites.hlc` (parent = site).
- `_exportEquipmentSetItems` → parent-gather by `equipment_sets.hlc` (parent = set; the table's parent FK is `setId`).

Change each signature to `(String? hlcSince)` and, when `hlcSince != null`, filter by `parentId.isInQuery(<parents where hlc > hlcSince>)`; when null, export all (base behavior).

- [ ] **Step 6: Thread the watermark through; add `exportChangeset`**

- Change `exportData` to pass `null` to every helper (it is the full/base path): its body calls `_exportX(null)` for all helpers (the `DateTime? since` param becomes vestigial for the base; keep the signature for callers but always pass null internally, OR drop the param if Step 1 confirmed no non-null callers).
- Add `exportChangeset`, mirroring `exportData`'s assembly but passing the watermark and using `toHlc`/`sinceHlc` headers:

```dart
Future<SyncPayload> exportChangeset({
  required String deviceId,
  required String? hlcWatermark,
  required List<DeletionLogData> deletions,
  int? seq,
  String? uploadNonce,
  String? epochId,
}) async {
  final data = SyncData(
    divers: await _safeExport('divers', () => _exportDivers(hlcWatermark)),
    // ... same list as exportData, each helper now taking hlcWatermark ...
  );
  final deletionMap = _groupDeletions(deletions); // extract the existing grouping
  final dataJson = jsonEncode(data.toJson());
  final checksum = _computeChecksum(dataJson);
  final toHlc = await maxRowHlc();          // see Step 7
  return SyncPayload(
    version: syncFormatVersion,
    exportedAt: DateTime.now().millisecondsSinceEpoch,
    deviceId: deviceId,
    checksum: checksum,
    data: data,
    deletions: deletionMap,
    seq: seq,
    sinceHlc: hlcWatermark,
    toHlc: toHlc,
    uploadNonce: uploadNonce,
    epochId: epochId,
  );
}
```
Extract the deletion-grouping block from `exportData` into a shared `_groupDeletions(...)` helper used by both, to stay DRY.

- [ ] **Step 7: Add `maxRowHlc()` (the watermark to advance to)**

`SyncRepository` already has a private `_maxRowHlc()` (used in `ensureSyncClockConfigured`). Expose an equivalent the serializer can call — either make `SyncRepository.maxRowHlc()` public and inject it, or add a serializer method that runs the same MAX(hlc) union across `_hlcTables`. Quote/copy the existing `_maxRowHlc()` union query. Returns the highest `hlc` string across all HLC tables (or null if none).

- [ ] **Step 8: Run the test — expect PASS.** Iterate on the subquery idiom until `exportChangeset` returns only changed dives + their children.

- [ ] **Step 9: Confirm the base path is unchanged**

Run the existing serializer/sync tests that exercise `exportData(since: null)` (full export) to prove re-keying the helpers didn't change full-export behavior:
Run: `flutter test test/core/services/sync/` (specific existing serializer test files — list them, don't run the whole tree if it times out).

- [ ] **Step 10: analyze, format, commit**

```bash
flutter analyze && dart format lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/export_changeset_test.dart
git add -A && git commit -m "feat(sync): HLC-watermark delta export (exportChangeset) with parent-gathered children"
```

---

### Task 4: Changeset & base builders + parse

**Files:**
- Create: `lib/core/services/sync/changeset_log/changeset_codec.dart`
- Test: `test/core/services/sync/changeset_log/changeset_codec_test.dart`

This wraps Phase 1's `BaseChunker` + the serializer into "bytes ready for upload" and "parsed back", with no cloud I/O.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/changeset_codec_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';

void main() {
  late AppDatabase db;
  late ChangesetCodec codec;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    codec = ChangesetCodec(SyncDataSerializer(db));
  });
  tearDown(() => db.close());

  test('changeset encode -> decode round-trips the payload', () async {
    final payload = await codec.serializer.exportChangeset(
      deviceId: 'dev', hlcWatermark: null, deletions: const [], seq: 3,
    );
    final bytes = codec.encodeChangeset(payload);
    final back = codec.decodeChangeset(bytes);
    expect(back.seq, 3);
    expect(codec.serializer.validateChecksum(back), isTrue);
  });

  test('base encode (chunked) -> reassemble -> decode round-trips', () async {
    final payload = await codec.serializer.exportData(deviceId: 'dev', deletions: const []);
    final parts = codec.encodeBaseParts(payload, partSize: 64);
    expect(parts.length, greaterThanOrEqualTo(1));
    final back = codec.decodeBaseParts(parts);
    expect(codec.serializer.validateChecksum(back), isTrue);
  });
}
```

- [ ] **Step 2: Run it — expect FAIL** (file does not exist).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/sync/changeset_log/changeset_codec.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

/// Bridges the serializer and the on-storage byte form: a changeset is one
/// JSON object; a base is the same JSON byte-sliced into resumable parts.
class ChangesetCodec {
  ChangesetCodec(this.serializer);

  final SyncDataSerializer serializer;

  Uint8List encodeChangeset(SyncPayload payload) =>
      Uint8List.fromList(utf8.encode(serializer.serializePayload(payload)));

  SyncPayload decodeChangeset(Uint8List bytes) =>
      serializer.deserializePayload(utf8.decode(bytes));

  List<Uint8List> encodeBaseParts(
    SyncPayload base, {
    int partSize = BaseChunker.defaultPartSize,
  }) =>
      BaseChunker.slice(encodeChangeset(base), partSize: partSize);

  SyncPayload decodeBaseParts(List<Uint8List> parts) =>
      decodeChangeset(BaseChunker.reassemble(parts));
}
```

- [ ] **Step 4: Run it — expect PASS.**

> NOTE: the base test calls `exportData(deviceId:, deletions:)` — confirm `exportData`'s required params after Task 3 Step 6 (it may still require `since`; pass `since: null`). Adjust the call to the real signature.

- [ ] **Step 5: analyze, format, commit**

```bash
flutter analyze && dart format lib/core/services/sync/changeset_log/changeset_codec.dart test/core/services/sync/changeset_log/changeset_codec_test.dart
git add -A && git commit -m "feat(sync): add ChangesetCodec (encode/decode changesets and chunked bases)"
```

---

### Phase 2 wrap-up

- [ ] Run the Phase 2 test files together + `flutter analyze`; confirm green.
- [ ] Confirm `exportData(since: null)` full-export behavior is unchanged (Task 3 Step 9) — this is the safety property: the base path must be byte-equivalent to before.

After this phase a device can compute and serialize an HLC-delta changeset and a chunked base, and parse both back — with no cloud wiring yet. **Phase 3 (write path)** consumes `ChangesetCodec` + the Phase 1 stores to actually publish to a `CloudStorageProvider`.
