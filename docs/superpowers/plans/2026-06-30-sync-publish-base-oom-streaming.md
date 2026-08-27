# Streaming Base Publish (write-side OOM #358) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish (and compact) a device's own sync base of any size without ever materializing the whole library in RAM, fixing the remaining iOS OOM crash in #358.

**Architecture:** Mirror the already-shipped read-side streaming in reverse. A new `SyncDataSerializer.exportBaseToTempFile` streams all rows (keyset-paged by `id`) to a temp file as exactly `jsonEncode(SyncPayload.toJson())`; a new `BasePartFileSource` reads that file back in 8 MB parts (checksumming incrementally) for upload. `ChangesetWriter` uses these at its two base-writing sites instead of `exportChangeset` → `encodeChangeset` → `BaseChunker.slice`.

**Tech Stack:** Dart/Flutter, Drift ORM (SQLite), `package:crypto` (SHA-256), `dart:io` `RandomAccessFile`.

## Global Constraints

- `dart format .` clean and `flutter analyze` clean before every commit (project pre-push hook enforces this).
- No emojis in code/comments/docs.
- Wire format unchanged: output is a valid `SyncPayload.toJson()` JSON object with the same keys/structure; existing readers and old bases must keep working (no forced re-publish).
- Peak memory bounded to one keyset page of rows + one 8 MB part buffer, independent of library size.
- Only the two **base**-writing paths change (`ChangesetWriter.publish` `!hasBase` branch and `_compact`). The incremental **changeset** path (`hasBase`) stays on `exportChangeset` + `encodeChangeset` (small deltas) — do not touch it.
- Correctness anchor is **semantic/round-trip parity**, not byte-identity: rows stream in `id` order (reorders arrays vs. today's rowid order), which is safe because each base is verified only against its own manifest checksums.
- `syncFormatVersion == 2`. BLOB serializer (`_syncBlobSerializer`, base64) is used for exactly `media`, `certifications`, `diveDataSources`.

---

### Task 1: `BasePartFileSource` (read temp file back out as checksummed parts)

**Files:**
- Create: `lib/core/services/sync/changeset_log/base_part_file_source.dart`
- Test: `test/core/services/sync/changeset_log/base_part_file_source_test.dart`

**Interfaces:**
- Produces: `BasePartFileSource(String path, {int partSize})` with
  `Future<BasePartUploadResult> uploadAll(Future<void> Function(int index, Uint8List bytes) upload)`
  where `BasePartUploadResult = ({int partCount, String wholeChecksum, List<String> partChecksums, int byteLength})`. `wholeChecksum`/part checksums use the `sha256:<hex>` convention of `BaseChunker.checksum`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/sync/changeset_log/base_part_file_source_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_source.dart';

void main() {
  test('yields parts + checksums matching BaseChunker over a multi-part file', () async {
    final dir = await Directory.systemTemp.createTemp('src');
    final path = '${dir.path}/base.json';
    // 2.5 parts of the 8 MB default so we cross part boundaries with a remainder.
    final data = Uint8List.fromList(
      List.generate(2 * BaseChunker.defaultPartSize + 12345, (i) => i % 256),
    );
    await File(path).writeAsBytes(data);
    final expected = BaseChunker.slice(data);

    final uploaded = <int, Uint8List>{};
    final res = await BasePartFileSource(path).uploadAll((i, bytes) async {
      uploaded[i] = Uint8List.fromList(bytes);
    });

    expect(res.partCount, expected.length);
    expect(res.byteLength, data.length);
    expect(res.wholeChecksum, BaseChunker.checksum(data));
    for (var i = 0; i < expected.length; i++) {
      expect(uploaded[i], expected[i], reason: 'part $i bytes');
      expect(res.partChecksums[i], BaseChunker.checksum(expected[i]));
    }
    await dir.delete(recursive: true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_source_test.dart`
Expected: FAIL — `base_part_file_source.dart` / `BasePartFileSource` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/services/sync/changeset_log/base_part_file_source.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

typedef BasePartUploadResult = ({
  int partCount,
  String wholeChecksum,
  List<String> partChecksums,
  int byteLength,
});

/// Reads an assembled base temp file back out in fixed-size parts, checksumming
/// each part and the whole file incrementally so the full base is never held in
/// memory. Write-side mirror of [BasePartFileSink] (which does the reverse on
/// download). Each part is handed to [upload] in order; the returned checksums
/// use the same `sha256:<hex>` convention as the manifest fields.
class BasePartFileSource {
  BasePartFileSource(this.path, {this.partSize = BaseChunker.defaultPartSize});

  final String path;
  final int partSize;

  Future<BasePartUploadResult> uploadAll(
    Future<void> Function(int index, Uint8List bytes) upload,
  ) async {
    final raf = await File(path).open();
    final digestSink = _DigestSink();
    final whole = sha256.startChunkedConversion(digestSink);
    final partChecksums = <String>[];
    try {
      final length = await raf.length();
      var index = 0;
      if (length == 0) {
        // Mirror BaseChunker.slice(empty) == [Uint8List(0)].
        final empty = Uint8List(0);
        whole.add(empty);
        partChecksums.add(BaseChunker.checksum(empty));
        await upload(0, empty);
        index = 1;
      } else {
        for (var off = 0; off < length; off += partSize) {
          final n = (off + partSize < length) ? partSize : length - off;
          final buf = await raf.read(n);
          whole.add(buf);
          partChecksums.add(BaseChunker.checksum(buf));
          await upload(index, buf);
          index++;
        }
      }
      whole.close();
      return (
        partCount: index,
        wholeChecksum: 'sha256:${digestSink.value}',
        partChecksums: partChecksums,
        byteLength: length,
      );
    } finally {
      await raf.close();
    }
  }
}

/// Minimal `Sink<Digest>` capturing the digest emitted at close (mirrors the
/// one in base_part_file_sink.dart; crypto does not export AccumulatorSink).
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/sync/changeset_log/base_part_file_source.dart test/core/services/sync/changeset_log/base_part_file_source_test.dart
git add lib/core/services/sync/changeset_log/base_part_file_source.dart test/core/services/sync/changeset_log/base_part_file_source_test.dart
git commit -m "feat(sync): BasePartFileSource streams a base temp file into checksummed parts (#358)"
```

---

### Task 2: `SyncDataSerializer.exportBaseToTempFile` (stream DB → base JSON temp file)

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (add imports, `StreamedBase` typedef, `_baseTables`, `_pageBaseTableById`, `exportBaseToTempFile`, `_Sha256DigestSink`)
- Test: `test/core/services/sync/base_publish_streaming_parity_test.dart`

**Interfaces:**
- Consumes: existing `_db`, `_groupDeletions`, `_maxHlc`, `_computeChecksum`, `_syncBlobSerializer`, `syncFormatVersion`, and the composite-table exporters `_exportDiveEquipment`, `_exportEquipmentSetItems`, `_exportSettings`.
- Produces: `Future<StreamedBase> exportBaseToTempFile({required String deviceId, required List<DeletionLogData> deletions, String? epochId, String? uploadNonce, int? seq, int pageSize, DateTime Function() now, Future<Directory> Function()? tempDir})` where `StreamedBase = ({String path, int byteLength, int exportedAt, String? toHlc, int rowCount})`. Writes exactly `jsonEncode(SyncPayload.toJson())` for a full base (all rows, `hlcWatermark == null` semantics). Caller owns and must delete the temp file.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/sync/base_publish_streaming_parity_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';

/// Order-independent snapshot: each table's rows sorted by their JSON so an
/// array-order difference (id order here vs. list order in exportChangeset) is
/// not a mismatch -- only data differences are.
String _canonical(Map<String, dynamic> dataJson) {
  final out = <String, dynamic>{};
  for (final key in dataJson.keys.toList()..sort()) {
    final list = (dataJson[key] as List).cast<Map<String, dynamic>>();
    final sorted = [...list]..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    out[key] = sorted;
  }
  return jsonEncode(out);
}

Future<void> _seedRich() async {
  final serializer = SyncDataSerializer();
  final dives = DiveRepository();
  await dives.createDive(createTestDiveWithBottomTime(id: 'd1', diveNumber: 1));
  await dives.createDive(createTestDiveWithBottomTime(id: 'd2', diveNumber: 2));
  await serializer.upsertRecord('diveSites', {
    'id': 'site-1', 'name': 'Test Site', 'description': '', 'notes': '',
    'isShared': false, 'createdAt': 1000, 'updatedAt': 1000,
  });
  // BLOB-bearing table (diveDataSources uses the base64 serializer).
  await serializer.upsertRecord('diveDataSources', {
    'id': 'ds-1', 'diveId': 'd1', 'isPrimary': true, 'sourceFormat': 'shearwater',
    'importedAt': 1700000000000, 'createdAt': 1700000000000,
    'rawFingerprint': Uint8List.fromList([0x01, 0x02, 0x03, 0xFE, 0xFF]),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => tearDownTestDatabase());

  test('_baseTables lists exactly the SyncData entities in order', () {
    // A missing/extra/misordered entity would silently drop or misplace rows.
    expect(
      SyncDataSerializer.debugBaseTableKeys,
      const SyncData().toJson().keys.toList(),
    );
  });

  test('streamed base equals exportChangeset(null) per table + valid checksum', () async {
    await _seedRich();
    final deletions = await SyncRepository().getAllDeletions();
    final expected = await SyncDataSerializer().exportChangeset(
      deviceId: 'peer', hlcWatermark: null, deletions: deletions,
    );

    final base = await SyncDataSerializer().exportBaseToTempFile(
      deviceId: 'peer', deletions: deletions, now: () => DateTime.fromMillisecondsSinceEpoch(123),
    );
    final decoded = jsonDecode(await File(base.path).readAsString()) as Map<String, dynamic>;
    await File(base.path).delete();

    expect(decoded['version'], syncFormatVersion);
    expect(decoded['exportedAt'], 123);
    expect(base.exportedAt, 123);
    expect(_canonical(decoded['data'] as Map<String, dynamic>),
        _canonical(expected.data.toJson()));
    expect(base.toHlc, expected.toHlc);
    // Internal checksum is valid over the streamed data bytes.
    final dataJson = jsonEncode(decoded['data']);
    expect(decoded['checksum'], sha256.convert(utf8.encode(dataJson)).toString());
  });

  test('keyset paging across >1 page is complete', () async {
    final dives = DiveRepository();
    for (var i = 1; i <= 250; i++) {
      await dives.createDive(createTestDiveWithBottomTime(id: 'd$i', diveNumber: i));
    }
    final expected = await SyncDataSerializer().exportChangeset(
      deviceId: 'peer', hlcWatermark: null, deletions: const [],
    );
    final base = await SyncDataSerializer().exportBaseToTempFile(
      deviceId: 'peer', deletions: const [], pageSize: 100, // forces 3 pages of dives
    );
    final decoded = jsonDecode(await File(base.path).readAsString()) as Map<String, dynamic>;
    await File(base.path).delete();
    expect((decoded['data']['dives'] as List).length, 250);
    expect(_canonical(decoded['data'] as Map<String, dynamic>),
        _canonical(expected.data.toJson()));
  });
}
```

Add `import 'package:crypto/crypto.dart';` to the test file (used for the checksum assertion).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/base_publish_streaming_parity_test.dart`
Expected: FAIL — `exportBaseToTempFile` / `debugBaseTableKeys` not defined.

- [ ] **Step 3: Add imports + `_Sha256DigestSink` at the top of `sync_data_serializer.dart`**

Add to the imports (after `import 'dart:convert';`):

```dart
import 'dart:io';

import 'package:uuid/uuid.dart';
```

Add a file-level uuid (near `const int syncFormatVersion = 2;`):

```dart
const _baseTempUuid = Uuid();
```

Add near the bottom of the file (outside the class):

```dart
/// Captures the single digest a chunked SHA-256 conversion emits at close.
class _Sha256DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
```

- [ ] **Step 4: Add the streaming export to `SyncDataSerializer`**

Add the return typedef above the class:

```dart
/// Result of streaming a base to a temp file. The caller owns [path] and must
/// delete it. [byteLength] is the on-disk base size (== manifest `baseBytes`);
/// [rowCount] is the total rows written (0 => an empty library).
typedef StreamedBase = ({
  String path,
  int byteLength,
  int exportedAt,
  String? toHlc,
  int rowCount,
});
```

Inside `class SyncDataSerializer`, add:

```dart
/// Ordered table descriptors for a base snapshot, matching SyncData.toJson.
/// `table != null` => keyset-page by `id`; otherwise `full` loads the whole
/// (small, composite-key) table. `blob` selects the base64 BLOB serializer.
List<({String key, TableInfo<Table, dynamic>? table, bool blob,
       Future<List<Map<String, dynamic>>> Function()? full})>
    get _baseTables => [
  (key: 'divers', table: _db.divers, blob: false, full: null),
  (key: 'diverSettings', table: _db.diverSettings, blob: false, full: null),
  (key: 'dives', table: _db.dives, blob: false, full: null),
  (key: 'diveProfiles', table: _db.diveProfiles, blob: false, full: null),
  (key: 'diveTanks', table: _db.diveTanks, blob: false, full: null),
  (key: 'diveEquipment', table: null, blob: false, full: () => _exportDiveEquipment(null)),
  (key: 'diveWeights', table: _db.diveWeights, blob: false, full: null),
  (key: 'diveSites', table: _db.diveSites, blob: false, full: null),
  (key: 'equipment', table: _db.equipment, blob: false, full: null),
  (key: 'equipmentSets', table: _db.equipmentSets, blob: false, full: null),
  (key: 'equipmentSetItems', table: null, blob: false, full: () => _exportEquipmentSetItems(null)),
  (key: 'media', table: _db.media, blob: true, full: null),
  (key: 'buddies', table: _db.buddies, blob: false, full: null),
  (key: 'diveBuddies', table: _db.diveBuddies, blob: false, full: null),
  (key: 'certifications', table: _db.certifications, blob: true, full: null),
  (key: 'courses', table: _db.courses, blob: false, full: null),
  (key: 'serviceRecords', table: _db.serviceRecords, blob: false, full: null),
  (key: 'diveCenters', table: _db.diveCenters, blob: false, full: null),
  (key: 'trips', table: _db.trips, blob: false, full: null),
  (key: 'liveaboardDetails', table: _db.liveaboardDetails, blob: false, full: null),
  (key: 'itineraryDays', table: _db.itineraryDays, blob: false, full: null),
  (key: 'tags', table: _db.tags, blob: false, full: null),
  (key: 'diveTags', table: _db.diveTags, blob: false, full: null),
  (key: 'diveDiveTypes', table: _db.diveDiveTypes, blob: false, full: null),
  (key: 'diveTypes', table: _db.diveTypes, blob: false, full: null),
  (key: 'tankPresets', table: _db.tankPresets, blob: false, full: null),
  (key: 'diveComputers', table: _db.diveComputers, blob: false, full: null),
  (key: 'tankPressureProfiles', table: _db.tankPressureProfiles, blob: false, full: null),
  (key: 'tideRecords', table: _db.tideRecords, blob: false, full: null),
  (key: 'settings', table: null, blob: false, full: () => _exportSettings(null)),
  (key: 'species', table: _db.species, blob: false, full: null),
  (key: 'sightings', table: _db.sightings, blob: false, full: null),
  (key: 'diveProfileEvents', table: _db.diveProfileEvents, blob: false, full: null),
  (key: 'gasSwitches', table: _db.gasSwitches, blob: false, full: null),
  (key: 'diveCustomFields', table: _db.diveCustomFields, blob: false, full: null),
  (key: 'diveDataSources', table: _db.diveDataSources, blob: true, full: null),
  (key: 'siteSpecies', table: _db.siteSpecies, blob: false, full: null),
  (key: 'csvPresets', table: _db.csvPresets, blob: false, full: null),
  (key: 'viewConfigs', table: _db.viewConfigs, blob: false, full: null),
  (key: 'fieldPresets', table: _db.fieldPresets, blob: false, full: null),
];

/// Test seam: the base table order, asserted equal to SyncData.toJson keys.
@visibleForTesting
static List<String> get debugBaseTableKeys =>
    SyncDataSerializer()._baseTables.map((t) => t.key).toList();

/// One keyset page (`id > cursor`, ascending, up to [limit]) of an id-PK table,
/// as JSON rows identical to the table's own `toJson` (blob serializer applied
/// for BLOB tables). O(n) total across pages; never loads the whole table.
Future<List<Map<String, dynamic>>> _pageBaseTableById(
  TableInfo<Table, dynamic> table, {
  required String? cursor,
  required int limit,
  required bool blob,
}) async {
  final name = table.actualTableName;
  final rows = cursor == null
      ? await _db.customSelect(
          'SELECT * FROM "$name" ORDER BY id LIMIT ?',
          variables: [Variable.withInt(limit)],
        ).get()
      : await _db.customSelect(
          'SELECT * FROM "$name" WHERE id > ? ORDER BY id LIMIT ?',
          variables: [Variable.withString(cursor), Variable.withInt(limit)],
        ).get();
  return rows.map((r) {
    final data = table.map(r.data) as dynamic;
    return (blob
        ? data.toJson(serializer: _syncBlobSerializer)
        : data.toJson()) as Map<String, dynamic>;
  }).toList();
}

/// Streams a full base snapshot to a temp file as exactly
/// `jsonEncode(SyncPayload.toJson())`, in bounded memory (one keyset page + one
/// write). Replaces `exportChangeset(null)` + `encodeChangeset` on the
/// publish/compact path, whose full-graph materialization OOM-crashed iOS on
/// large libraries (#358, write side). Rows stream in `id` order.
Future<StreamedBase> exportBaseToTempFile({
  required String deviceId,
  required List<DeletionLogData> deletions,
  String? epochId,
  String? uploadNonce,
  int? seq,
  int pageSize = 2000,
  DateTime Function() now = DateTime.now,
  Future<Directory> Function()? tempDir,
}) async {
  final dir = await (tempDir?.call() ?? Future.value(Directory.systemTemp));
  final path = '${dir.path}/ssv1_base_${deviceId}_${seq ?? 0}.${_baseTempUuid.v4()}.json';
  final raf = await File(path).open(mode: FileMode.write);
  final digestSink = _Sha256DigestSink();
  final dataHash = sha256.startChunkedConversion(digestSink);
  final exportedAt = now().millisecondsSinceEpoch;
  String? maxRowHlc;
  var rowCount = 0;

  // Writes + hashes only the `data` object bytes (matches _computeChecksum,
  // which hashes jsonEncode(data.toJson())).
  Future<void> writeData(String s) async {
    final bytes = utf8.encode(s);
    dataHash.add(bytes);
    await raf.writeFrom(bytes);
  }

  try {
    // Header up to (but not including) the checksum value.
    await raf.writeString(
      '{"version":$syncFormatVersion,"exportedAt":$exportedAt,'
      '"deviceId":${jsonEncode(deviceId)},"lastSyncTimestamp":null,"checksum":"',
    );
    final checksumOffset = await raf.position();
    await raf.writeFrom(List.filled(64, 0x30)); // 64 '0' placeholder, patched below
    await raf.writeString('","data":');

    // ---- data object (hashed) ----
    await writeData('{');
    for (var t = 0; t < _baseTables.length; t++) {
      final spec = _baseTables[t];
      if (t > 0) await writeData(',');
      await writeData('${jsonEncode(spec.key)}:[');
      var firstRow = true;

      Future<void> emit(Map<String, dynamic> row) async {
        if (!firstRow) await writeData(',');
        firstRow = false;
        rowCount++;
        final hlc = row['hlc'];
        if (hlc is String && (maxRowHlc == null || hlc.compareTo(maxRowHlc!) > 0)) {
          maxRowHlc = hlc;
        }
        await writeData(jsonEncode(row));
      }

      if (spec.table != null) {
        String? cursor;
        while (true) {
          final rows = await _pageBaseTableById(
            spec.table!, cursor: cursor, limit: pageSize, blob: spec.blob,
          );
          for (final row in rows) {
            await emit(row);
          }
          if (rows.length < pageSize) break;
          cursor = rows.last['id'] as String;
        }
      } else {
        for (final row in await spec.full!()) {
          await emit(row);
        }
      }
      await writeData(']');
    }
    await writeData('}');

    // ---- trailer (not part of the data checksum) ----
    final toHlc = _maxHlc([maxRowHlc, ...deletions.map((d) => d.hlc)]);
    final tail = <String, dynamic>{
      'deletions': _groupDeletions(deletions)
          .map((k, v) => MapEntry(k, v.map((d) => d.toJson()).toList())),
      'uploadNonce': uploadNonce,
      'epochId': epochId,
      'seq': seq,
      'baseSeq': null,
      'sinceHlc': null,
      'toHlc': toHlc,
    };
    final tailBuf = StringBuffer();
    tail.forEach((k, v) => tailBuf.write(',${jsonEncode(k)}:${jsonEncode(v)}'));
    tailBuf.write('}');
    await raf.writeString(tailBuf.toString());

    // ---- patch the checksum placeholder with the real data digest ----
    dataHash.close();
    final endPos = await raf.position();
    await raf.setPosition(checksumOffset);
    await raf.writeFrom(utf8.encode(digestSink.value.toString()));
    await raf.setPosition(endPos);
    await raf.flush();
    await raf.close();

    final byteLength = await File(path).length();
    return (
      path: path,
      byteLength: byteLength,
      exportedAt: exportedAt,
      toHlc: toHlc,
      rowCount: rowCount,
    );
  } catch (e) {
    await raf.close();
    try {
      await File(path).delete();
    } catch (_) {}
    rethrow;
  }
}
```

Note: `@visibleForTesting` requires `import 'package:meta/meta.dart';` — add it if not already imported (drift re-exports it, so it is usually already available via `package:drift/drift.dart`).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/base_publish_streaming_parity_test.dart`
Expected: PASS (all three tests). If `table.actualTableName` does not resolve, use `table.entityName`; if `table.map(r.data)` typing complains, the row map is `r.data` (a `Map<String, dynamic>`).

- [ ] **Step 6: Commit**

```bash
dart format lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/base_publish_streaming_parity_test.dart
flutter analyze lib/core/services/sync/sync_data_serializer.dart
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/base_publish_streaming_parity_test.dart
git commit -m "feat(sync): stream a base snapshot to a temp file in bounded memory (#358)"
```

---

### Task 3: Wire `ChangesetWriter.publish` `!hasBase` branch to the streaming path

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_writer.dart` (imports, restructure `publish`)
- Test: `test/core/services/sync/changeset_log/changeset_writer_test.dart` (add a round-trip test; the existing "first publish" test is a regression guard)

**Interfaces:**
- Consumes: `SyncDataSerializer.exportBaseToTempFile` (Task 2), `BasePartFileSource` (Task 1).
- Produces: unchanged `publish(...) -> Future<ChangesetWriteResult>`; the `ChangesetWriteKind.base` result and manifest fields are identical in meaning to today.

- [ ] **Step 1: Write the failing test** (append inside `main()` of `changeset_writer_test.dart`)

```dart
  test('first base publish streams parts that reassemble to the library', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.base);

    final deviceId = await SyncRepository().getDeviceId();
    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      ),
    );

    // Reassemble the uploaded parts and verify checksum + parsed content.
    final parts = <int, List<int>>{};
    for (final f in await provider.listFiles(
        folderId: folder, namePattern: ChangesetLogLayout.prefix)) {
      final bp = ChangesetLogLayout.basePartOf(f.name);
      if (bp != null && bp.baseSeq == manifest.baseSeq) {
        parts[bp.partIndex] = await provider.downloadFile(f.id);
      }
    }
    final ordered = (parts.keys.toList()..sort()).expand((i) => parts[i]!).toList();
    expect(ordered.length, manifest.baseBytes);
    expect('sha256:${sha256.convert(ordered)}', manifest.baseChecksum);

    final payload = jsonDecode(utf8.decode(ordered)) as Map<String, dynamic>;
    final diveIds = ((payload['data'] as Map)['dives'] as List)
        .map((d) => (d as Map)['id'])
        .toSet();
    expect(diveIds, {'d1', 'd2'});
  });
```

Add imports at the top of `changeset_writer_test.dart` if missing: `import 'dart:convert';`, `import 'package:crypto/crypto.dart';`, and ensure `basePartOf(...)` exposes `partIndex`/`baseSeq` (it already returns a record used in `changeset_writer.dart`).

- [ ] **Step 2: Run the new test as a refactor-guard baseline**

Run: `flutter test test/core/services/sync/changeset_log/changeset_writer_test.dart -n "reassemble"`
Expected: PASS on the current (in-memory) base path. This is a characterization/guard test for a refactor: it pins the observable publish behavior (parts reassemble to the library, checksum matches the manifest) so the streaming rewrite in Step 3 must keep it green. Memory bounding itself is validated by the parity/paging tests in Task 2 and the device run in Task 5, not here.

- [ ] **Step 3: Restructure `publish` to stream the base**

Add imports to `changeset_writer.dart`:

```dart
import 'dart:io';

import 'package:submersion/core/services/sync/changeset_log/base_part_file_source.dart';
```

First fix the pre-branch setup: keep `final newSeq = knownHeadSeq + 1;` and `final now = DateTime.now().millisecondsSinceEpoch;` **before** the `if (!hasBase)` (both branches use them), and **delete** the pre-branch `final payload = await _serializer.exportChangeset(...)` (lines ~64-71) and `if (_isEmpty(payload)) return ...noop;` (lines ~73-75) — they move into the changeset branch. Then replace the `if (!hasBase) { ... }` base branch with:

```dart
    if (!hasBase) {
      // Stream the base to a temp file and slice-upload it, so a large library
      // is never materialized in RAM (#358 write side). Do NOT call
      // exportChangeset(null) here -- that is the OOM path.
      final base = await _serializer.exportBaseToTempFile(
        deviceId: deviceId,
        deletions: deletions,
        epochId: epochId,
        uploadNonce: uploadNonce,
        seq: newSeq,
      );
      try {
        if (base.rowCount == 0 && deletions.isEmpty) {
          return const ChangesetWriteResult(ChangesetWriteKind.noop);
        }
        final upload = await BasePartFileSource(base.path).uploadAll(
          (i, bytes) => provider.uploadFile(
            bytes,
            ChangesetLogLayout.basePartName(deviceId, newSeq, i),
            folderId: folderId,
          ),
        );
        final manifest = SyncManifest(
          deviceId: deviceId,
          provider: providerId,
          baseSeq: newSeq,
          basePartCount: upload.partCount,
          baseBytes: base.byteLength,
          baseChecksum: upload.wholeChecksum,
          basePartChecksums: upload.partChecksums,
          headSeq: newSeq,
          publishedHlcHigh: base.toHlc,
          epochId: epochId,
          uploadNonce: uploadNonce,
          updatedAt: now,
        );
        await _writeManifest(provider, folderId, deviceId, manifest);
        await _publishState.upsert(
          LocalPublishStatesCompanion(
            provider: Value(providerId),
            baseSeq: Value(newSeq),
            basePartCount: Value(upload.partCount),
            baseBytes: Value(base.byteLength),
            headSeq: Value(newSeq),
            publishedHlcHigh: Value(base.toHlc),
            changesetBytesSinceBase: const Value(0),
            updatedAt: Value(now),
          ),
        );
        return ChangesetWriteResult(ChangesetWriteKind.base, newSeq);
      } finally {
        try {
          await File(base.path).delete();
        } catch (_) {}
      }
    }
```

Then, at the start of the changeset branch (the existing `// Changeset:` comment, just before `final bytes = _codec.encodeChangeset(payload);`), insert the payload computation that used to run before the branch:

```dart
    // Changeset: reuse the base fields from the (authoritative) own manifest;
    // only headSeq / publishedHlcHigh advance. The incremental delta stays in
    // memory (small); only the base path above is streamed (#358).
    final payload = await _serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: watermark,
      deletions: deletions,
      seq: newSeq,
      epochId: epochId,
      uploadNonce: uploadNonce,
    );
    if (_isEmpty(payload)) {
      return const ChangesetWriteResult(ChangesetWriteKind.noop);
    }
    final bytes = _codec.encodeChangeset(payload);
```

Everything after `final bytes = _codec.encodeChangeset(payload);` (the changeset upload, manifest, publish-state upsert, and compaction trip check) is unchanged. Note `watermark` (not `hasBase ? watermark : null`) is correct here because this branch only runs when `hasBase` is true.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/changeset_writer_test.dart`
Expected: PASS (existing "first publish with data writes a base + manifest", the new reassemble test, and the noop/changeset tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/sync/changeset_log/changeset_writer.dart test/core/services/sync/changeset_log/changeset_writer_test.dart
flutter analyze lib/core/services/sync/changeset_log/changeset_writer.dart
git add lib/core/services/sync/changeset_log/changeset_writer.dart test/core/services/sync/changeset_log/changeset_writer_test.dart
git commit -m "fix(sync): stream base publish to fix iOS OOM on large libraries (#358)"
```

---

### Task 4: Wire `ChangesetWriter._compact` to the streaming path

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_writer.dart` (`_compact`)
- Test: `test/core/services/sync/changeset_log/changeset_writer_compaction_test.dart` (existing tests are the regression guard)

**Interfaces:**
- Consumes: `exportBaseToTempFile`, `BasePartFileSource`.
- Produces: unchanged `_compact(...) -> Future<int>` (the new base seq), same manifest/publish-state effects and pruning.

- [ ] **Step 1: Run the existing compaction tests to confirm the baseline**

Run: `flutter test test/core/services/sync/changeset_log/changeset_writer_compaction_test.dart`
Expected: PASS (before the change). These assert a compaction rewrites a fresh base + prunes; they will re-run after the change as the guard.

- [ ] **Step 2: Replace the base build in `_compact`**

In `_compact`, replace:

```dart
    final full = await _serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: null,
      deletions: deletions,
      epochId: epochId,
      uploadNonce: uploadNonce,
    );
    final fullBytes = _codec.encodeChangeset(full);
    // Slice the same bytes we checksum (serialize once) -- see publish().
    final parts = BaseChunker.slice(fullBytes);
    final compSeq = afterSeq + 1;
    for (var i = 0; i < parts.length; i++) {
      await provider.uploadFile(
        parts[i],
        ChangesetLogLayout.basePartName(deviceId, compSeq, i),
        folderId: folderId,
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final manifest = SyncManifest(
      deviceId: deviceId,
      provider: providerId,
      baseSeq: compSeq,
      basePartCount: parts.length,
      baseBytes: fullBytes.length,
      baseChecksum: BaseChunker.checksum(fullBytes),
      basePartChecksums: parts.map(BaseChunker.checksum).toList(),
      headSeq: compSeq,
      publishedHlcHigh: full.toHlc,
      epochId: epochId,
      uploadNonce: uploadNonce,
      updatedAt: now,
    );
```

with:

```dart
    final compSeq = afterSeq + 1;
    final base = await _serializer.exportBaseToTempFile(
      deviceId: deviceId,
      deletions: deletions,
      epochId: epochId,
      uploadNonce: uploadNonce,
      seq: compSeq,
    );
    final BasePartUploadResult upload;
    try {
      upload = await BasePartFileSource(base.path).uploadAll(
        (i, bytes) => provider.uploadFile(
          bytes,
          ChangesetLogLayout.basePartName(deviceId, compSeq, i),
          folderId: folderId,
        ),
      );
    } finally {
      try {
        await File(base.path).delete();
      } catch (_) {}
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final manifest = SyncManifest(
      deviceId: deviceId,
      provider: providerId,
      baseSeq: compSeq,
      basePartCount: upload.partCount,
      baseBytes: base.byteLength,
      baseChecksum: upload.wholeChecksum,
      basePartChecksums: upload.partChecksums,
      headSeq: compSeq,
      publishedHlcHigh: base.toHlc,
      epochId: epochId,
      uploadNonce: uploadNonce,
      updatedAt: now,
    );
```

Then update the `_publishState.upsert` in `_compact` to use `upload.partCount` / `base.byteLength` / `base.toHlc` in place of `parts.length` / `fullBytes.length` / `full.toHlc`. If `BaseChunker` is now unused in `changeset_writer.dart`, remove its import.

- [ ] **Step 3: Run the compaction tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/changeset_writer_compaction_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
dart format lib/core/services/sync/changeset_log/changeset_writer.dart
flutter analyze lib/core/services/sync/changeset_log/changeset_writer.dart
git add lib/core/services/sync/changeset_log/changeset_writer.dart
git commit -m "fix(sync): stream base compaction to bound memory (#358)"
```

---

### Task 5: Full verification (suite + format/analyze + device)

**Files:** none (verification only)

- [ ] **Step 1: Whole-project format + analyze**

Run: `dart format . && flutter analyze`
Expected: "0 issues found" and no formatting changes. (Format the whole project, not a subdir — the Analyze & Format CI check covers everything.)

- [ ] **Step 2: Run the full sync suite**

Run: `flutter test test/core/services/sync/`
Expected: all green (new parity/round-trip tests + all pre-existing sync tests, including the read-side `sync_base_streaming_parity_test.dart` and adopt parity).

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all green.

- [ ] **Step 4: Device verification on the iOS simulator**

The macOS dev instance already published the reporter's ~648 MB library (`base_bytes=648190516`, 78 parts) to S3. On the booted simulator (`B3558678-E6A7-4366-B806-FB1035E5511C`):

```bash
flutter run -d B3558678-E6A7-4366-B806-FB1035E5511C
```

Configure S3 sync (same bucket) and trigger a sync. Expected: the pull completes (streamed), then **publish completes without the crash/hang** (progress reaches "Sync complete"). Confirm the device's own manifest was written and its `base_part_count`/`base_bytes` match the macOS publisher (a full base was published in bounded memory). Watch memory in Xcode/Instruments or `flutter run` DevTools: peak stays bounded (no multi-GB spike during "Publishing changes...").

- [ ] **Step 5: Update memory + open PR** (after device verification)

Record the outcome (write-side #358 fixed, device-verified) and open a PR referencing #358, noting this completes the write half of the three OOM paths (read pull #365, read adopt #398, write publish this PR).

## Self-Review notes

- **Spec coverage:** `BasePartFileSource` (Task 1) ↔ read-side mirror; `exportBaseToTempFile` + keyset paging + seek-back checksum + composite-table handling (Task 2) ↔ mechanics section; both `ChangesetWriter` base sites (Tasks 3–4) ↔ "affected files"; semantic parity + round-trip + paging + device (Tasks 2–5) ↔ testing section. The `_baseTables` structural test enforces the 40-table order automatically.
- **Type consistency:** `StreamedBase`/`BasePartUploadResult` record fields are used identically across tasks (`byteLength`, `wholeChecksum`, `partChecksums`, `partCount`, `toHlc`, `rowCount`).
- **Known API risks to verify during Task 2 (analyzer/tests will catch):** `TableInfo.actualTableName` (fallback `entityName`) and `table.map(r.data)` dynamic `toJson`. These are the only non-obvious Drift touchpoints.
