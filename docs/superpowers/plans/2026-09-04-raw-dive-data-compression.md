# Raw Dive Data Compression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store `dive_data_sources.raw_data` zlib-compressed on disk, saving 2.5x to 4.8x on real dive computer downloads, with no change to any caller and no change to the sync wire format.

**Architecture:** A pure codec wraps each blob in a self-describing 8-byte header (`"SRD1"` plus a little-endian uint32 original length) ahead of a zlib stream. A Drift `TypeConverter` on the column applies it, so every read and write is covered and the sync layer keeps seeing uncompressed bytes. A v188 migration rung recompresses existing rows and signals the one VACUUM that `DatabaseService` already owns.

**Tech Stack:** Dart, Flutter, Drift 2.34.3, `dart:io` `ZLibCodec`, `sqlite3` via `NativeDatabase`.

**Spec:** `docs/superpowers/specs/2026-09-04-raw-dive-data-compression-design.md`

## Global Constraints

- **No em-dashes** anywhere: not in code, comments, doc comments, commit messages, or this plan's output. Also no en-dash or double-hyphen used as prose punctuation. Rewrite the sentence instead.
- **No emojis** in code, comments, or documentation.
- **TDD:** the failing test is written and run before the implementation, every task.
- **`lib/core/database/database.dart` and everything it imports must stay Flutter-free.** `test/core/database/database_import_graph_test.dart` walks the graph and fails on any `package:flutter/` or `package:flutter_` import. `dart:io` and `package:drift/drift.dart` are allowed; the existing profile-series codec already pulls in `dart:io`.
- **Immutability:** never mutate a caller's `Uint8List`. Both codec directions return a new list or the input unchanged.
- **`dart format .` must be run** over the whole project before the final commit.
- **Schema rung is v188**, claimed against `origin/main` at schema version 187. Re-verify at the start of Task 3 that no newly merged or open pull request has taken 188.
- **The sync wire format does not change.** `minimumCompatibleSchemaVersion` is not touched. Peers keep exchanging uncompressed, base64-encoded bytes.
- **`raw_fingerprint` is not touched** in any task.
- Run tests one file or one directory at a time. Never overlap two local `flutter test` runs, and never pipe a test run into `grep`: the pipe reports the exit status of `grep`, not of the test run.

## Constants Used Across Tasks

Defined once in Task 1, referenced by every later task:

| Name | Value | Meaning |
|---|---|---|
| `kRawDiveDataMagic` | `[0x53, 0x52, 0x44, 0x31]` (ASCII `SRD1`) | Marks a compressed blob. |
| `kRawDiveDataHeaderBytes` | `8` | Magic (4) plus uint32 length (4). |
| `kMaxRawDiveBlobBytes` | `8 * 1024 * 1024` | Both the decode bound and the encode refusal threshold. |

---

### Task 1: The codec

A pure module: no Drift, no database, no I/O. Everything about the byte format lives here and is fully tested here, so Task 2 only has to wire it up.

**Files:**
- Create: `lib/core/database/raw_dive_data_codec.dart`
- Test: `test/core/database/raw_dive_data_codec_test.dart`

**Interfaces:**
- Consumes: `inflateBounded` and `BoundedInflateException` from `lib/core/utils/bounded_inflate.dart`.
- Produces:
  - `const List<int> kRawDiveDataMagic`
  - `const int kRawDiveDataHeaderBytes`
  - `const int kMaxRawDiveBlobBytes`
  - `Uint8List encodeRawDiveData(Uint8List raw)`
  - `Uint8List decodeRawDiveData(Uint8List stored)`
  - `bool isCompressedRawDiveData(Uint8List stored)`
  - `class RawDiveDataConverter extends TypeConverter<Uint8List, Uint8List>` with `const RawDiveDataConverter()`

- [ ] **Step 1: Write the failing test**

Create `test/core/database/raw_dive_data_codec_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';

/// The three fixtures are the real libdivecomputer downloads already
/// committed to this repository. Compressing a synthetic byte pattern would
/// measure the pattern, not the payload, and the 2026-04-15 spec's "negligible
/// savings" ruling came from exactly that mistake.
Uint8List fixture(String path) =>
    Uint8List.fromList(File(path).readAsBytesSync());

const teric =
    'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
    'shearwater_teric_dive.bin';
const petrel3 =
    'packages/libdivecomputer_plugin/test/native/fixtures/'
    'petrel3_ccr_o2_cells.bin';
const smallDive =
    'packages/libdivecomputer_plugin/test/native/fixtures/dive1_raw.bin';

void main() {
  group('round trip', () {
    for (final path in [teric, petrel3, smallDive]) {
      test('$path survives encode then decode and gets smaller', () {
        final raw = fixture(path);
        final encoded = encodeRawDiveData(raw);

        expect(encoded.length, lessThan(raw.length));
        expect(isCompressedRawDiveData(encoded), isTrue);
        expect(decodeRawDiveData(encoded), equals(raw));
      });
    }
  });

  test('encode does not mutate its input', () {
    final raw = fixture(teric);
    final before = Uint8List.fromList(raw);

    encodeRawDiveData(raw);

    expect(raw, equals(before));
  });

  test('incompressible bytes are stored raw and read back unchanged', () {
    // 32 random-looking bytes: zlib cannot beat 8 bytes of header plus its
    // own framing on a payload this small.
    final raw = Uint8List.fromList(
      List<int>.generate(32, (i) => (i * 97 + 13) & 0xFF),
    );

    final encoded = encodeRawDiveData(raw);

    expect(encoded, equals(raw));
    expect(isCompressedRawDiveData(encoded), isFalse);
    expect(decodeRawDiveData(encoded), equals(raw));
  });

  test('legacy bytes with no magic pass through untouched', () {
    final legacy = fixture(teric);

    expect(decodeRawDiveData(legacy), equals(legacy));
  });

  test('a legacy blob that begins with the magic reads back as itself', () {
    // The one collision the format cannot rule out by the magic alone. It
    // survives because decode also requires the body to inflate to exactly
    // the declared length, and this body is not a zlib stream at all.
    final legacy = Uint8List.fromList([
      ...kRawDiveDataMagic,
      0xFF, 0xFF, 0xFF, 0xFF,
      1, 2, 3, 4, 5, 6, 7, 8,
    ]);

    expect(decodeRawDiveData(legacy), equals(legacy));
  });

  test('a truncated stream behind a valid magic reads back as stored', () {
    // zlib accepts a truncated stream and returns what it managed to inflate,
    // with no error. Only the declared-length check catches this.
    final encoded = encodeRawDiveData(fixture(teric));
    final truncated = Uint8List.sublistView(encoded, 0, encoded.length - 40);

    expect(decodeRawDiveData(truncated), equals(truncated));
  });

  test('a declared length past the cap is refused, not inflated', () {
    final encoded = encodeRawDiveData(fixture(teric));
    final tampered = Uint8List.fromList(encoded);
    ByteData.sublistView(tampered).setUint32(4, 0x7FFFFFFF, Endian.little);

    expect(decodeRawDiveData(tampered), equals(tampered));
  });

  test('a zlib bomb is abandoned, not inflated', () {
    // 64 MiB of zeroes compresses to a few tens of KiB and is well past
    // kMaxRawDiveBlobBytes, so the bound must stop it mid-stream.
    final bomb = ZLibCodec(level: 9).encode(Uint8List(64 * 1024 * 1024));
    final blob = Uint8List.fromList([
      ...kRawDiveDataMagic,
      0x00, 0x00, 0x00, 0x04, // declares 64 MiB, little-endian
      ...bomb,
    ]);

    expect(decodeRawDiveData(blob), equals(blob));
  });

  test('a blob over the cap is stored raw so decode can still read it', () {
    // The encoder must never mint something its own decode bound refuses.
    final huge = Uint8List(kMaxRawDiveBlobBytes + 1);

    final encoded = encodeRawDiveData(huge);

    expect(encoded, same(huge));
    expect(decodeRawDiveData(encoded), equals(huge));
  });

  test('empty and single-byte blobs round trip', () {
    for (final raw in [Uint8List(0), Uint8List.fromList([42])]) {
      final encoded = encodeRawDiveData(raw);
      expect(decodeRawDiveData(encoded), equals(raw));
    }
  });

  group('RawDiveDataConverter', () {
    const converter = RawDiveDataConverter();

    test('toSql compresses and fromSql restores', () {
      final raw = fixture(teric);
      final stored = converter.toSql(raw);

      expect(stored.length, lessThan(raw.length));
      expect(converter.fromSql(stored), equals(raw));
    });

    test('fromSql reads a legacy uncompressed row', () {
      final legacy = fixture(teric);

      expect(converter.fromSql(legacy), equals(legacy));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/core/database/raw_dive_data_codec_test.dart
```

Expected: FAIL at compile time with "Target of URI doesn't exist: 'package:submersion/core/database/raw_dive_data_codec.dart'".

- [ ] **Step 3: Write the implementation**

Create `lib/core/database/raw_dive_data_codec.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:submersion/core/utils/bounded_inflate.dart';

/// The at-rest encoding for `dive_data_sources.raw_data` (issue #227).
///
/// The raw bytes libdivecomputer handed back at download time are the only
/// thing that makes a later re-parse possible, so they are kept forever and
/// there is no second copy to fall back on. Every rule here exists to make
/// losing one impossible.
///
/// A stored blob is either the compressed form:
///
/// ```text
/// offset  size  meaning
/// 0       4     magic, ASCII "SRD1"
/// 4       4     uint32 little-endian, length of the original bytes
/// 8       n     zlib stream (level 6) of the original bytes
/// ```
///
/// or the original bytes verbatim. Nothing else records which, so the header
/// is the only discriminator and a blob carries its own answer. That is what
/// lets a partially migrated table, a row inbound from a peer that has not
/// updated, and a blob that simply does not compress all sit in one column
/// with no state to consult, and it is what lets `DiveMergeService` keep
/// copying provenance rows wholesale without knowing this format exists.
///
/// The digit in the magic is the extension point: a future codec mints
/// "SRD2" and this decoder keeps reading "SRD1" for as long as any diver's
/// database still holds one, which is forever.
const List<int> kRawDiveDataMagic = [0x53, 0x52, 0x44, 0x31];

/// Magic (4 bytes) plus the uint32 original length (4 bytes).
const int kRawDiveDataHeaderBytes = 8;

/// The largest blob this codec will compress, and the largest it will inflate.
///
/// One constant for both directions on purpose. A decode bound without a
/// matching encode refusal would let the encoder mint a blob its own decoder
/// rejects, which would read back as compressed garbage: the exact data loss
/// this file exists to prevent. 8 MiB is far above any dive a computer
/// records and far below anything that threatens memory.
const int kMaxRawDiveBlobBytes = 8 * 1024 * 1024;

/// Level 6. Level 9 was measured on all three committed fixtures and gained
/// under 1.2%, which does not pay for its time. Not `const`: `ZLibCodec` has
/// no const constructor.
final ZLibCodec _zlib = ZLibCodec(level: 6);

/// True when [stored] carries the compressed header.
///
/// A cheap prefix test for callers that want to skip work, such as the v188
/// migration deciding whether a row is already packed. It is NOT proof the
/// body is intact; only [decodeRawDiveData] establishes that.
bool isCompressedRawDiveData(Uint8List stored) {
  if (stored.length < kRawDiveDataHeaderBytes) return false;
  for (var i = 0; i < kRawDiveDataMagic.length; i++) {
    if (stored[i] != kRawDiveDataMagic[i]) return false;
  }
  return true;
}

/// Returns the at-rest form of [raw].
///
/// Compressed only when that is strictly smaller AND within
/// [kMaxRawDiveBlobBytes]; otherwise [raw] itself, unchanged and uncopied.
/// Never mutates [raw].
Uint8List encodeRawDiveData(Uint8List raw) {
  if (raw.length > kMaxRawDiveBlobBytes) return raw;

  final body = _zlib.encode(raw);
  final total = kRawDiveDataHeaderBytes + body.length;
  if (total >= raw.length) return raw;

  final out = Uint8List(total);
  out.setRange(0, kRawDiveDataMagic.length, kRawDiveDataMagic);
  ByteData.sublistView(out).setUint32(4, raw.length, Endian.little);
  out.setRange(kRawDiveDataHeaderBytes, total, body);
  return out;
}

/// Returns the original bytes behind [stored].
///
/// Falls back to [stored] itself on anything that is not a well-formed
/// compressed blob, and never throws. A converter that threw would break
/// ordinary row mapping for the whole table, taking down pages that never
/// wanted the raw bytes; a damaged blob instead degrades into a re-parse
/// failure, which `ReparseService` already counts and surfaces.
///
/// The declared length is load-bearing twice. It bounds the inflate, and it
/// is checked afterwards: zlib accepts a truncated stream and returns what it
/// managed to inflate with no error at all, so length equality is the only
/// completeness check available.
Uint8List decodeRawDiveData(Uint8List stored) {
  if (!isCompressedRawDiveData(stored)) return stored;

  final declared = ByteData.sublistView(
    stored,
    4,
    kRawDiveDataHeaderBytes,
  ).getUint32(0, Endian.little);
  // The declared length reaches 4 GiB and is not trustworthy on its own, so
  // it bounds the inflate only while it is the smaller of the two.
  final cap = declared < kMaxRawDiveBlobBytes ? declared : kMaxRawDiveBlobBytes;

  try {
    final inflated = inflateBounded(
      Uint8List.sublistView(stored, kRawDiveDataHeaderBytes),
      decoder: _zlib.decoder,
      maxBytes: cap,
      maxBlobBytes: kMaxRawDiveBlobBytes,
    );
    if (inflated.length != declared) return stored;
    return inflated;
  } on BoundedInflateException {
    return stored;
  }
}

/// Applies [encodeRawDiveData] and [decodeRawDiveData] to every read and
/// write of the column.
///
/// A converter rather than encoding at the call sites, because the two
/// mistakes are not symmetrical: a write site that forgets to encode stores a
/// raw blob that still reads back correctly, so the bug is invisible, while a
/// read site that forgets to decode hands compressed bytes to
/// libdivecomputer. It is also what keeps sync transparent. Every sync path
/// for this table goes through the row's `toJson`/`fromJson`, which operate
/// on the converted Dart value, so peers keep exchanging uncompressed bytes
/// and no schema floor has to be raised.
class RawDiveDataConverter extends TypeConverter<Uint8List, Uint8List> {
  const RawDiveDataConverter();

  @override
  Uint8List fromSql(Uint8List fromDb) => decodeRawDiveData(fromDb);

  @override
  Uint8List toSql(Uint8List value) => encodeRawDiveData(value);
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/core/database/raw_dive_data_codec_test.dart
```

Expected: PASS, all tests.

- [ ] **Step 5: Confirm the file did not break the import graph**

```bash
flutter test test/core/database/database_import_graph_test.dart
```

Expected: PASS. Nothing imports the codec yet, so this is the baseline that Task 2 must preserve.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/core/database/raw_dive_data_codec.dart test/core/database/raw_dive_data_codec_test.dart
git commit -m "feat(db): codec for compressed raw dive computer data (#227)"
```

---

### Task 2: Apply the converter to the column

Wiring the codec onto `dive_data_sources.raw_data`. Every existing caller keeps its `Uint8List?` type, so nothing outside `database.g.dart` should need editing. The sync assertion in this task is the contract that keeps compressed bytes off the wire.

**Files:**
- Modify: `lib/core/database/database.dart:2610`
- Modify: `lib/core/database/database.g.dart` (regenerated, not hand-edited)
- Test: `test/core/database/raw_data_column_converter_test.dart` (create)
- Test: `test/features/dive_computer/data/services/reparse_service_test.dart` (add one test)
- Test: `test/core/services/sync/sync_serializer_round_trip_test.dart` (add one test)

**Interfaces:**
- Consumes: `RawDiveDataConverter`, `encodeRawDiveData`, `isCompressedRawDiveData` from Task 1.
- Produces: nothing new. The `DiveDataSourcesData.rawData` field stays `Uint8List?`, now holding decoded bytes.

- [ ] **Step 1: Write the failing column test**

Create `test/core/database/raw_data_column_converter_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';

/// The column stores compressed bytes and hands back the original ones. What
/// is asserted here is the seam itself: what SQLite holds, read with raw SQL
/// that bypasses the converter, versus what the row class returns.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Uint8List teric() => Uint8List.fromList(
    File(
      'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
      'shearwater_teric_dive.bin',
    ).readAsBytesSync(),
  );

  // Through the companion, not raw SQL: `dives` has required columns this
  // test has no business hard-coding, and a missing one is then a compile
  // error naming the field rather than a runtime NOT NULL failure. The
  // parent row is not optional; `beforeOpen` turns foreign keys on, so a
  // dive_data_sources insert without it will not even prepare.
  Future<void> seedDive(String diveId) async {
    await db
        .into(db.dives)
        .insert(DivesCompanion.insert(id: diveId, diveDateTime: 0));
  }

  test('a written blob lands compressed and reads back identical', () async {
    final raw = teric();
    await seedDive('d1');
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 's1',
            diveId: 'd1',
            importedAt: DateTime.fromMillisecondsSinceEpoch(0),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            rawData: Value(raw),
          ),
        );

    final onDisk = await db
        .customSelect('SELECT raw_data FROM dive_data_sources WHERE id = ?',
            variables: [Variable('s1')])
        .getSingle();
    final storedBytes = onDisk.read<Uint8List>('raw_data');

    expect(isCompressedRawDiveData(storedBytes), isTrue);
    expect(storedBytes.length, lessThan(raw.length));

    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('s1'))).getSingle();
    expect(row.rawData, equals(raw));
  });

  test('a legacy uncompressed row still reads back correctly', () async {
    // The state every existing database is in before the v188 rung, and the
    // state a row inbound from a peer that has not updated arrives in.
    final raw = teric();
    await seedDive('d2');
    await db.customStatement(
      'INSERT INTO dive_data_sources '
      '(id, dive_id, is_primary, imported_at, created_at, raw_data) '
      'VALUES (?, ?, 0, 0, 0, ?)',
      ['s2', 'd2', raw],
    );

    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('s2'))).getSingle();

    expect(row.rawData, equals(raw));
  });

  test('a null blob stays null in both directions', () async {
    await seedDive('d3');
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 's3',
            diveId: 'd3',
            importedAt: DateTime.fromMillisecondsSinceEpoch(0),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );

    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('s3'))).getSingle();

    expect(row.rawData, isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/core/database/raw_data_column_converter_test.dart
```

Expected: FAIL on the first test, at `expect(isCompressedRawDiveData(storedBytes), isTrue)`, because the column stores the bytes verbatim today.

- [ ] **Step 3: Apply the converter**

In `lib/core/database/database.dart`, add the import next to the other `package:submersion/core/...` imports:

```dart
import 'package:submersion/core/database/raw_dive_data_codec.dart';
```

Then change the column at line 2610 from:

```dart
  BlobColumn get rawData => blob().nullable()();
```

to:

```dart
  /// The raw bytes libdivecomputer returned for this download, zlib-compressed
  /// at rest behind a self-describing header (issue #227). The converter runs
  /// on every read and write, so callers see the original bytes and the sync
  /// layer keeps exchanging them uncompressed. See [RawDiveDataConverter].
  BlobColumn get rawData =>
      blob().map(const RawDiveDataConverter()).nullable()();
```

Drift wraps a non-nullable converter on a nullable column with
`NullAwareTypeConverter`, so `null` maps to `null` in both directions and the
generated field stays `Uint8List?`.

- [ ] **Step 4: Regenerate the Drift code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `database.g.dart` regenerates with a `$converterrawData` field. If the command is refused because the bare word `build` matches a read-deny rule, run it from a script in the scratchpad directory instead.

- [ ] **Step 5: Run the column test to verify it passes**

```bash
flutter test test/core/database/raw_data_column_converter_test.dart
```

Expected: PASS, all three tests.

- [ ] **Step 6: Write the re-parse round-trip test**

Append to `test/features/dive_computer/data/services/reparse_service_test.dart`, inside the existing top-level `main`:

```dart
  test('re-parse receives the exact bytes that were downloaded', () async {
    // The path that matters most: these bytes go straight to
    // libdivecomputer, and a decode this misses would hand it a zlib stream.
    final raw = Uint8List.fromList(
      File(
        'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
        'shearwater_teric_dive.bin',
      ).readAsBytesSync(),
    );
    await db
        .into(db.dives)
        .insert(DivesCompanion.insert(id: 'dive-raw', diveDateTime: 0));
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-raw',
            diveId: 'dive-raw',
            importedAt: DateTime.fromMillisecondsSinceEpoch(0),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            rawData: Value(raw),
          ),
        );

    final sources = await service.getSourcesForDiveReparse('dive-raw');

    expect(sources, hasLength(1));
    expect(sources.single.rawData, equals(raw));
  });
```

Add `import 'dart:io';` and `import 'dart:typed_data';` to that file if they
are not already present. Reuse whatever `db` and `service` the existing
`setUp` in that file builds; do not introduce a second harness.

- [ ] **Step 7: Run the re-parse test**

```bash
flutter test test/features/dive_computer/data/services/reparse_service_test.dart
```

Expected: PASS, the new test and every existing one.

- [ ] **Step 8: Write the sync wire-contract test**

This is the load-bearing assertion of the whole change. Append to
`test/core/services/sync/sync_serializer_round_trip_test.dart`, inside the
existing top-level `main`:

```dart
  test('sync exports raw dive data uncompressed (#227 wire contract)', () async {
    // Compression is at-rest only. Sync payloads are gzipped whole before
    // encryption, so compressing this column would buy nothing on the wire,
    // and shipping compressed bytes would need the schema floor raised, which
    // stops older peers syncing at all. If this test ever fails, the fix is
    // to put the encoding back behind the column converter, NOT to update the
    // expectation.
    final raw = Uint8List.fromList(
      File(
        'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
        'shearwater_teric_dive.bin',
      ).readAsBytesSync(),
    );
    await db
        .into(db.dives)
        .insert(DivesCompanion.insert(id: 'dive-wire', diveDateTime: 0));
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-wire',
            diveId: 'dive-wire',
            importedAt: DateTime.fromMillisecondsSinceEpoch(0),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            rawData: Value(raw),
          ),
        );

    final payload = await serializer.exportData();
    final row = payload.diveDataSources.singleWhere(
      (r) => r['id'] == 'src-wire',
    );

    expect(base64Decode(row['rawData'] as String), equals(raw));
  });
```

Add `import 'dart:convert';`, `import 'dart:io';` and `import 'dart:typed_data';`
if absent. Reuse the file's existing `db` and `serializer` from its `setUp`. If
the serializer's export entry point or the JSON key differs from `exportData()`
and `rawData`, match what the file's existing tests already use rather than
inventing a name.

- [ ] **Step 9: Run the sync test**

```bash
flutter test test/core/services/sync/sync_serializer_round_trip_test.dart
```

Expected: PASS.

- [ ] **Step 10: Run the surrounding suites for regressions**

One at a time, never overlapping:

```bash
flutter test test/core/database
```

```bash
flutter test test/core/services/sync
```

```bash
flutter test test/features/dive_computer
```

```bash
flutter test test/features/dive_log
```

Expected: PASS. `database_import_graph_test` is inside the first run and must
still be green now that `database.dart` imports the codec.

- [ ] **Step 11: Format and commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/core/database/raw_dive_data_codec.dart test/core/database/raw_data_column_converter_test.dart test/features/dive_computer/data/services/reparse_service_test.dart test/core/services/sync/sync_serializer_round_trip_test.dart
git commit -m "feat(db): compress raw dive data at rest via a column converter (#227)"
```

---

### Task 3: The v188 rung

New downloads compress from Task 2 onward. This rung is what reaches the bytes
already on disk, which is where the savings actually are: the divers with the
most raw data are the ones who have been downloading longest.

**Files:**
- Modify: `lib/core/database/database.dart` (version constant, `migrationVersions`, the rung body, the new flag)
- Test: `test/core/database/migration_v188_raw_data_compression_test.dart` (create)
- Test: `test/core/database/migration_v187_session_item_overdue_services_test.dart:54` (hand over the tripwire)

**Interfaces:**
- Consumes: `encodeRawDiveData`, `isCompressedRawDiveData` from Task 1.
- Produces: `bool get AppDatabase.recompressedRawBlobs` and
  `bool get AppDatabase.hasUnreclaimedPages`, both read by Task 4.

- [ ] **Step 1: Re-verify the rung number**

```bash
git fetch origin main && git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "
```

Expected: `187`. If another branch has taken 188 since, use the next free
number and substitute it everywhere below, including the test filename.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v188_raw_data_compression_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';

/// v188 (issue #227): recompress `dive_data_sources.raw_data` in place.
///
/// No DDL. The column's SQL type does not change; only the stored bytes move,
/// and the self-describing header means a row the rung skips keeps reading
/// correctly forever. That is what lets the rung be guarded per row: a blob
/// left uncompressed costs space and nothing else, and nothing about one bad
/// row justifies refusing to open the database that holds the diver's log.
void main() {
  Uint8List teric() => Uint8List.fromList(
    File(
      'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
      'shearwater_teric_dive.bin',
    ).readAsBytesSync(),
  );

  // Stamped at 187 so ONLY the v188 step runs, isolating what is asserted.
  NativeDatabase setupDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 187');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            raw_data BLOB,
            raw_fingerprint BLOB
          )
        ''');
        rawDb.execute("INSERT INTO dives (id) VALUES ('d1')");
        seed(rawDb);
      },
    );
  }

  void insertSource(dynamic rawDb, String id, Uint8List? raw) {
    rawDb.execute(
      'INSERT INTO dive_data_sources '
      '(id, dive_id, is_primary, imported_at, created_at, raw_data) '
      'VALUES (?, ?, 0, 0, 0, ?)',
      [id, 'd1', raw],
    );
  }

  Future<Uint8List?> storedBytes(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          'SELECT raw_data FROM dive_data_sources WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingle();
    return row.readNullable<Uint8List>('raw_data');
  }

  test('v188 is the current schema version and is in the ladder', () {
    // The latest-version tripwire lives in the newest migration's test.
    expect(AppDatabase.currentSchemaVersion, 188);
    expect(AppDatabase.migrationVersions, contains(188));
  });

  test('compresses existing rows without changing what they mean', () async {
    final raw = teric();
    final db = AppDatabase(setupDb((rawDb) => insertSource(rawDb, 's1', raw)));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    final stored = (await storedBytes(db, 's1'))!;
    expect(isCompressedRawDiveData(stored), isTrue);
    expect(stored.length, lessThan(raw.length));
    // Decoded by hand rather than through `db.select(db.diveDataSources)`:
    // the fixture table above carries only the columns this rung reads, so a
    // Drift select over the full table would fail on the absent ones. Task 2
    // already proves the converter is wired to the column.
    expect(decodeRawDiveData(stored), equals(raw));
    expect(db.recompressedRawBlobs, isTrue);
  });

  test('leaves a row alone when compression would not help', () async {
    final incompressible = Uint8List.fromList(
      List<int>.generate(24, (i) => (i * 31 + 7) & 0xFF),
    );
    final db = AppDatabase(
      setupDb((rawDb) => insertSource(rawDb, 's2', incompressible)),
    );
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    expect(await storedBytes(db, 's2'), equals(incompressible));
  });

  test('a database with no raw data does not claim a reclaim', () async {
    final db = AppDatabase(setupDb((rawDb) => insertSource(rawDb, 's3', null)));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    expect(db.recompressedRawBlobs, isFalse);
    expect(db.hasUnreclaimedPages, isFalse);
  });

  test('is idempotent: a second run re-packs nothing', () async {
    final raw = teric();
    final db = AppDatabase(setupDb((rawDb) => insertSource(rawDb, 's4', raw)));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final afterFirst = await storedBytes(db, 's4');

    await db.recompressRawDiveDataForTest();

    expect(await storedBytes(db, 's4'), equals(afterFirst));
  });

  test('a row the encoder cannot pack leaves the database openable', () async {
    // The v182 profile-series rung had an unguarded pack step that could
    // leave a database that would not open. This rung must not repeat it, so
    // an oversized blob (which the encoder declines) has to be a no-op for
    // that row and a non-event for every other one.
    final raw = teric();
    final oversized = Uint8List(kMaxRawDiveBlobBytes + 1);
    final db = AppDatabase(
      setupDb((rawDb) {
        insertSource(rawDb, 's5', oversized);
        insertSource(rawDb, 's6', raw);
      }),
    );
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    expect(await storedBytes(db, 's5'), equals(oversized));
    expect(isCompressedRawDiveData((await storedBytes(db, 's6'))!), isTrue);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

```bash
flutter test test/core/database/migration_v188_raw_data_compression_test.dart
```

Expected: FAIL on the first test with `Expected: <188> Actual: <187>`, and on
the rest with "The method 'recompressedRawBlobs' isn't defined".

- [ ] **Step 4: Bump the version and register the rung**

In `lib/core/database/database.dart`, change line 3377:

```dart
  static const int currentSchemaVersion = 188;
```

Append to the end of the `migrationVersions` list, after `187`:

```dart
    // v188: recompress dive_data_sources.raw_data in place (issue #227).
    // No DDL; the column's SQL type is unchanged and only the stored bytes
    // move. Guarded per row: the self-describing header means a row this
    // rung skips keeps reading correctly forever, so a blob left
    // uncompressed costs space and nothing else.
    188,
```

- [ ] **Step 5: Write the rung body and the reclaim flag**

Add next to `_backfillMergeSourceSlots` in `lib/core/database/database.dart`:

```dart
  /// v188: rewrite `dive_data_sources.raw_data` in its compressed at-rest
  /// form (issue #227).
  ///
  /// PRAGMA-guarded like every other data rung, so a partial schema no-ops
  /// rather than throwing. Rows already carrying the magic are skipped, which
  /// is what makes a second run free and an interrupted run cost only the
  /// work it already did.
  ///
  /// Every row is guarded on its own. An unguarded pack step in the v182
  /// profile-series rung could leave a database that would not open, which is
  /// the worst outcome available to a migration and the one this rung is
  /// closest to repeating. A row that will not pack is left exactly as it is
  /// and logged; nothing about it justifies refusing to open the diver's log.
  Future<void> _recompressRawDiveData() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('id') || !names.contains('raw_data')) return;

    const pageSize = 200;
    String? cursor;
    while (true) {
      final page = await customSelect(
        'SELECT id, raw_data FROM dive_data_sources '
        'WHERE raw_data IS NOT NULL${cursor == null ? '' : ' AND id > ?'} '
        'ORDER BY id LIMIT $pageSize',
        variables: [if (cursor != null) Variable(cursor)],
      ).get();
      if (page.isEmpty) break;
      cursor = page.last.read<String>('id');

      for (final row in page) {
        final id = row.read<String>('id');
        final stored = row.read<Uint8List>('raw_data');
        if (isCompressedRawDiveData(stored)) continue;
        try {
          final packed = encodeRawDiveData(stored);
          if (packed.length >= stored.length) continue;
          await customStatement(
            'UPDATE dive_data_sources SET raw_data = ? WHERE id = ?',
            [packed, id],
          );
          _recompressedRawBlobs = true;
        } catch (e, stackTrace) {
          // `developer.log` is what this file already uses (see the v182
          // pack). AppDatabase has no logger field, and it must stay
          // Flutter-free, so do not introduce one.
          _rawBlobsLeftUncompressed++;
          developer.log(
            'v188 left raw_data on dive_data_sources row $id uncompressed; '
            'the bytes are intact and still readable',
            name: 'AppDatabase',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
      if (page.length < pageSize) break;
    }
  }

  bool _recompressedRawBlobs = false;
  int _rawBlobsLeftUncompressed = 0;

  /// How many rows the v188 rung could not pack on this connection.
  ///
  /// Counted rather than only logged: a swallowed exception with nothing but
  /// a log line is invisible to any test, and the one thing worth proving
  /// about this rung is that a row it cannot pack changes nothing else.
  int get rawBlobsLeftUncompressed => _rawBlobsLeftUncompressed;

  /// True once this connection's v188 rung has actually shrunk at least one
  /// `raw_data` blob.
  ///
  /// The rewritten pages go to the freelist, and only a VACUUM returns them
  /// to the filesystem. Keyed off the event rather than the stored version
  /// for the same reason as [droppedLegacySampleTables]: a file with no raw
  /// data crosses this rung without earning a reclaim, and rewriting it would
  /// cost a diver a full-file VACUUM for nothing.
  bool get recompressedRawBlobs => _recompressedRawBlobs;

  /// True when this connection did something whose freed pages are still held
  /// by the file. The single signal [DatabaseService] reads to decide whether
  /// its one VACUUM is worth taking.
  bool get hasUnreclaimedPages =>
      droppedLegacySampleTables || recompressedRawBlobs;

  /// Test hook: run the v188 recompression on demand so tests can assert it
  /// is idempotent. Not used in production; the migration calls the private
  /// method.
  Future<void> recompressRawDiveDataForTest() => _recompressRawDiveData();
```

`database.dart` already imports `dart:developer` for the v182 pack's logging;
confirm the import is present and reuse it. Do NOT add a logger field:
`AppDatabase` has none, and the file must stay Flutter-free.

`rawBlobsLeftUncompressed` has no test that drives it above zero, because
there is no seam to force `encodeRawDiveData` to throw: an oversized blob is
declined rather than thrown on, and that path is covered. The counter exists so
the swallowed exception is observable at all, which a bare log line is not.
Record it as a known untested residual rather than inventing a seam for it.

Then add the rung to `onUpgrade`, immediately after the `from < 187` pair
around line 10029:

```dart
        // v188: recompress dive_data_sources.raw_data in place (issue #227).
        // No DDL. Guarded per row, so a blob that will not pack is left as it
        // is rather than failing the ladder.
        if (from < 188) {
          await _recompressRawDiveData();
        }
        if (from < 188) await reportProgress();
```

Do NOT add a `beforeOpen` backstop for this rung. The backstops exist to
re-assert schema a partial upgrade may have missed; this rung changes no
schema, and a row it skipped reads correctly regardless.

- [ ] **Step 6: Hand the tripwire to the new test**

In `test/core/database/migration_v187_session_item_overdue_services_test.dart`,
change line 54 from:

```dart
    expect(AppDatabase.currentSchemaVersion, 187);
```

to:

```dart
    // v187 is now a past migration; the latest-version tripwire lives in the
    // newest migration's test (migration_v188_raw_data_compression_test.dart),
    // so assert membership rather than equality.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(187));
    expect(AppDatabase.migrationVersions, contains(187));
```

- [ ] **Step 7: Run both migration tests**

```bash
flutter test test/core/database/migration_v188_raw_data_compression_test.dart test/core/database/migration_v187_session_item_overdue_services_test.dart
```

Expected: PASS, both files.

- [ ] **Step 8: Run the whole database directory**

```bash
flutter test test/core/database
```

Expected: PASS. Other migration tests assert ladder membership and step
counts, so this is where a mis-registered rung shows up.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/core/database/database.dart test/core/database/migration_v188_raw_data_compression_test.dart test/core/database/migration_v187_session_item_overdue_services_test.dart
git commit -m "feat(db): v188 recompresses existing raw dive data (#227)"
```

---

### Task 4: Reclaim the pages, and verify

The rung moves the old pages to the freelist. `DatabaseService` already owns
exactly one VACUUM per open, and this task teaches its two gates about the new
reclaim signal. Two lines of production code, then the full verification pass.

**Files:**
- Modify: `lib/core/services/database_service.dart:378`
- Modify: `lib/core/services/database_service.dart:472`

**Interfaces:**
- Consumes: `AppDatabase.hasUnreclaimedPages` from Task 3.
- Produces: nothing.

- [ ] **Step 1: Read the two gates before touching them**

```bash
sed -n '336,344p;374,382p;460,480p' lib/core/services/database_service.dart
```

Confirm line 378 reads `!willVacuum && migrator.droppedLegacySampleTables` and
line 472 reads `if (database.droppedLegacySampleTables) {`. The line numbers
shift if Task 3 touched this file, which it should not have.

- [ ] **Step 2: Widen the migration-path gate**

At line 378, change:

```dart
      final unplannedReclaim =
          !willVacuum && migrator.droppedLegacySampleTables;
```

to:

```dart
      // v188 (issue #227) recompresses raw_data in place, which frees pages
      // the same way the v183 drop did. A file upgrading from 184 or later
      // has willVacuum false, so the recompression reaches the one VACUUM
      // through this branch, unannounced as a progress step. The totals were
      // fixed before the ladder started, and reporting an unplanned reclaim
      // as a step would send the bar past its own total.
      final unplannedReclaim = !willVacuum && migrator.hasUnreclaimedPages;
```

Leave `willVacuum` and its `storedBefore < 183` gate exactly as they are. A
file old enough to plan a VACUUM already gets one.

- [ ] **Step 3: Widen the background-open gate**

At line 472, change:

```dart
    if (database.droppedLegacySampleTables) {
```

to:

```dart
    if (database.hasUnreclaimedPages) {
```

The comment above it names the v183 backstop specifically. Extend its last
paragraph rather than replacing it:

```dart
    // The v188 recompression reaches this the same way if it ever runs on an
    // open with no pending ladder. It cannot today, but the gate is one
    // signal so a future rung that frees pages does not have to remember to
    // add itself in two places.
```

- [ ] **Step 4: Run the database service tests**

```bash
flutter test test/core/services
```

Expected: PASS.

- [ ] **Step 5: Verify the compression end to end on real bytes**

Confirm the ratios the spec claims. This has to run inside the package, or
`package:submersion/...` will not resolve, so it goes in `test/` as a
throwaway and is deleted in the same step. Create
`test/core/database/scratch_ratio_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';

void main() {
  test('measured ratios', () {
    const paths = [
      'packages/libdivecomputer_plugin/test/native/fixtures/dive1_raw.bin',
      'packages/libdivecomputer_plugin/test/native/fixtures/'
          'petrel3_ccr_o2_cells.bin',
      'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
          'shearwater_teric_dive.bin',
    ];
    for (final path in paths) {
      final raw = Uint8List.fromList(File(path).readAsBytesSync());
      final packed = encodeRawDiveData(raw);
      final ratio = (raw.length / packed.length).toStringAsFixed(2);
      // ignore: avoid_print
      print('$path ${raw.length} -> ${packed.length} (${ratio}x)');
      expect(decodeRawDiveData(packed), equals(raw));
    }
  });
}
```

```bash
flutter test test/core/database/scratch_ratio_test.dart
```

Expected printed ratios of about 1.22x, 2.51x and 4.75x, matching the spec's
table, and a passing round trip. Then delete the file:

```bash
rm test/core/database/scratch_ratio_test.dart
```

If a ratio is materially below the spec's, stop and report it rather than
adjusting the spec: the whole case for this change rests on that table.

- [ ] **Step 6: Run the full suite**

```bash
flutter test
```

Expected: PASS, apart from the known `local_file_resolver_test.dart` flake,
which passes when run alone and is a `TMPDIR` artifact rather than a
regression. If it fails, re-run that one file by itself to confirm.

- [ ] **Step 7: Analyze the whole project**

```bash
flutter analyze
```

Expected: no issues. Infos are fatal in CI, so treat any output as a failure.
Do not pipe this into `grep`: the pipe masks the exit status.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/core/services/database_service.dart
git commit -m "feat(db): reclaim the pages v188 frees (#227)"
```

- [ ] **Step 9: Stop for push authorization**

Do not push and do not open a pull request. Report the four commits, the
measured ratios from Step 5, and the full-suite result, then wait.

---

## Verification Summary

| Spec requirement | Where it is met |
|---|---|
| Blob format, magic, declared length | Task 1, Steps 1 and 3 |
| Decode conditions 1, 2 and 3 | Task 1, the collision, truncation and tampered-length tests |
| `kMaxRawDiveBlobBytes` bounds both directions | Task 1, the bomb test and the over-cap test |
| Encode only when strictly smaller | Task 1, the incompressible test |
| Converter on the column | Task 2, Steps 3 and 4 |
| Callers unchanged, legacy rows readable | Task 2, Steps 1 and 6 |
| The sync wire stays uncompressed | Task 2, Step 8 |
| `raw_fingerprint` untouched | No task modifies it |
| v188 rung, no DDL, idempotent | Task 3, Steps 4, 5 and the idempotence test |
| Rung guarded per row, ladder cannot fail | Task 3, Step 5 and the oversized-blob test |
| Reclaim signal drives the existing VACUUM | Task 4, Steps 2 and 3 |
| No `minimumCompatibleSchemaVersion` change | No task modifies it |
