# Raw Dive Computer Data in UDDF Exports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Carry each dive's raw libdivecomputer bytes through UDDF export and restore them losslessly on import, so a Submersion UDDF backup is a complete archive and "Re-parse raw data" still works after a restore.

**Architecture:** Raw bytes go into the UDDF standard's `<divecomputercontrol>` / `<divecomputerdump>` section as base64(bzip2(...)), which the spec mandates. Everything the standard cannot express (the libdivecomputer descriptor triple, the per-source metric snapshot, source identity) goes into a parallel `<applicationdata><submersion><datasources>` record, one `<source>` entry per `dive_data_sources` row, paired to dumps by `(diveref, ordinal)`. On import the entries replace the importer's single synthesised provenance row with one row per entry.

**Tech Stack:** Flutter, Dart, Drift (SQLite), `xml: ^7.0.1`, `archive: ^4.0.9` (BZip2Encoder/BZip2Decoder), Riverpod.

**Spec:** `docs/superpowers/specs/2026-09-04-uddf-raw-dive-data-design.md`

## Global Constraints

- **TDD.** Write the failing test first, watch it fail, then implement. Project rule from `CLAUDE.md`.
- **No em-dashes** (`—`, U+2014) in any file, comment, commit message, or ARB string. Use a colon, semicolon, comma, or two sentences.
- **No emojis** in code, comments, or documentation.
- **Immutability.** Never mutate objects or arrays.
- **Run `dart format .`** before every commit.
- **Import order:** dart, flutter, packages, local (relative).
- **File size:** 200-400 lines typical, 800 maximum.
- **The export query is a Drift-typed select, never `customSelect`.** Under issue #227 the `raw_data` column carries a `TypeConverter`; `customSelect` skips converters and would emit `SRD1`-framed zlib inside `<dcdump>`. Task 2 pins this with a byte-identity test.
- **Never route raw-byte reads through `getDataSources`** (`dive_repository_impl.dart:6192`). It collapses rows sharing a merge slot into one display source, and each collapsed row is the only copy of its half's `rawData`.
- `kMaxRawDiveBlobBytes = 8 * 1024 * 1024`. Issue #227 defines the same ceiling in `lib/core/database/raw_dive_data_codec.dart`. Whichever change lands second deletes its duplicate and imports the other's.
- **11 locales.** `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`. Every new key goes in all 11, and generated l10n must be regenerated and committed or CI's staleness gate fails.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/services/export/uddf/uddf_dump_codec.dart` | New. bzip2 + base64 both ways, the bounded output stream, the worker-isolate hop. No Flutter imports. |
| `lib/core/services/export/models/uddf_export_options.dart` | New. `UddfExportOptions.includeRawData`. |
| `lib/features/dive_log/domain/entities/dive_source_export.dart` | New. The per-source provenance value type crossing repository to export service. |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | `getSourcesForExport`, `saveComputerReadings` (batch). |
| `lib/core/services/export/uddf/uddf_export_builders.dart` | `buildDataSources`, `buildDiveComputerControl`. Pure XML over pre-encoded payloads. |
| `lib/core/services/export/uddf/uddf_full_export_service.dart` | Emits both new sections. |
| `lib/core/services/export/uddf/uddf_export_service.dart` | Same, plus its own top-level `<applicationdata><submersion>` wrapper. |
| `lib/core/services/export/export_service.dart` | Threads options through four UDDF entry points. |
| `lib/core/services/export/uddf/uddf_source_fetch.dart` | New. The one rule for whether an export fetches source rows, shared by the notifier and the three page call sites. |
| `lib/core/services/export/uddf/uddf_full_import_service.dart` | Parses both sections and joins them. |
| `lib/features/dive_import/data/services/uddf_entity_importer.dart` | Restores one source row per entry. |
| `lib/features/settings/presentation/providers/export_providers.dart` | Fetches sources when enabled, carries counts. |

---

### Task 1: The dump codec

**Files:**
- Create: `lib/core/services/export/uddf/uddf_dump_codec.dart`
- Test: `test/core/services/export/uddf/uddf_dump_codec_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `const int kMaxRawDiveBlobBytes`; `class UddfDumpTooLargeException implements Exception`; `class UddfDumpCodec` with `static String encodeOne(Uint8List raw)`, `static Uint8List decodeOne(String base64Text)`, `static Future<List<String?>> encodeAll(List<Uint8List> raws)`.

`encodeAll` returns a list positionally matching its input, with `null` where that blob failed to encode. It never throws for a single bad blob.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/uddf/uddf_dump_codec_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';

void main() {
  group('UddfDumpCodec', () {
    test('round trips the committed libdivecomputer fixtures', () {
      const paths = [
        'packages/libdivecomputer_plugin/test/native/fixtures/dive1_raw.bin',
        'packages/libdivecomputer_plugin/test/native/fixtures/'
            'petrel3_ccr_o2_cells.bin',
        'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
            'shearwater_teric_dive.bin',
      ];

      for (final path in paths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing fixture: $path');
        final raw = Uint8List.fromList(file.readAsBytesSync());

        final encoded = UddfDumpCodec.encodeOne(raw);
        expect(encoded, isNotEmpty);

        final decoded = UddfDumpCodec.decodeOne(encoded);
        expect(decoded, equals(raw), reason: 'round trip failed for $path');
      }
    });

    test('round trips empty and single byte payloads', () {
      for (final raw in [Uint8List(0), Uint8List.fromList([0x42])]) {
        expect(UddfDumpCodec.decodeOne(UddfDumpCodec.encodeOne(raw)),
            equals(raw));
      }
    });

    test('decode tolerates surrounding whitespace from pretty printed XML', () {
      final raw = Uint8List.fromList(List<int>.generate(512, (i) => i % 256));
      final encoded = UddfDumpCodec.encodeOne(raw);
      expect(UddfDumpCodec.decodeOne('\n  $encoded\n  '), equals(raw));
    });

    test('decode refuses a payload that expands past the ceiling', () {
      // Highly compressible: 12 MiB of zeros bzip2s to a few hundred bytes,
      // so the guard has to fire during decode, not on the encoded size.
      final bomb = Uint8List(12 * 1024 * 1024);
      final encoded = UddfDumpCodec.encodeOne(bomb);

      expect(
        () => UddfDumpCodec.decodeOne(encoded),
        throwsA(isA<UddfDumpTooLargeException>()),
      );
    });

    test('decode rejects text that is not bzip2', () {
      expect(
        () => UddfDumpCodec.decodeOne('bm90IGJ6aXAy'),
        throwsA(isA<FormatException>()),
      );
    });

    test('encodeAll yields null for a failed blob and keeps the rest', () async {
      final good = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final tooBig = Uint8List(kMaxRawDiveBlobBytes + 1);

      final result = await UddfDumpCodec.encodeAll([good, tooBig, good]);

      expect(result.length, 3);
      expect(result[0], isNotNull);
      expect(result[1], isNull);
      expect(result[2], isNotNull);
      expect(UddfDumpCodec.decodeOne(result[0]!), equals(good));
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/core/services/export/uddf/uddf_dump_codec_test.dart -r compact
```

Expected: FAIL, `Target of URI doesn't exist: '.../uddf_dump_codec.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/core/services/export/uddf/uddf_dump_codec.dart`:

```dart
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Largest raw dive blob this app will encode into, or accept out of, a UDDF
/// `<dcdump>` element.
///
/// Issue #227 defines the same ceiling in
/// `lib/core/database/raw_dive_data_codec.dart` for the at-rest codec.
/// Whichever of the two changes lands second deletes its duplicate and
/// imports the other's, so there is exactly one definition of this number.
const int kMaxRawDiveBlobBytes = 8 * 1024 * 1024;

/// A dump exceeded [kMaxRawDiveBlobBytes], encoding or decoding.
///
/// Decompression bombs are the reason this exists: a `<dcdump>` in a file
/// from anywhere else is untrusted input, and bzip2 expands far more
/// aggressively than zlib.
class UddfDumpTooLargeException implements Exception {
  const UddfDumpTooLargeException();

  @override
  String toString() =>
      'UddfDumpTooLargeException: raw dive dump exceeds '
      '$kMaxRawDiveBlobBytes bytes';
}

/// Encodes and decodes the payload of a UDDF `<dcdump>` element.
///
/// UDDF 3.2.1 requires that "the memory dump data shall be compressed with
/// bzip2 algorithm and encoded into ASCII using Base64 encoder". bzip2 is
/// therefore not a choice; gzip would produce a file no other UDDF reader
/// can open.
///
/// Note that this is NOT the codec issue #227 uses to compress the same
/// bytes at rest. That one is zlib behind an `SRD1` header, chosen for
/// space; this one is dictated by the file format. Bytes read from Drift
/// arrive already decoded by #227's `TypeConverter`, so the export always
/// decodes then recompresses. Copying the stored blob through would be
/// faster and would produce a spec-violating file.
class UddfDumpCodec {
  const UddfDumpCodec._();

  /// bzip2 then base64. Throws [UddfDumpTooLargeException] rather than mint
  /// a dump its own decoder would refuse.
  static String encodeOne(Uint8List raw) {
    if (raw.length > kMaxRawDiveBlobBytes) {
      throw const UddfDumpTooLargeException();
    }
    return base64.encode(BZip2Encoder().encodeBytes(raw));
  }

  /// base64 then bzip2, bounded at [kMaxRawDiveBlobBytes].
  ///
  /// Decoding runs into a bounded [OutputStream] rather than
  /// `BZip2Decoder.decodeBytes`, so a bomb is abandoned mid-stream instead
  /// of being fully allocated and then measured.
  static Uint8List decodeOne(String base64Text) {
    final compressed = base64.decode(base64Text.trim());
    final output = _BoundedOutputStream(kMaxRawDiveBlobBytes);
    final ok = BZip2Decoder().decodeStream(
      InputMemoryStream(compressed),
      output,
    );
    if (!ok) {
      throw const FormatException('Malformed bzip2 payload in <dcdump>');
    }
    return Uint8List.fromList(output.getBytes());
  }

  /// Encode many blobs on a worker isolate.
  ///
  /// Returns a list positionally matching [raws], carrying `null` wherever
  /// that blob could not be encoded. A single bad blob must not cost the
  /// user the whole export: this is a backup path, and a file missing one
  /// dump beats no file at all.
  ///
  /// bzip2 is a block sorting compressor and is markedly slower in pure Dart
  /// than zlib, which is why a whole logbook's worth of it does not run on
  /// the calling isolate.
  static Future<List<String?>> encodeAll(List<Uint8List> raws) {
    if (raws.isEmpty) return Future.value(const []);
    return _encodeOnWorker(raws);
  }

  /// Minimal-scope hop to the worker isolate.
  ///
  /// Kept as its own method so the [Isolate.run] closure's enclosing scope
  /// holds only sendable values: Dart closures capture the whole enclosing
  /// scope, not only what they reference. This mirrors
  /// `backup_crypto.dart`, which documents the same hazard.
  static Future<List<String?>> _encodeOnWorker(List<Uint8List> raws) {
    return Isolate.run(() => _encodeAllImpl(raws), debugName: 'uddf-dcdump');
  }

  static List<String?> _encodeAllImpl(List<Uint8List> raws) {
    return raws.map((raw) {
      try {
        return encodeOne(raw);
      } catch (_) {
        return null;
      }
    }).toList(growable: false);
  }
}

/// An [OutputStream] that refuses to grow past [maxBytes].
///
/// Delegates to an [OutputMemoryStream] rather than reimplementing its
/// buffer, and checks the bound before each write so an oversized stream is
/// abandoned partway rather than after it is fully materialised.
class _BoundedOutputStream extends OutputStream {
  _BoundedOutputStream(this.maxBytes)
    : _inner = OutputMemoryStream(),
      super(byteOrder: ByteOrder.littleEndian);

  final int maxBytes;
  final OutputMemoryStream _inner;

  void _guard(int adding) {
    if (_inner.length + adding > maxBytes) {
      throw const UddfDumpTooLargeException();
    }
  }

  @override
  int get length => _inner.length;

  @override
  void writeByte(int value) {
    _guard(1);
    _inner.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _guard(length ?? bytes.length);
    _inner.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _guard(stream.length);
    _inner.writeStream(stream);
  }

  @override
  void clear() => _inner.clear();

  @override
  void flush() => _inner.flush();

  @override
  Uint8List subset(int start, [int? end]) => _inner.subset(start, end);
}
```

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/core/services/export/uddf/uddf_dump_codec_test.dart -r compact
```

Expected: PASS, 6 tests.

If the bomb test is slow (it compresses 12 MiB), that is expected; bzip2 in pure Dart is not fast. If it exceeds the default timeout, keep the test and reduce the bomb to 9 MiB, which still clears the 8 MiB ceiling.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/core/services/export/uddf/uddf_dump_codec.dart test/core/services/export/uddf/uddf_dump_codec_test.dart
git commit -m "feat(export): add the UDDF dcdump bzip2 codec (#228)"
```

---

### Task 2: The export query and its byte-identity guard

**Files:**
- Create: `lib/features/dive_log/domain/entities/dive_source_export.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add near the "Dive Data Sources" section, around line 6190)
- Test: `test/features/dive_log/data/repositories/sources_for_export_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `class DiveSourceExport` (fields listed below); `Future<List<DiveSourceExport>> getSourcesForExport(List<String> diveIds)` on `DiveRepository`.

`DiveSourceExport` fields: `String id`, `String diveId`, `int ordinal`, `bool isPrimary`, `Uint8List? rawData`, `Uint8List? rawFingerprint`, `String? computerId`, `String? computerModel`, `String? computerSerial`, `String? sourceFormat`, `String? sourceFileName`, `String? sourceFileFormat`, `String? sourceUuid`, `String? descriptorVendor`, `String? descriptorProduct`, `int? descriptorModel`, `String? libdivecomputerVersion`, `int? mergeSourceSlot`, `int? timeOffsetSeconds`, `double? maxDepth`, `double? avgDepth`, `int? duration`, `double? waterTemp`, `double? entryLatitude`, `double? entryLongitude`, `double? exitLatitude`, `double? exitLongitude`, `DateTime? entryTime`, `DateTime? exitTime`, `double? maxAscentRate`, `double? maxDescentRate`, `int? surfaceInterval`, `double? cns`, `double? otu`, `String? decoAlgorithm`, `int? gradientFactorLow`, `int? gradientFactorHigh`, `DateTime importedAt`, `DateTime createdAt`, `DateTime? lastParsedAt`. Convenience getter `bool get hasDump => rawData != null && rawData!.isNotEmpty;`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/sources_for_export_test.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  // DiveRepository takes no database argument: it reads
  // DatabaseService.instance, which setUpTestDatabase points at an in-memory
  // database. Constructing it with a database would not compile.
  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> insertDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.dives).insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSource(
    String id,
    String diveId, {
    Uint8List? rawData,
    bool isPrimary = false,
    int? mergeSourceSlot,
    DateTime? createdAt,
  }) async {
    final stamp = createdAt ?? DateTime(2019, 6, 2, 18, 41, 7);
    await db.into(db.diveDataSources).insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            isPrimary: Value(isPrimary),
            rawData: rawData == null ? const Value.absent() : Value(rawData),
            mergeSourceSlot: mergeSourceSlot == null
                ? const Value.absent()
                : Value(mergeSourceSlot),
            descriptorVendor: const Value('Shearwater'),
            descriptorProduct: const Value('Perdix'),
            descriptorModel: const Value(5),
            importedAt: Value(stamp),
            createdAt: Value(stamp),
          ),
        );
  }

  test('returns raw bytes byte identical to what was written', () async {
    // The load bearing assertion. Under issue #227 raw_data carries a Drift
    // TypeConverter; customSelect skips converters, so a raw SQL version of
    // getSourcesForExport would hand back SRD1 framed zlib and this fails.
    final raw = Uint8List.fromList(
      List<int>.generate(4096, (i) => (i * 31) % 256),
    );
    await insertDive('dive-1');
    await insertSource('src-1', 'dive-1', rawData: raw, isPrimary: true);

    final sources = await repository.getSourcesForExport(['dive-1']);

    expect(sources, hasLength(1));
    expect(sources.single.rawData, equals(raw));
    expect(sources.single.hasDump, isTrue);
  });

  test('returns rows without raw data too, marked as having no dump',
      () async {
    await insertDive('dive-1');
    await insertSource('src-1', 'dive-1', isPrimary: true);

    final sources = await repository.getSourcesForExport(['dive-1']);

    expect(sources, hasLength(1));
    expect(sources.single.rawData, isNull);
    expect(sources.single.hasDump, isFalse);
  });

  test('does not collapse rows sharing a merge slot', () async {
    // getDataSources collapses these into one display source. Each row is
    // the only copy of its half's rawData, so the export must see both.
    final a = Uint8List.fromList([1, 2, 3]);
    final b = Uint8List.fromList([4, 5, 6]);
    await insertDive('dive-1');
    await insertSource('src-a', 'dive-1',
        rawData: a,
        isPrimary: true,
        mergeSourceSlot: 0,
        createdAt: DateTime(2019, 6, 2));
    await insertSource('src-b', 'dive-1',
        rawData: b,
        mergeSourceSlot: 0,
        createdAt: DateTime(2019, 6, 3));

    final sources = await repository.getSourcesForExport(['dive-1']);

    expect(sources, hasLength(2));
    expect(sources.map((s) => s.rawData), containsAll([a, b]));
  });

  test('numbers ordinals per dive, primary first then createdAt', () async {
    await insertDive('dive-1');
    await insertDive('dive-2');
    await insertSource('src-late', 'dive-1',
        createdAt: DateTime(2019, 6, 4));
    await insertSource('src-primary', 'dive-1',
        isPrimary: true, createdAt: DateTime(2019, 6, 5));
    await insertSource('src-other', 'dive-2', isPrimary: true);

    final sources = await repository.getSourcesForExport(['dive-1', 'dive-2']);

    final diveOne = sources.where((s) => s.diveId == 'dive-1').toList();
    expect(diveOne.map((s) => s.id), ['src-primary', 'src-late']);
    expect(diveOne.map((s) => s.ordinal), [0, 1]);

    final diveTwo = sources.where((s) => s.diveId == 'dive-2').toList();
    expect(diveTwo.single.ordinal, 0);
  });

  test('returns an empty list for an empty id list without querying',
      () async {
    expect(await repository.getSourcesForExport(const []), isEmpty);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/features/dive_log/data/repositories/sources_for_export_test.dart -r compact
```

Expected: FAIL, `DiveSourceExport` and `getSourcesForExport` do not exist.

- [ ] **Step 3: Create the value type**

Create `lib/features/dive_log/domain/entities/dive_source_export.dart`:

```dart
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// One `dive_data_sources` row as the UDDF exporter needs to see it.
///
/// This is the whole row rather than just the bytes. A UDDF `<dive>` carries
/// only the consolidated values, so the per-source snapshot (max depth, cns,
/// deco algorithm, entry and exit) exists nowhere else in the document, and a
/// restore that dropped it would be lossless only about the blob.
///
/// [ordinal] is this row's position among its own dive's rows in the order
/// the repository returned them. It is what pairs a `<source>` entry with its
/// `<divecomputerdump>`, because `<divecomputerdump>` accepts no attributes
/// and so cannot carry an id of its own.
class DiveSourceExport extends Equatable {
  const DiveSourceExport({
    required this.id,
    required this.diveId,
    required this.ordinal,
    required this.isPrimary,
    required this.importedAt,
    required this.createdAt,
    this.rawData,
    this.rawFingerprint,
    this.computerId,
    this.computerModel,
    this.computerSerial,
    this.sourceFormat,
    this.sourceFileName,
    this.sourceFileFormat,
    this.sourceUuid,
    this.descriptorVendor,
    this.descriptorProduct,
    this.descriptorModel,
    this.libdivecomputerVersion,
    this.mergeSourceSlot,
    this.timeOffsetSeconds,
    this.maxDepth,
    this.avgDepth,
    this.duration,
    this.waterTemp,
    this.entryLatitude,
    this.entryLongitude,
    this.exitLatitude,
    this.exitLongitude,
    this.entryTime,
    this.exitTime,
    this.maxAscentRate,
    this.maxDescentRate,
    this.surfaceInterval,
    this.cns,
    this.otu,
    this.decoAlgorithm,
    this.gradientFactorLow,
    this.gradientFactorHigh,
    this.lastParsedAt,
  });

  final String id;
  final String diveId;
  final int ordinal;
  final bool isPrimary;
  final DateTime importedAt;
  final DateTime createdAt;

  final Uint8List? rawData;
  final Uint8List? rawFingerprint;

  final String? computerId;
  final String? computerModel;
  final String? computerSerial;
  final String? sourceFormat;
  final String? sourceFileName;
  final String? sourceFileFormat;
  final String? sourceUuid;

  final String? descriptorVendor;
  final String? descriptorProduct;
  final int? descriptorModel;
  final String? libdivecomputerVersion;

  final int? mergeSourceSlot;
  final int? timeOffsetSeconds;

  final double? maxDepth;
  final double? avgDepth;
  final int? duration;
  final double? waterTemp;
  final double? entryLatitude;
  final double? entryLongitude;
  final double? exitLatitude;
  final double? exitLongitude;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final double? maxAscentRate;
  final double? maxDescentRate;
  final int? surfaceInterval;
  final double? cns;
  final double? otu;
  final String? decoAlgorithm;
  final int? gradientFactorLow;
  final int? gradientFactorHigh;
  final DateTime? lastParsedAt;

  /// Whether this row contributes a `<dcdump>`.
  bool get hasDump => rawData != null && rawData!.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    diveId,
    ordinal,
    isPrimary,
    importedAt,
    createdAt,
    rawData,
    rawFingerprint,
    computerId,
    computerModel,
    computerSerial,
    sourceFormat,
    sourceFileName,
    sourceFileFormat,
    sourceUuid,
    descriptorVendor,
    descriptorProduct,
    descriptorModel,
    libdivecomputerVersion,
    mergeSourceSlot,
    timeOffsetSeconds,
    maxDepth,
    avgDepth,
    duration,
    waterTemp,
    entryLatitude,
    entryLongitude,
    exitLatitude,
    exitLongitude,
    entryTime,
    exitTime,
    maxAscentRate,
    maxDescentRate,
    surfaceInterval,
    cns,
    otu,
    decoAlgorithm,
    gradientFactorLow,
    gradientFactorHigh,
    lastParsedAt,
  ];
}
```

- [ ] **Step 4: Add the repository method**

Add the import at the top of `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (in the local import group):

```dart
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
```

Add this method immediately after `getDataSources` (which ends around line 6213):

```dart
  /// Every `dive_data_sources` row for [diveIds], for UDDF export.
  ///
  /// Deliberately NOT built on [getDataSources]: that one runs rows through
  /// `_canonicalDataSourceRows`, which collapses rows sharing a merge slot
  /// into one display source. Each collapsed row is the sole surviving copy
  /// of its half's `rawData`, so exporting through it would silently drop
  /// half of a combined dive's bytes.
  ///
  /// Rows with no `rawData` are included too. The provenance record has to
  /// cover them or a dive with one plain source beside one carrying bytes
  /// would restore with fewer sources than it had.
  ///
  /// This MUST stay a Drift typed select. Issue #227 puts a `TypeConverter`
  /// on `raw_data`; typed selects run converters and `customSelect` does
  /// not, so a raw SQL version would return `SRD1` framed zlib and the
  /// export would write compressed bytes into `<dcdump>` with nothing to
  /// catch it. `sources_for_export_test.dart` pins this.
  ///
  /// The ordering is part of the contract: it defines the ordinals that pair
  /// a `<source>` entry with its `<divecomputerdump>`.
  Future<List<DiveSourceExport>> getSourcesForExport(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    try {
      final query = _db.select(_db.diveDataSources)
        ..where((t) => t.diveId.isIn(diveIds))
        ..orderBy([
          (t) => OrderingTerm.asc(t.diveId),
          (t) => OrderingTerm.desc(t.isPrimary),
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]);
      final rows = await query.get();

      final ordinalByDive = <String, int>{};
      return rows.map((row) {
        final ordinal = ordinalByDive.update(
          row.diveId,
          (value) => value + 1,
          ifAbsent: () => 0,
        );
        return DiveSourceExport(
          id: row.id,
          diveId: row.diveId,
          ordinal: ordinal,
          isPrimary: row.isPrimary,
          importedAt: row.importedAt,
          createdAt: row.createdAt,
          rawData: row.rawData,
          rawFingerprint: row.rawFingerprint,
          computerId: row.computerId,
          computerModel: row.computerModel,
          computerSerial: row.computerSerial,
          sourceFormat: row.sourceFormat,
          sourceFileName: row.sourceFileName,
          sourceFileFormat: row.sourceFileFormat,
          sourceUuid: row.sourceUuid,
          descriptorVendor: row.descriptorVendor,
          descriptorProduct: row.descriptorProduct,
          descriptorModel: row.descriptorModel,
          libdivecomputerVersion: row.libdivecomputerVersion,
          mergeSourceSlot: row.mergeSourceSlot,
          timeOffsetSeconds: row.timeOffsetSeconds,
          maxDepth: row.maxDepth,
          avgDepth: row.avgDepth,
          duration: row.duration,
          waterTemp: row.waterTemp,
          entryLatitude: row.entryLatitude,
          entryLongitude: row.entryLongitude,
          exitLatitude: row.exitLatitude,
          exitLongitude: row.exitLongitude,
          entryTime: row.entryTime,
          exitTime: row.exitTime,
          maxAscentRate: row.maxAscentRate,
          maxDescentRate: row.maxDescentRate,
          surfaceInterval: row.surfaceInterval,
          cns: row.cns,
          otu: row.otu,
          decoAlgorithm: row.decoAlgorithm,
          gradientFactorLow: row.gradientFactorLow,
          gradientFactorHigh: row.gradientFactorHigh,
          lastParsedAt: row.lastParsedAt,
        );
      }).toList(growable: false);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load data sources for export',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Note the class in this file is named `DiveRepository`, not `DiveRepositoryImpl`, despite the filename. It is a factory constructor taking only optional media dependencies, and it resolves its database through `DatabaseService.instance`, which is why the test uses `setUpTestDatabase()` rather than passing a database in.

- [ ] **Step 5: Run the test and verify it passes**

```bash
flutter test test/features/dive_log/data/repositories/sources_for_export_test.dart -r compact
```

Expected: PASS, 5 tests.

- [ ] **Step 6: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/features/dive_log/domain/entities/dive_source_export.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/sources_for_export_test.dart
git commit -m "feat(export): read every data source row for UDDF export (#228)"
```

---

### Task 3: The XML builders

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart`
- Test: `test/core/services/export/uddf/uddf_dcdump_builders_test.dart`

**Interfaces:**
- Consumes: `DiveSourceExport` from Task 2.
- Produces, both `static` on `UddfExportBuilders`:
  - `void buildDataSources(XmlBuilder builder, List<DiveSourceExport> sources)`
  - `void buildDiveComputerControl(XmlBuilder builder, List<DiveSourceExport> sources, Map<String, String?> encodedById, {required bool declaresComputers})`

`encodedById` maps `DiveSourceExport.id` to its base64 payload, or to `null` when encoding failed. A source absent from the map, or mapped to `null`, contributes no `<divecomputerdump>`.

`declaresComputers` is false for the dives-only export, which emits no `<divecomputer>` element, so a `<link ref="computer_...">` there would dangle.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/uddf/uddf_dcdump_builders_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

DiveSourceExport source({
  required String id,
  required String diveId,
  required int ordinal,
  bool isPrimary = true,
  Uint8List? rawData,
  String? computerId,
}) {
  return DiveSourceExport(
    id: id,
    diveId: diveId,
    ordinal: ordinal,
    isPrimary: isPrimary,
    importedAt: DateTime(2019, 6, 2, 18, 41, 7),
    createdAt: DateTime(2019, 6, 2, 18, 41, 7),
    rawData: rawData,
    rawFingerprint: Uint8List.fromList([0xA1, 0x7F, 0x3C]),
    computerId: computerId,
    computerModel: 'Perdix AI',
    computerSerial: 'SN123',
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: 5,
    libdivecomputerVersion: '0.9.0-devel',
    mergeSourceSlot: 0,
    timeOffsetSeconds: 0,
    maxDepth: 31.5,
    cns: 12.5,
    decoAlgorithm: 'ZHL16C',
  );
}

String render(void Function(XmlBuilder) body) {
  final builder = XmlBuilder();
  builder.element('root', nest: () => body(builder));
  return builder.buildDocument().toXmlString(pretty: true);
}

void main() {
  group('buildDataSources', () {
    test('writes one entry per source with hasdump reflecting the bytes', () {
      final withBytes = source(
        id: 'src-a',
        diveId: 'dive-1',
        ordinal: 0,
        rawData: Uint8List.fromList([1, 2, 3]),
      );
      final withoutBytes =
          source(id: 'src-b', diveId: 'dive-1', ordinal: 1, isPrimary: false);

      final xml = render(
        (b) => UddfExportBuilders.buildDataSources(b, [
          withBytes,
          withoutBytes,
        ]),
      );
      final doc = XmlDocument.parse(xml);
      final entries = doc.findAllElements('source').toList();

      expect(entries, hasLength(2));
      expect(entries[0].getAttribute('diveref'), 'dive_dive-1');
      expect(entries[0].getAttribute('ordinal'), '0');
      expect(entries[0].getAttribute('hasdump'), 'true');
      expect(entries[1].getAttribute('hasdump'), 'false');

      final descriptor = entries[0].findElements('descriptor').single;
      expect(descriptor.getAttribute('vendor'), 'Shearwater');
      expect(descriptor.getAttribute('product'), 'Perdix');
      expect(descriptor.getAttribute('model'), '5');

      expect(entries[0].findElements('fingerprint').single.innerText, 'A17F3C');
      expect(entries[0].findElements('primary').single.innerText, 'true');
      expect(entries[1].findElements('primary').single.innerText, 'false');
      expect(entries[0].findElements('maxdepth').single.innerText, '31.5');
      expect(
        entries[0].findElements('decoalgorithm').single.innerText,
        'ZHL16C',
      );
      expect(
        entries[0].findElements('importedat').single.innerText,
        DateTime(2019, 6, 2, 18, 41, 7).toIso8601String(),
      );
    });

    test('writes nothing at all for an empty source list', () {
      final xml = render((b) => UddfExportBuilders.buildDataSources(b, const []));
      expect(XmlDocument.parse(xml).findAllElements('datasources'), isEmpty);
    });
  });

  group('buildDiveComputerControl', () {
    test('emits a dump only for sources with an encoded payload', () {
      final a = source(
        id: 'src-a',
        diveId: 'dive-1',
        ordinal: 0,
        rawData: Uint8List.fromList([1, 2, 3]),
        computerId: 'computer_9c21',
      );
      final b = source(
        id: 'src-b',
        diveId: 'dive-1',
        ordinal: 1,
        isPrimary: false,
        rawData: Uint8List.fromList([4, 5, 6]),
      );
      final c = source(id: 'src-c', diveId: 'dive-2', ordinal: 0);

      final xml = render(
        (builder) => UddfExportBuilders.buildDiveComputerControl(
          builder,
          [a, b, c],
          const {'src-a': 'QlpoOUFB', 'src-b': null},
          declaresComputers: true,
        ),
      );
      final doc = XmlDocument.parse(xml);
      final dumps = doc.findAllElements('divecomputerdump').toList();

      expect(dumps, hasLength(1));
      expect(dumps.single.findElements('dcdump').single.innerText, 'QlpoOUFB');
      final refs = dumps.single
          .findElements('link')
          .map((e) => e.getAttribute('ref'))
          .toList();
      expect(refs, ['dive_dive-1', 'computer_9c21']);
      expect(
        dumps.single.findElements('datetime').single.innerText,
        DateTime(2019, 6, 2, 18, 41, 7).toIso8601String(),
      );
    });

    test('omits the computer link when the document declares no computers',
        () {
      final a = source(
        id: 'src-a',
        diveId: 'dive-1',
        ordinal: 0,
        rawData: Uint8List.fromList([1, 2, 3]),
        computerId: 'computer_9c21',
      );

      final xml = render(
        (builder) => UddfExportBuilders.buildDiveComputerControl(
          builder,
          [a],
          const {'src-a': 'QlpoOUFB'},
          declaresComputers: false,
        ),
      );
      final refs = XmlDocument.parse(xml)
          .findAllElements('link')
          .map((e) => e.getAttribute('ref'))
          .toList();

      // A ref pointing at an undeclared id would dangle under IDREF
      // validation, and the dives only export declares no <divecomputer>.
      expect(refs, ['dive_dive-1']);
    });

    test('writes no section when nothing encoded', () {
      final xml = render(
        (builder) => UddfExportBuilders.buildDiveComputerControl(
          builder,
          [source(id: 'src-a', diveId: 'dive-1', ordinal: 0)],
          const {},
          declaresComputers: true,
        ),
      );
      expect(
        XmlDocument.parse(xml).findAllElements('divecomputercontrol'),
        isEmpty,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/core/services/export/uddf/uddf_dcdump_builders_test.dart -r compact
```

Expected: FAIL, `buildDataSources` is not defined.

- [ ] **Step 3: Write the builders**

Add these imports to `lib/core/services/export/uddf/uddf_export_builders.dart` if not already present:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
```

Add both methods to `UddfExportBuilders`, after `buildApplicationData`:

```dart
  /// Hex encode, matching SQLite's `hex()` and the convention
  /// `dive_repository_impl.dart` documents for raw fingerprints.
  static String _hex(Uint8List bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();

  /// The Submersion per-source provenance record.
  ///
  /// One `<source>` entry per `dive_data_sources` row, carrying every column
  /// except the blob itself. This exists because UDDF has nowhere to put the
  /// libdivecomputer descriptor triple, without which a restored dump can
  /// never be re-parsed, and nowhere to put the per-source metric snapshot,
  /// since a UDDF `<dive>` carries only the consolidated values.
  ///
  /// Entries are written for rows with no bytes as well. Omitting them would
  /// restore a dive that had one plain source beside one carrying bytes with
  /// fewer sources than it had.
  static void buildDataSources(
    XmlBuilder builder,
    List<DiveSourceExport> sources,
  ) {
    if (sources.isEmpty) return;

    builder.element(
      'datasources',
      nest: () {
        for (final source in sources) {
          builder.element(
            'source',
            attributes: {
              'diveref': 'dive_${source.diveId}',
              'ordinal': '${source.ordinal}',
              'hasdump': '${source.hasDump}',
            },
            nest: () {
              if (source.descriptorVendor != null ||
                  source.descriptorProduct != null ||
                  source.descriptorModel != null) {
                builder.element(
                  'descriptor',
                  attributes: {
                    if (source.descriptorVendor != null)
                      'vendor': source.descriptorVendor!,
                    if (source.descriptorProduct != null)
                      'product': source.descriptorProduct!,
                    if (source.descriptorModel != null)
                      'model': '${source.descriptorModel}',
                  },
                );
              }
              _text(builder, 'libdivecomputerversion',
                  source.libdivecomputerVersion);
              _text(builder, 'sourceuuid', source.sourceUuid);
              if (source.rawFingerprint != null &&
                  source.rawFingerprint!.isNotEmpty) {
                builder.element(
                  'fingerprint',
                  nest: _hex(source.rawFingerprint!),
                );
              }
              builder.element('primary', nest: '${source.isPrimary}');
              _number(builder, 'mergesourceslot', source.mergeSourceSlot);
              _number(builder, 'timeoffsetseconds', source.timeOffsetSeconds);
              _text(builder, 'computermodel', source.computerModel);
              _text(builder, 'computerserial', source.computerSerial);
              _text(builder, 'sourceformat', source.sourceFormat);
              _text(builder, 'sourcefilename', source.sourceFileName);
              _text(builder, 'sourcefileformat', source.sourceFileFormat);
              _date(builder, 'importedat', source.importedAt);
              _date(builder, 'createdat', source.createdAt);
              _date(builder, 'lastparsedat', source.lastParsedAt);
              _number(builder, 'maxdepth', source.maxDepth);
              _number(builder, 'avgdepth', source.avgDepth);
              _number(builder, 'duration', source.duration);
              _number(builder, 'watertemp', source.waterTemp);
              _number(builder, 'entrylatitude', source.entryLatitude);
              _number(builder, 'entrylongitude', source.entryLongitude);
              _number(builder, 'exitlatitude', source.exitLatitude);
              _number(builder, 'exitlongitude', source.exitLongitude);
              _date(builder, 'entrytime', source.entryTime);
              _date(builder, 'exittime', source.exitTime);
              _number(builder, 'maxascentrate', source.maxAscentRate);
              _number(builder, 'maxdescentrate', source.maxDescentRate);
              _number(builder, 'surfaceinterval', source.surfaceInterval);
              _number(builder, 'cns', source.cns);
              _number(builder, 'otu', source.otu);
              _text(builder, 'decoalgorithm', source.decoAlgorithm);
              _number(builder, 'gradientfactorlow', source.gradientFactorLow);
              _number(builder, 'gradientfactorhigh', source.gradientFactorHigh);
            },
          );
        }
      },
    );
  }

  static void _text(XmlBuilder builder, String name, String? value) {
    if (value == null || value.isEmpty) return;
    builder.element(name, nest: value);
  }

  static void _number(XmlBuilder builder, String name, num? value) {
    if (value == null) return;
    builder.element(name, nest: '$value');
  }

  static void _date(XmlBuilder builder, String name, DateTime? value) {
    if (value == null) return;
    builder.element(name, nest: value.toIso8601String());
  }

  /// The UDDF standard `<divecomputercontrol>` section, which the spec
  /// places last in the document.
  ///
  /// One `<divecomputerdump>` per source that has an encoded payload in
  /// [encodedById]. A source mapped to null failed to compress; its dump and
  /// nothing else is omitted, because this is a backup path and a file
  /// missing one dump beats no file at all.
  ///
  /// [declaresComputers] must be false when the document emits no
  /// `<divecomputer>` element, which is the case for the dives only export.
  /// Every ref this writes has to point at an id the standard itself
  /// declares, or it dangles under IDREF validation.
  static void buildDiveComputerControl(
    XmlBuilder builder,
    List<DiveSourceExport> sources,
    Map<String, String?> encodedById, {
    required bool declaresComputers,
  }) {
    final withPayload = sources
        .where((s) => encodedById[s.id] != null)
        .toList(growable: false);
    if (withPayload.isEmpty) return;

    builder.element(
      'divecomputercontrol',
      nest: () {
        for (final source in withPayload) {
          builder.element(
            'divecomputerdump',
            nest: () {
              builder.element(
                'link',
                attributes: {'ref': 'dive_${source.diveId}'},
              );
              if (declaresComputers && source.computerId != null) {
                builder.element(
                  'link',
                  attributes: {'ref': source.computerId!},
                );
              }
              // The spec means "when the dump was captured", so this is the
              // source row's importedAt, not the dive's own datetime. The
              // dive link is what ties the dump to its dive.
              builder.element(
                'datetime',
                nest: source.importedAt.toIso8601String(),
              );
              builder.element('dcdump', nest: encodedById[source.id]!);
            },
          );
        }
      },
    );
  }
```

If `_text`, `_number` or `_date` already exist in this file under those names, rename the new ones to `_dsText`, `_dsNumber`, `_dsDate` and update the call sites. Check with `grep -n "static void _text\|static void _number\|static void _date" lib/core/services/export/uddf/uddf_export_builders.dart` before adding.

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/core/services/export/uddf/uddf_dcdump_builders_test.dart -r compact
```

Expected: PASS, 5 tests.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/core/services/export/uddf/uddf_export_builders.dart test/core/services/export/uddf/uddf_dcdump_builders_test.dart
git commit -m "feat(export): build the UDDF dcdump and datasources sections (#228)"
```

---

### Task 4: Export options and the full export service

**Files:**
- Create: `lib/core/services/export/models/uddf_export_options.dart`
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart`
- Test: `test/core/services/export/uddf/uddf_full_export_raw_data_test.dart`

**Interfaces:**
- Consumes: `UddfDumpCodec.encodeAll` (Task 1), `DiveSourceExport` (Task 2), `buildDataSources` / `buildDiveComputerControl` (Task 3).
- Produces: `class UddfExportOptions` with `final bool includeRawData` defaulting to `true` and a `copyWith`; `UddfFullExportService.exportAllDataToUddf` and `saveAllDataToUddfFile` each gain `List<DiveSourceExport>? dataSources` and `UddfExportOptions options = const UddfExportOptions()`.

The service is given the sources; it does not fetch them. Fetching is the provider's job in Task 6.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/uddf/uddf_full_export_raw_data_test.dart`. Model the `Dive` construction on `test/core/services/export/uddf/uddf_export_builders_test.dart`, which shows the required fields.

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2019, 6, 2, 10, 0),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 31.5,
    avgDepth: 18.0,
    waterTemp: 22.0,
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  final raw = Uint8List.fromList(List<int>.generate(256, (i) => i));

  DiveSourceExport sourceFor({
    required String id,
    required int ordinal,
    bool isPrimary = true,
    Uint8List? rawData,
  }) {
    return DiveSourceExport(
      id: id,
      diveId: 'dive-1',
      ordinal: ordinal,
      isPrimary: isPrimary,
      importedAt: DateTime(2019, 6, 2, 18, 41, 7),
      createdAt: DateTime(2019, 6, 2, 18, 41, 7),
      rawData: rawData,
      descriptorVendor: 'Shearwater',
      descriptorProduct: 'Perdix',
      descriptorModel: 5,
    );
  }

  test('includes the dump and the source record when enabled', () async {
    final service = UddfFullExportService();

    final xml = await service.generateAllDataXmlForTest(
      dives: [dive],
      dataSources: [sourceFor(id: 'src-a', ordinal: 0, rawData: raw)],
      options: const UddfExportOptions(),
    );
    final doc = XmlDocument.parse(xml);

    final dumps = doc.findAllElements('divecomputerdump').toList();
    expect(dumps, hasLength(1));
    expect(
      UddfDumpCodec.decodeOne(dumps.single.findElements('dcdump').single.innerText),
      equals(raw),
    );

    final entries = doc.findAllElements('source').toList();
    expect(entries, hasLength(1));
    expect(entries.single.getAttribute('hasdump'), 'true');

    // divecomputercontrol is the last section of a UDDF document.
    final root = doc.rootElement;
    expect(root.childElements.last.name.local, 'divecomputercontrol');
  });

  test('writes an entry with no dump for a source that has no bytes',
      () async {
    final service = UddfFullExportService();

    final xml = await service.generateAllDataXmlForTest(
      dives: [dive],
      dataSources: [
        sourceFor(id: 'src-a', ordinal: 0, rawData: raw),
        sourceFor(id: 'src-b', ordinal: 1, isPrimary: false),
      ],
      options: const UddfExportOptions(),
    );
    final doc = XmlDocument.parse(xml);

    expect(doc.findAllElements('source'), hasLength(2));
    expect(doc.findAllElements('divecomputerdump'), hasLength(1));
    expect(
      doc.findAllElements('source').map((e) => e.getAttribute('hasdump')),
      ['true', 'false'],
    );
  });

  test('omits both sections when includeRawData is false', () async {
    final service = UddfFullExportService();

    final xml = await service.generateAllDataXmlForTest(
      dives: [dive],
      dataSources: [sourceFor(id: 'src-a', ordinal: 0, rawData: raw)],
      options: const UddfExportOptions(includeRawData: false),
    );
    final doc = XmlDocument.parse(xml);

    expect(doc.findAllElements('divecomputercontrol'), isEmpty);
    expect(doc.findAllElements('datasources'), isEmpty);
  });

  test('defaults to including raw data', () {
    expect(const UddfExportOptions().includeRawData, isTrue);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/core/services/export/uddf/uddf_full_export_raw_data_test.dart -r compact
```

Expected: FAIL, `UddfExportOptions` does not exist.

- [ ] **Step 3: Create the options class**

Create `lib/core/services/export/models/uddf_export_options.dart`:

```dart
/// Options for a UDDF export.
///
/// Shaped after `PdfExportOptions` in `lib/core/constants/pdf_templates.dart`:
/// a const class with defaults, passed as a defaulted named parameter, so no
/// existing call site has to change.
class UddfExportOptions {
  /// Whether to carry each dive's raw dive computer bytes.
  ///
  /// Defaults to true, matching what every export UI shows: the checkbox is
  /// pre-checked in both the full backup and the dives only share paths, and
  /// the code level default is kept in step with it rather than diverging.
  /// A caller that omits options therefore gets a complete export.
  final bool includeRawData;

  const UddfExportOptions({this.includeRawData = true});

  UddfExportOptions copyWith({bool? includeRawData}) =>
      UddfExportOptions(includeRawData: includeRawData ?? this.includeRawData);
}
```

- [ ] **Step 4: Wire the full export service**

In `lib/core/services/export/uddf/uddf_full_export_service.dart`:

1. Add imports:

```dart
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
```

2. Change `_generateAllDataXml` to `Future<String>` and add the two parameters. Add to its parameter list:

```dart
    List<DiveSourceExport>? dataSources,
    UddfExportOptions options = const UddfExportOptions(),
```

3. At the top of the method body, before `final builder = XmlBuilder();`, resolve what will be written:

```dart
    // Encoding happens before the XML build, so the builders stay pure
    // synchronous functions over already encoded strings like every other
    // builder in this file.
    final sources = options.includeRawData
        ? (dataSources ?? const <DiveSourceExport>[])
        : const <DiveSourceExport>[];
    final withBytes = sources.where((s) => s.hasDump).toList(growable: false);
    final encoded = await UddfDumpCodec.encodeAll(
      withBytes.map((s) => s.rawData!).toList(growable: false),
    );
    final encodedById = <String, String?>{
      for (var i = 0; i < withBytes.length; i++) withBytes[i].id: encoded[i],
    };
```

4. Pass `sources` into the existing `UddfExportBuilders.buildApplicationData(...)` call at line 405 by adding a `dataSources: sources` argument, and inside `buildApplicationData` (Task 3's file) add the parameter and call `buildDataSources(builder, dataSources ?? const [])` inside the `<submersion>` element, after the existing sections. Also add `(dataSources?.isNotEmpty ?? false)` to that method's `hasData` disjunction, or a source-only export writes no `<applicationdata>` at all.

5. After `buildApplicationData` and as the last child of `<uddf>`, add:

```dart
        UddfExportBuilders.buildDiveComputerControl(
          builder,
          sources,
          encodedById,
          declaresComputers: true,
        );
```

6. Make `exportAllDataToUddf` and `saveAllDataToUddfFile` accept `dataSources` and `options` and forward them, awaiting the now-async `_generateAllDataXml`.

7. Add a test seam so the test above can call the generator without touching the filesystem:

```dart
  /// Visible for testing: the document this service would write.
  @visibleForTesting
  Future<String> generateAllDataXmlForTest({
    required List<Dive> dives,
    List<DiveSourceExport>? dataSources,
    UddfExportOptions options = const UddfExportOptions(),
  }) => _generateAllDataXml(
    dives: dives,
    dataSources: dataSources,
    options: options,
  );
```

This needs `import 'package:flutter/foundation.dart';` for `@visibleForTesting`. If the file must stay Flutter-free, drop the annotation and keep the method.

- [ ] **Step 5: Run the test and verify it passes**

```bash
flutter test test/core/services/export/uddf/uddf_full_export_raw_data_test.dart -r compact
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Run the existing UDDF suite for regressions**

```bash
flutter test test/core/services/export/uddf -r compact
```

Expected: PASS. Callers of `_generateAllDataXml` now need `await`; fix any that the analyzer flags.

- [ ] **Step 7: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/core/services/export/models/uddf_export_options.dart lib/core/services/export/uddf/uddf_full_export_service.dart lib/core/services/export/uddf/uddf_export_builders.dart test/core/services/export/uddf/uddf_full_export_raw_data_test.dart
git commit -m "feat(export): carry raw dive data in the full UDDF export (#228)"
```

---

### Task 5: The dives-only export service

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart`
- Test: `test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1 through 4.
- Produces: `UddfExportService.generateDivesUddfContent`, `exportDivesToUddf` and `saveDivesToUddfFile` each gain `List<DiveSourceExport>? dataSources` and `UddfExportOptions options = const UddfExportOptions()`. `generateDivesUddfContent` becomes `Future<String>`.

This path is different from Task 4 in two ways that are easy to get wrong:

- It emits **no** `<divecomputer>` element, so `declaresComputers` is `false` and dumps carry only the dive link.
- It has **no** top-level `<applicationdata><submersion>` block. Its only `<applicationdata>` is a per-dive inline one for custom fields at `uddf_export_service.dart:525`, a different element in a different position. The `<datasources>` record needs its own top-level wrapper here, and the inline ones must be left alone.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2019, 6, 2, 10, 0),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 31.5,
    avgDepth: 18.0,
    waterTemp: 22.0,
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  final source = DiveSourceExport(
    id: 'src-a',
    diveId: 'dive-1',
    ordinal: 0,
    isPrimary: true,
    importedAt: DateTime(2019, 6, 2, 18, 41, 7),
    createdAt: DateTime(2019, 6, 2, 18, 41, 7),
    rawData: Uint8List.fromList([1, 2, 3, 4]),
    computerId: 'computer_9c21',
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: 5,
  );

  test('emits the dive link but no computer link', () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      dataSources: [source],
    );
    final doc = XmlDocument.parse(xml);

    // This path declares no <divecomputer>, so a computer ref would dangle.
    expect(doc.findAllElements('divecomputer'), isEmpty);
    final dump = doc.findAllElements('divecomputerdump').single;
    expect(
      dump.findElements('link').map((e) => e.getAttribute('ref')),
      ['dive_dive-1'],
    );
  });

  test('hosts the source record in its own top level applicationdata',
      () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      dataSources: [source],
    );
    final doc = XmlDocument.parse(xml);

    final topLevel = doc.rootElement.childElements
        .where((e) => e.name.local == 'applicationdata')
        .toList();
    expect(topLevel, hasLength(1));
    expect(
      topLevel.single.findElements('submersion').single
          .findElements('datasources'),
      hasLength(1),
    );
  });

  test('omits both sections when includeRawData is false', () async {
    final xml = await UddfExportService().generateDivesUddfContent(
      [dive],
      dataSources: [source],
      options: const UddfExportOptions(includeRawData: false),
    );
    final doc = XmlDocument.parse(xml);

    expect(doc.findAllElements('divecomputercontrol'), isEmpty);
    expect(doc.findAllElements('datasources'), isEmpty);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart -r compact
```

Expected: FAIL, `generateDivesUddfContent` takes no `dataSources`.

- [ ] **Step 3: Wire the dives-only export**

In `lib/core/services/export/uddf/uddf_export_service.dart`:

1. Add the same three imports as Task 4 step 4.

2. Make `generateDivesUddfContent` `Future<String>` and add the parameters:

```dart
    List<DiveSourceExport>? dataSources,
    UddfExportOptions options = const UddfExportOptions(),
```

3. Compute `sources` and `encodedById` exactly as in Task 4 step 3, before `final builder = XmlBuilder();`.

4. As the final children of `<uddf>`, after the existing `profiledata` element closes, add:

```dart
        // This path has no top level <applicationdata><submersion> block of
        // its own: the only <applicationdata> it writes is the per dive
        // inline one for custom fields. So the source record gets its own
        // wrapper here. UDDF permits <applicationdata> in both positions and
        // the inline ones are untouched.
        if (sources.isNotEmpty) {
          builder.element(
            'applicationdata',
            nest: () {
              builder.element(
                'submersion',
                attributes: {'version': '1.0'},
                nest: () {
                  UddfExportBuilders.buildDataSources(builder, sources);
                },
              );
            },
          );
        }

        // The dives only export declares no <divecomputer>, so a computer
        // ref would dangle under IDREF validation.
        UddfExportBuilders.buildDiveComputerControl(
          builder,
          sources,
          encodedById,
          declaresComputers: false,
        );
```

5. Update `exportDivesToUddf` and `saveDivesToUddfFile` to take and forward both parameters, awaiting `generateDivesUddfContent`.

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart -r compact
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/core/services/export/uddf/uddf_export_service.dart test/core/services/export/uddf/uddf_dives_export_raw_data_test.dart
git commit -m "feat(export): carry raw dive data in the dives only UDDF export (#228)"
```

---

### Task 6: Thread options through ExportService and the providers

**Files:**
- Modify: `lib/core/services/export/export_service.dart` (the four UDDF entry points, lines 314-434)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (`exportDivesToUddf` at 392, `saveUddfToFile` at 1002)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:5871`, `lib/features/dive_log/presentation/widgets/dive_list_content.dart:690`, `lib/features/buddies/presentation/pages/buddy_detail_page.dart:395`
- Test: `test/features/settings/presentation/providers/uddf_export_options_test.dart`

**Interfaces:**
- Consumes: `UddfExportOptions`, `getSourcesForExport`.
- Produces: `ExportService.exportDivesToUddf(List<Dive> dives, {List<DiveSite>? sites, Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures, List<DiveSourceExport>? dataSources, UddfExportOptions options})` and the same shape on the other three. `ExportNotifier.exportDivesToUddf([UddfExportOptions? options])` and `saveUddfToFile([UddfExportOptions? options])`. Plus a new top-level `Future<List<DiveSourceExport>> resolveDataSources(DiveRepository repository, List<String> diveIds, UddfExportOptions options)` in `lib/core/services/export/uddf/uddf_source_fetch.dart`.

- [ ] **Step 1: Write the failing test**

Testing the notifier means standing up its whole provider graph, which is disproportionate for a boolean. Test the behaviour that actually matters at the seam instead: that a disabled export never issues the query. Create `test/features/settings/presentation/providers/uddf_export_options_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

import '../../../../helpers/test_database.dart';

/// Records whether the export path asked for data sources.
class RecordingDiveRepository implements DiveRepository {
  int calls = 0;

  @override
  Future<List<DiveSourceExport>> getSourcesForExport(List<String> diveIds) {
    calls++;
    return Future.value(const []);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The fetch rule the notifier and the three page call sites all follow.
Future<List<DiveSourceExport>> resolveDataSources(
  DiveRepository repository,
  List<String> diveIds,
  UddfExportOptions options,
) async {
  if (!options.includeRawData) return const [];
  return repository.getSourcesForExport(diveIds);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  test('fetches sources when raw data is included', () async {
    final repository = RecordingDiveRepository();

    await resolveDataSources(
      repository,
      const ['dive-1'],
      const UddfExportOptions(),
    );

    expect(repository.calls, 1);
  });

  test('never queries when raw data is excluded', () async {
    // A share with the box unchecked must not pay for a query it will not
    // use, which is the entire point of the toggle on the dives only paths.
    final repository = RecordingDiveRepository();

    final result = await resolveDataSources(
      repository,
      const ['dive-1'],
      const UddfExportOptions(includeRawData: false),
    );

    expect(repository.calls, 0);
    expect(result, isEmpty);
  });
}
```

`resolveDataSources` is not a test-only helper: extract it into `lib/core/services/export/uddf/uddf_source_fetch.dart` as a top-level function and call it from the notifier and from all three page call sites, so there is one rule rather than four copies of it, and this test covers all four. Import it in the test instead of redeclaring it.

If `implements DiveRepository` will not compile because the class is `final` or has a private generative constructor, wrap instead: define an abstract `UddfSourceFetcher` with the single method, have the production code depend on that, and give the test a plain implementation.

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/features/settings/presentation/providers/uddf_export_options_test.dart -r compact
```

Expected: FAIL.

- [ ] **Step 3: Thread the parameters through ExportService**

For each of `exportDivesToUddf`, `saveDivesToUddfFile`, `exportAllDataToUddf` and `saveAllDataToUddfFile` in `lib/core/services/export/export_service.dart`, add `List<DiveSourceExport>? dataSources` and `UddfExportOptions options = const UddfExportOptions()` and forward both. Add the two imports.

- [ ] **Step 4: Fetch sources in the notifier**

In `export_providers.dart`, in both `exportDivesToUddf` and `saveUddfToFile`, before calling the service:

First create `lib/core/services/export/uddf/uddf_source_fetch.dart`:

```dart
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';

/// Whether an export fetches source rows, and the fetch itself.
///
/// One rule rather than four copies of it: the settings notifier and the
/// three page call sites all go through here. A share with the box unchecked
/// must not pay for a query it will not use, which is the whole point of the
/// toggle on the dives only paths.
Future<List<DiveSourceExport>> resolveDataSources(
  DiveRepository repository,
  List<String> diveIds,
  UddfExportOptions options,
) async {
  if (!options.includeRawData) return const [];
  return repository.getSourcesForExport(diveIds);
}
```

Then in both notifier methods, before calling the service:

```dart
    final dataSources = await resolveDataSources(
      _diveRepository,
      dives.map((d) => d.id).toList(growable: false),
      exportOptions,
    );
```

and pass `dataSources: dataSources, options: exportOptions`. Give both methods an `[UddfExportOptions? options]` parameter resolving to `options ?? const UddfExportOptions()`, mirroring `exportDivesToPdf` at line 257.

- [ ] **Step 5: Update the three direct call sites**

`dive_detail_page.dart:5871`, `dive_list_content.dart:690`, and `buddy_detail_page.dart:395` call `ExportService` directly. Each calls the same `resolveDataSources` and passes both new arguments. Read the surrounding code for how each obtains a repository; if a page has no repository handle, add one via the existing provider rather than reaching into the database.

- [ ] **Step 6: Run the tests**

```bash
flutter test test/features/settings/presentation/providers/uddf_export_options_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 7: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add -u
git commit -m "feat(export): thread UDDF raw data options through the export paths (#228)"
```

---

### Task 7: Parse the two new sections on import

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart`
- Test: `test/core/services/export/uddf/uddf_dcdump_import_parse_test.dart`

**Interfaces:**
- Consumes: `UddfDumpCodec.decodeOne` (Task 1).
- Produces: `UddfImportResult` gains `final Map<String, List<Map<String, dynamic>>> dataSourcesByDiveRef` and `final int unpairedDumps`. Each inner map carries the `<source>` fields under camelCase keys (`descriptorVendor`, `descriptorProduct`, `descriptorModel`, `libdivecomputerVersion`, `sourceUuid`, `rawFingerprint` as `Uint8List?`, `isPrimary` as `bool`, `mergeSourceSlot`, `timeOffsetSeconds`, `computerModel`, `computerSerial`, `sourceFormat`, `sourceFileName`, `sourceFileFormat`, `importedAt`, `createdAt`, `lastParsedAt`, `maxDepth`, `avgDepth`, `duration`, `waterTemp`, `entryLatitude`, `entryLongitude`, `exitLatitude`, `exitLongitude`, `entryTime`, `exitTime`, `maxAscentRate`, `maxDescentRate`, `surfaceInterval`, `cns`, `otu`, `decoAlgorithm`, `gradientFactorLow`, `gradientFactorHigh`), plus `ordinal` as `int` and `rawData` as `Uint8List?`.

Keys are the `diveref` attribute value, for example `dive_7f3a...`; entries within a key are sorted by `ordinal`.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/export/uddf/uddf_dcdump_import_parse_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

String document({required String applicationData, required String control}) {
  return '''
<uddf version="3.2.0" xmlns="http://www.streit.cc/uddf/3.2/">
  <profiledata>
    <repetitiongroup>
      <dive id="dive_d1">
        <informationbeforedive><datetime>2019-06-02T10:00:00</datetime></informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
  $applicationData
  $control
</uddf>
''';
}

void main() {
  final raw = Uint8List.fromList([9, 8, 7, 6, 5]);
  final payload = UddfDumpCodec.encodeOne(raw);

  test('pairs a dump with its source entry by diveref and ordinal', () async {
    final xml = document(
      applicationData: '''
  <applicationdata>
    <submersion version="1.0">
      <datasources>
        <source diveref="dive_d1" ordinal="0" hasdump="true">
          <descriptor vendor="Shearwater" product="Perdix" model="5"/>
          <primary>true</primary>
          <fingerprint>A17F3C</fingerprint>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
          <maxdepth>31.5</maxdepth>
        </source>
      </datasources>
    </submersion>
  </applicationdata>''',
      control: '''
  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_d1"/>
      <datetime>2019-06-02T18:41:07</datetime>
      <dcdump>$payload</dcdump>
    </divecomputerdump>
  </divecomputercontrol>''',
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    final entries = result.dataSourcesByDiveRef['dive_d1']!;

    expect(entries, hasLength(1));
    expect(entries.single['rawData'], equals(raw));
    expect(entries.single['descriptorVendor'], 'Shearwater');
    expect(entries.single['descriptorModel'], 5);
    expect(entries.single['isPrimary'], isTrue);
    expect(entries.single['maxDepth'], 31.5);
    expect(
      entries.single['rawFingerprint'],
      equals(Uint8List.fromList([0xA1, 0x7F, 0x3C])),
    );
    expect(
      entries.single['importedAt'],
      DateTime.parse('2019-06-02T18:41:07.000'),
    );
    expect(result.unpairedDumps, 0);
  });

  test('an entry claiming a dump that is absent restores without bytes',
      () async {
    final xml = document(
      applicationData: '''
  <applicationdata>
    <submersion version="1.0">
      <datasources>
        <source diveref="dive_d1" ordinal="0" hasdump="true">
          <primary>true</primary>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>
      </datasources>
    </submersion>
  </applicationdata>''',
      control: '',
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    final entries = result.dataSourcesByDiveRef['dive_d1']!;

    // It must not pair with the next dump along.
    expect(entries.single['rawData'], isNull);
  });

  test('a spec shaped dump with no source entry still yields its bytes',
      () async {
    final xml = document(
      applicationData: '',
      control: '''
  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_d1"/>
      <datetime>2019-06-02T18:41:07</datetime>
      <dcdump>$payload</dcdump>
    </divecomputerdump>
  </divecomputercontrol>''',
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    final entries = result.dataSourcesByDiveRef['dive_d1']!;

    expect(entries.single['rawData'], equals(raw));
    expect(entries.single['descriptorVendor'], isNull);
    expect(entries.single['isPrimary'], isTrue);
  });

  test('a submersion block holding only datasources parses cleanly', () async {
    final xml = document(
      applicationData: '''
  <applicationdata>
    <submersion version="1.0">
      <datasources>
        <source diveref="dive_d1" ordinal="0" hasdump="false">
          <primary>true</primary>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>
      </datasources>
    </submersion>
  </applicationdata>''',
      control: '',
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);
    expect(result.dataSourcesByDiveRef['dive_d1'], hasLength(1));
  });

  test('the dump datetime does not become the dive time', () async {
    final xml = document(
      applicationData: '',
      control: '''
  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_d1"/>
      <datetime>2031-12-25T03:00:00</datetime>
      <dcdump>$payload</dcdump>
    </divecomputerdump>
  </divecomputercontrol>''',
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);

    expect(result.dives.single['dateTime'], DateTime(2019, 6, 2, 10, 0));
  });

  test('an oversized dump is skipped and counted, not thrown', () async {
    final bomb = UddfDumpCodec.encodeOne(Uint8List(12 * 1024 * 1024));
    final xml = document(
      applicationData: '',
      control: '''
  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_d1"/>
      <datetime>2019-06-02T18:41:07</datetime>
      <dcdump>$bomb</dcdump>
    </divecomputerdump>
  </divecomputercontrol>''',
    );

    final result = await UddfFullImportService().importAllDataFromUddf(xml);

    expect(result.dataSourcesByDiveRef['dive_d1'] ?? const [], isEmpty);
    expect(result.unpairedDumps, 1);
  });
}
```

Check `UddfImportResult`'s existing field for parsed dives; if it is not `dives` holding `List<Map<String, dynamic>>`, adjust the fifth test's assertion to match. Read `lib/core/services/export/models/uddf_import_result.dart` first.

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/core/services/export/uddf/uddf_dcdump_import_parse_test.dart -r compact
```

Expected: FAIL, `dataSourcesByDiveRef` is not defined.

- [ ] **Step 3: Implement the parse**

In `lib/core/services/export/models/uddf_import_result.dart`, add the two fields with defaults (`const {}` and `0`) so no existing construction breaks.

In `uddf_full_import_service.dart`, add a private method and call it before building the result:

```dart
  /// Parse `<applicationdata><submersion><datasources>` and
  /// `<divecomputercontrol>`, joining them on (diveref, ordinal).
  ///
  /// Two passes rather than one: the standard section carries the bytes and
  /// the Submersion section carries everything the standard cannot express,
  /// most importantly the libdivecomputer descriptor triple. Without that
  /// triple a restored blob can never be re-parsed
  /// (`reparse_service.dart` skips any source missing it).
  ///
  /// A dump with no matching entry still yields its bytes, as a lone primary
  /// source with a null descriptor: those bytes are not ours to discard, and
  /// re-parse already reports a source it cannot parse.
  ({Map<String, List<Map<String, dynamic>>> byDiveRef, int unpaired})
  _parseDataSources(XmlElement uddfElement) {
    final entries = <String, List<Map<String, dynamic>>>{};

    for (final appData in uddfElement.findElements('applicationdata')) {
      for (final submersion in appData.findElements('submersion')) {
        for (final block in submersion.findElements('datasources')) {
          for (final source in block.findElements('source')) {
            final diveRef = source.getAttribute('diveref');
            if (diveRef == null) continue;
            entries
                .putIfAbsent(diveRef, () => <Map<String, dynamic>>[])
                .add(_parseSourceEntry(source));
          }
        }
      }
    }

    for (final list in entries.values) {
      list.sort(
        (a, b) => (a['ordinal'] as int).compareTo(b['ordinal'] as int),
      );
    }

    var unpaired = 0;
    final nextOrdinal = <String, int>{};

    for (final control in uddfElement.findElements('divecomputercontrol')) {
      for (final dump in control.findElements('divecomputerdump')) {
        final diveRef = dump
            .findElements('link')
            .map((e) => e.getAttribute('ref'))
            .firstWhere(
              (ref) => ref != null && ref.startsWith('dive_'),
              orElse: () => null,
            );
        final text = dump.findElements('dcdump').firstOrNull?.innerText;
        if (diveRef == null || text == null || text.trim().isEmpty) {
          unpaired++;
          continue;
        }

        Uint8List bytes;
        try {
          bytes = UddfDumpCodec.decodeOne(text);
        } catch (e) {
          // Untrusted input: a bomb, a truncated stream, or something that
          // is not bzip2 at all. Count it and keep importing.
          _log.warning('Skipping unreadable <dcdump> for $diveRef: $e');
          unpaired++;
          continue;
        }

        final ordinal = nextOrdinal.update(
          diveRef,
          (v) => v + 1,
          ifAbsent: () => 0,
        );
        final list = entries[diveRef];
        final match = list?.firstWhereOrNull(
          (e) => e['ordinal'] == ordinal && e['hasDump'] == true,
        );
        if (match != null) {
          match['rawData'] = bytes;
        } else {
          entries.putIfAbsent(diveRef, () => <Map<String, dynamic>>[]).add({
            'ordinal': ordinal,
            'hasDump': true,
            'rawData': bytes,
            'isPrimary': entries[diveRef]?.isEmpty ?? true,
          });
        }
      }
    }

    return (byDiveRef: entries, unpaired: unpaired);
  }
```

Write `_parseSourceEntry(XmlElement)` to read every child element listed in the Interfaces block into the camelCase key of the same name, using the file's existing `UddfImportParsers.getElementText` plus `int.tryParse` / `double.tryParse` / `DateTime.tryParse`, and `ordinal` / `hasDump` from the attributes. Hex-decode `<fingerprint>` into a `Uint8List` two characters at a time.

`firstWhereOrNull` comes from `package:collection/collection.dart`; add the import. `_log` follows whatever logger this file already uses, otherwise drop the line.

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/core/services/export/uddf/uddf_dcdump_import_parse_test.dart -r compact
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/core/services/export/uddf/uddf_full_import_service.dart lib/core/services/export/models/uddf_import_result.dart test/core/services/export/uddf/uddf_dcdump_import_parse_test.dart
git commit -m "feat(import): parse UDDF dcdump and data source records (#228)"
```

---

### Task 8: Batch source insert, so profile adoption stays correct

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (near `saveComputerReading`, line 6418)
- Test: `test/features/dive_log/data/repositories/save_computer_readings_batch_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `Future<void> saveComputerReadings(List<DiveDataSourcesCompanion> readings)` on `DiveRepository`.

**Why this task exists.** `saveComputerReading` calls `_adoptUnattributedProfiles`, which claims a dive's unattributed profile series for the inserted source, but only when it is the dive's sole source row (`dive_repository_impl.dart:6455`). Its doc comment explains the guard: with a second source present the rows could belong to either, and a guess would be worse. Calling it in a loop defeats that, because the **first** insert sees one row and adopts everything before the second row exists. A two-source restore would silently attribute the whole dive's profile to source one.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/save_computer_readings_batch_test.dart`. Reuse the `insertDive` helper shape from Task 2's test.

```dart
  test('adopts unattributed profiles when the batch leaves one source',
      () async {
    await insertDive('dive-1');
    await insertUnattributedSeries('dive-1');

    await repository.saveComputerReadings([reading('src-a', 'dive-1')]);

    expect(await sourceIdOfSeries('dive-1'), 'src-a');
  });

  test('does not adopt when the batch leaves more than one source', () async {
    // The guard exists because with two sources the rows could belong to
    // either. Inserting them one at a time would let the first row claim
    // everything before the second exists.
    await insertDive('dive-1');
    await insertUnattributedSeries('dive-1');

    await repository.saveComputerReadings([
      reading('src-a', 'dive-1', isPrimary: true),
      reading('src-b', 'dive-1'),
    ]);

    expect(await sourceIdOfSeries('dive-1'), isNull);
    expect(await countSources('dive-1'), 2);
  });

  test('inserts every row in the batch', () async {
    await insertDive('dive-1');

    await repository.saveComputerReadings([
      reading('src-a', 'dive-1', isPrimary: true),
      reading('src-b', 'dive-1'),
      reading('src-c', 'dive-1'),
    ]);

    expect(await countSources('dive-1'), 3);
  });

  test('an empty batch is a no-op', () async {
    await repository.saveComputerReadings(const []);
  });
```

Write `insertUnattributedSeries`, `sourceIdOfSeries`, `countSources` and `reading` as local helpers. Read `test/features/dive_computer/data/services/raw_data_persistence_test.dart` for how `dive_profile_series` rows are constructed in this codebase, and mirror it.

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/features/dive_log/data/repositories/save_computer_readings_batch_test.dart -r compact
```

Expected: FAIL, `saveComputerReadings` is not defined.

- [ ] **Step 3: Implement the batch insert**

Add after `saveComputerReading`:

```dart
  /// Insert several `dive_data_sources` rows as one unit.
  ///
  /// Not a loop over [saveComputerReading]. That one adopts a dive's
  /// unattributed profile rows for the row it just inserted, and only when
  /// that row is the dive's sole source; the guard is there because with a
  /// second source present the rows could belong to either. Inserting one at
  /// a time would let the first row adopt everything before the second row
  /// exists, so a restored two computer dive would attribute the whole
  /// profile to whichever source happened to go in first.
  ///
  /// Inserting the whole batch first and evaluating the rule once afterwards
  /// is what keeps that guard meaning what it says.
  Future<void> saveComputerReadings(
    List<DiveDataSourcesCompanion> readings,
  ) async {
    if (readings.isEmpty) return;
    try {
      await _db.transaction(() async {
        for (final reading in readings) {
          await _db.into(_db.diveDataSources).insert(reading);
        }
      });
      for (final reading in readings) {
        await _adoptUnattributedProfiles(reading);
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save computer readings',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

`_adoptUnattributedProfiles` re-counts the dive's rows and returns early unless there is exactly one, so running it after the batch is correct for both cases and needs no change.

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/features/dive_log/data/repositories/save_computer_readings_batch_test.dart -r compact
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/save_computer_readings_batch_test.dart
git commit -m "feat(dive-log): batch data source inserts so profile adoption stays correct (#228)"
```

---

### Task 9: Restore one source row per entry

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (the provenance write at line 2077-2102)
- Test: `test/features/dive_import/data/services/uddf_restore_data_sources_test.dart`

**Interfaces:**
- Consumes: `saveComputerReadings` (Task 8), `dataSourcesByDiveRef` (Task 7).
- Produces: `UddfEntityImporter.import` accepts `Map<String, List<Map<String, dynamic>>> dataSourcesByDiveRef = const {}`; `UddfEntityImportResult` gains `final int restoredDataSources`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_import/data/services/uddf_restore_data_sources_test.dart`. The harness below is copied from `test/features/dive_import/uddf_import_source_uuid_test.dart`, which is the working reference for driving this importer against a real in-memory database.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart' as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'dart:typed_data';

import '../../../helpers/test_database.dart';

ImportRepositories buildRepositories() => ImportRepositories(
      tripRepository: TripRepository(),
      equipmentRepository: EquipmentRepository(),
      equipmentSetRepository: EquipmentSetRepository(),
      buddyRepository: BuddyRepository(),
      diveCenterRepository: DiveCenterRepository(),
      certificationRepository: CertificationRepository(),
      tagRepository: TagRepository(),
      diveTypeRepository: DiveTypeRepository(),
      siteRepository: SiteRepository(),
      diveRepository: DiveRepository(),
      tankPressureRepository: TankPressureRepository(),
      courseRepository: CourseRepository(),
    );

Future<String> createTestDiver() async {
  final now = DateTime.now();
  const diverId = 'diver-restore-sources-test';
  await DiverRepository().createDiver(
    domain.Diver(
      id: diverId,
      name: 'Test Diver',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return diverId;
}

final raw = Uint8List.fromList(List<int>.generate(320, (i) => (i * 7) % 256));

/// A UDDF document with one dive and the given `<source>` entries.
String buildUddf({required String sources, String control = ''}) {
  return '''<uddf version="3.2.1">
  <gasdefinitions>
    <mix id="mix1"><name>Air</name><o2>0.21</o2><he>0.00</he></mix>
  </gasdefinitions>
  <profiledata>
    <repetitiongroup id="repgrp1">
      <dive id="DIVE-1">
        <informationbeforedive>
          <datetime>2019-06-02T10:00:00</datetime>
          <divenumber>1</divenumber>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>31.5</greatestdepth>
          <diveduration>2400.0</diveduration>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
  <applicationdata>
    <submersion version="1.0">
      <datasources>
$sources
      </datasources>
    </submersion>
  </applicationdata>
$control
</uddf>''';
}

String entry({
  required int ordinal,
  required bool hasDump,
  required bool primary,
  String computerModel = 'Perdix AI',
  String computerSerial = 'SN-A',
  String importedAt = '2019-06-02T18:41:07.000',
  double maxDepth = 31.5,
  int? mergeSourceSlot = 0,
}) {
  return '''        <source diveref="dive_DIVE-1" ordinal="$ordinal" hasdump="$hasDump">
          <descriptor vendor="Shearwater" product="Perdix" model="5"/>
          <primary>$primary</primary>
          <mergesourceslot>$mergeSourceSlot</mergesourceslot>
          <computermodel>$computerModel</computermodel>
          <computerserial>$computerSerial</computerserial>
          <importedat>$importedAt</importedat>
          <createdat>$importedAt</createdat>
          <maxdepth>$maxDepth</maxdepth>
        </source>''';
}

String dumpFor(String payload) => '''  <divecomputercontrol>
    <divecomputerdump>
      <link ref="dive_DIVE-1"/>
      <datetime>2019-06-02T18:41:07</datetime>
      <dcdump>$payload</dcdump>
    </divecomputerdump>
  </divecomputercontrol>''';

void main() {
  late AppDatabase db;
  final importer = UddfEntityImporter();
  final exportService = ExportService();

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> runImport(String xml) async {
    final diverId = await createTestDiver();
    final parsed = await exportService.importAllDataFromUddf(xml);
    await importer.import(
      data: parsed,
      selections: const UddfImportSelections(dives: {0}),
      repositories: buildRepositories(),
      diverId: diverId,
      dataSourcesByDiveRef: parsed.dataSourcesByDiveRef,
    );
  }

  test('restores every source row losslessly, bytes and all', () async {
    // The assertion the whole multi source design exists to satisfy.
    await runImport(
      buildUddf(
        sources: '${entry(ordinal: 0, hasDump: true, primary: true)}\n'
            '${entry(ordinal: 1, hasDump: false, primary: false, computerModel: 'Teric', computerSerial: 'SN-B', maxDepth: 30.9, mergeSourceSlot: 1)}',
        control: dumpFor(UddfDumpCodec.encodeOne(raw)),
      ),
    );

    final rows = await (db.select(db.diveDataSources)
          ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
        .get();

    expect(rows, hasLength(2));
    expect(rows[0].isPrimary, isTrue);
    expect(rows[1].isPrimary, isFalse);
    expect(rows[0].rawData, equals(raw));
    expect(rows[1].rawData, isNull);
    expect(rows[0].descriptorVendor, 'Shearwater');
    expect(rows[0].descriptorProduct, 'Perdix');
    expect(rows[0].descriptorModel, 5);
    expect(rows[0].mergeSourceSlot, 0);
    expect(rows[1].mergeSourceSlot, 1);
    expect(rows[0].maxDepth, 31.5);
    expect(rows[1].maxDepth, 30.9);
    expect(rows[1].computerModel, 'Teric');
  });

  test('writes no synthesised row alongside the restored ones', () async {
    await runImport(
      buildUddf(sources: entry(ordinal: 0, hasDump: false, primary: true)),
    );

    expect(await db.select(db.diveDataSources).get(), hasLength(1));
  });

  test('a document with no entries keeps the old single row behaviour',
      () async {
    await runImport('''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="repgrp1">
      <dive id="DIVE-1">
        <informationbeforedive><datetime>2019-06-02T10:00:00</datetime></informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''');

    final rows = await db.select(db.diveDataSources).get();
    expect(rows, hasLength(1));
    expect(rows.single.isPrimary, isTrue);
    expect(rows.single.rawData, isNull);
  });

  test('two entries claiming primary restore exactly one primary', () async {
    await runImport(
      buildUddf(
        sources: '${entry(ordinal: 0, hasDump: false, primary: true)}\n'
            '${entry(ordinal: 1, hasDump: false, primary: true, computerSerial: 'SN-B')}',
      ),
    );

    final rows = await db.select(db.diveDataSources).get();
    expect(rows.where((r) => r.isPrimary), hasLength(1));
  });

  test('no entry claiming primary promotes the first', () async {
    await runImport(
      buildUddf(
        sources: '${entry(ordinal: 0, hasDump: false, primary: false)}\n'
            '${entry(ordinal: 1, hasDump: false, primary: false, computerSerial: 'SN-B')}',
      ),
    );

    final rows = await db.select(db.diveDataSources).get();
    expect(rows.where((r) => r.isPrimary), hasLength(1));
  });

  test('importedAt comes from the entry, not the import clock', () async {
    await runImport(
      buildUddf(sources: entry(ordinal: 0, hasDump: false, primary: true)),
    );

    final rows = await db.select(db.diveDataSources).get();
    expect(
      rows.single.importedAt,
      DateTime.parse('2019-06-02T18:41:07.000'),
      reason: 'A restore must not relabel a 2019 dive with today, since the '
          'data sources panel shows this value as "Imported".',
    );
  });

  test('each source resolves its own computer from model and serial',
      () async {
    await runImport(
      buildUddf(
        sources: '${entry(ordinal: 0, hasDump: false, primary: true)}\n'
            '${entry(ordinal: 1, hasDump: false, primary: false, computerModel: 'Teric', computerSerial: 'SN-B')}',
      ),
    );

    final rows = await db.select(db.diveDataSources).get();
    final computerIds = rows.map((r) => r.computerId).toSet();
    expect(
      computerIds.length,
      2,
      reason: 'Two different model plus serial pairs must not collapse onto '
          'one registered computer.',
    );
  });
}
```

The last test needs `diveComputerRepository` present in the bundle for computers to be registered at all. If `buildRepositories()` leaves it null, add `diveComputerRepository: DiveComputerRepository()` and its import; without it, `computerIdByKey` is empty and both rows get a null computer id.

- [ ] **Step 2: Run the test and verify it fails**

```bash
flutter test test/features/dive_import/data/services/uddf_restore_data_sources_test.dart -r compact
```

Expected: FAIL.

- [ ] **Step 3: Replace the single synthesised row**

Replace the `saveComputerReading` call at `uddf_entity_importer.dart:2078` with:

```dart
      // Provenance. A dive that arrived with <source> entries has its source
      // rows defined by them, so the synthesised row below is NOT written:
      // writing both would leave the dive with one more source than it was
      // exported with. A dive with no entries keeps today's behaviour
      // exactly, which is every foreign UDDF file and every older export.
      final entries = dataSourcesByDiveRef['dive_${diveData['uddfId']}'] ??
          dataSourcesByDiveRef['dive_$diveId'] ??
          const <Map<String, dynamic>>[];

      if (entries.isEmpty) {
        await repos.diveRepository.saveComputerReading(
          DiveDataSourcesCompanion(
            // ... the existing companion, unchanged ...
          ),
        );
      } else {
        await repos.diveRepository.saveComputerReadings(
          _restoredSourceCompanions(
            entries: entries,
            diveId: diveId,
            computerIdByKey: computerIdByKey,
            fallbackComputerId: computerId,
            now: now,
          ),
        );
        restoredDataSources += entries.length;
      }
```

Add the helper:

```dart
  /// One companion per restored `<source>` entry.
  ///
  /// Exactly one row must end up primary. A hand edited or malformed file
  /// could claim zero or several, and a dive with no primary source would
  /// break primary source resolution for that dive permanently. The first
  /// entry claiming it wins; if none claims it, the first entry is promoted.
  ///
  /// Computers resolve through model and serial, NOT through the dump's
  /// `<link ref="computer_...">`. `computerIdByKey` is keyed by
  /// `_importedComputerKey`, which normalises model plus serial; the
  /// exported computer id belongs to an id space this importer never uses.
  List<DiveDataSourcesCompanion> _restoredSourceCompanions({
    required List<Map<String, dynamic>> entries,
    required String diveId,
    required Map<String, String> computerIdByKey,
    required String? fallbackComputerId,
    required DateTime now,
  }) {
    var primaryIndex = entries.indexWhere((e) => e['isPrimary'] == true);
    if (primaryIndex < 0) primaryIndex = 0;

    return [
      for (var i = 0; i < entries.length; i++)
        _companionFor(
          entries[i],
          diveId: diveId,
          isPrimary: i == primaryIndex,
          computerId: _resolveRestoredComputerId(
                entries[i],
                computerIdByKey,
              ) ??
              (i == primaryIndex ? fallbackComputerId : null),
          now: now,
        ),
    ];
  }

  String? _resolveRestoredComputerId(
    Map<String, dynamic> entry,
    Map<String, String> computerIdByKey,
  ) {
    final model = normalizeComputerIdentityPart(
      entry['computerModel'] as String?,
    );
    if (model.isEmpty) return null;
    final serial = normalizeComputerIdentityPart(
      entry['computerSerial'] as String?,
    );
    return computerIdByKey['$model|$serial'];
  }
```

Read `_importedComputerKey` at line 1310 and build the same key string here; if it joins with something other than `|`, match it exactly. Better still, extract the key construction into a shared private method and call it from both, so the two cannot drift.

Write `_companionFor` to map every entry key onto its `DiveDataSourcesCompanion` field, minting a fresh `_uuid.v4()` for `id`, using `Value(entry['importedAt'] as DateTime? ?? now)` for `importedAt` and the same for `createdAt`, and `Value.absent()` for any key the entry does not carry.

Thread `dataSourcesByDiveRef` from `importAllDataFromUddf`'s result through to `import`, declare `var restoredDataSources = 0;` alongside the other counters, and add it to `UddfEntityImportResult`.

- [ ] **Step 4: Run the test and verify it passes**

```bash
flutter test test/features/dive_import/data/services/uddf_restore_data_sources_test.dart -r compact
```

Expected: PASS, 7 tests.

- [ ] **Step 5: Run the import suites for regressions**

```bash
flutter test test/core/services/export/uddf test/features/dive_import -r compact
```

Expected: PASS.

- [ ] **Step 6: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/features/dive_import/data/services/uddf_entity_importer.dart test/features/dive_import/data/services/uddf_restore_data_sources_test.dart
git commit -m "feat(import): restore one data source row per UDDF source entry (#228)"
```

---

### Task 10: The toggle, strings, and generated l10n

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the other 10 locale files
- Modify: `lib/features/transfer/presentation/pages/transfer_page.dart:339`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:5871`, `lib/features/dive_log/presentation/widgets/dive_list_content.dart:690`, `lib/features/buddies/presentation/pages/buddy_detail_page.dart:395`

**Interfaces:**
- Consumes: `UddfExportOptions` (Task 4), the notifier parameters (Task 6).
- Produces: four new l10n keys.

- [ ] **Step 1: Add the English strings**

In `lib/l10n/arb/app_en.arb`, alphabetically near the other `settings_export_` keys:

```json
  "settings_export_uddf_includeRawData": "Include raw dive computer data",
  "settings_export_uddf_includeRawDataHelp": "Keeps the original bytes downloaded from your dive computer, so the export can be re-parsed after a restore. Makes the file larger.",
  "settings_export_uddf_skippedDumps": "{count, plural, =1{1 raw data record could not be included} other{{count} raw data records could not be included}}",
  "settings_export_uddf_restoredDumps": "{count, plural, =1{Restored 1 raw data record} other{Restored {count} raw data records}}",
```

- [ ] **Step 2: Add translations to the other 10 locales**

Add the same four keys to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`, translated, keeping the ICU plural syntax and the `{count}` placeholder intact in each.

- [ ] **Step 3: Regenerate l10n**

```bash
flutter gen-l10n
```

Then confirm the generated hub picked the keys up:

```bash
grep -c "settings_export_uddf_includeRawData" lib/l10n/arb/app_localizations.dart
```

Expected: at least 2 (declaration plus doc comment).

- [ ] **Step 4: Add the checkbox to the export UI**

In `transfer_page.dart` at the UDDF export action (line 339), add a `CheckboxListTile` bound to local state initialised to `true`, labelled `context.l10n.settings_export_uddf_includeRawData` with `subtitle` `settings_export_uddf_includeRawDataHelp`, and pass `UddfExportOptions(includeRawData: value)` into the notifier call. Follow whatever dialog or sheet pattern the PDF export options already use in this file.

Do the same at the three dives-only call sites, each pre-checked.

- [ ] **Step 5: Verify the app builds and the widget tests pass**

```bash
flutter test test/features/transfer test/features/settings -r compact
```

Expected: PASS. A new provider dependency can break consumer widget tests that do not override it; if a test fails on a missing override, add the override rather than weakening the provider.

- [ ] **Step 6: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add lib/l10n lib/features/transfer lib/features/dive_log lib/features/buddies
git commit -m "feat(export): add the raw dive data toggle and its strings (#228)"
```

---

### Task 11: The full round trip

**Files:**
- Test: `test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart`

**Interfaces:**
- Consumes: everything.
- Produces: nothing. This task adds no production code; if it needs any, that is a defect found and the fix belongs here.

- [ ] **Step 1: Write the round trip test**

Create `test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart`. Reuse `buildRepositories`, `createTestDiver` and the `setUpTestDatabase` harness from Task 9's test verbatim; the round trip differs only in that the document comes from the real exporter rather than a string literal.

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

// Plus the same repository and diver helper imports as Task 9's test.
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  final fixture = Uint8List.fromList(
    File('packages/libdivecomputer_plugin/android/src/androidTest/assets/'
            'shearwater_teric_dive.bin')
        .readAsBytesSync(),
  );

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  test('a two source dive survives export and import unchanged', () async {
    // Seed: one dive, two source rows, only the first carrying bytes.
    const diveId = 'dive-rt-1';
    final stamp = DateTime(2019, 6, 2, 18, 41, 7);
    final epoch = DateTime(2019, 6, 2, 10).millisecondsSinceEpoch;

    await db.into(db.dives).insert(
          DivesCompanion(
            id: const Value(diveId),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    await db.into(db.diveDataSources).insert(
          DiveDataSourcesCompanion(
            id: const Value('src-a'),
            diveId: const Value(diveId),
            isPrimary: const Value(true),
            rawData: Value(fixture),
            computerModel: const Value('Perdix AI'),
            computerSerial: const Value('SN-A'),
            descriptorVendor: const Value('Shearwater'),
            descriptorProduct: const Value('Perdix'),
            descriptorModel: const Value(5),
            mergeSourceSlot: const Value(0),
            maxDepth: const Value(31.5),
            cns: const Value(12.5),
            decoAlgorithm: const Value('ZHL16C'),
            importedAt: Value(stamp),
            createdAt: Value(stamp),
          ),
        );
    await db.into(db.diveDataSources).insert(
          DiveDataSourcesCompanion(
            id: const Value('src-b'),
            diveId: const Value(diveId),
            isPrimary: const Value(false),
            computerModel: const Value('Teric'),
            computerSerial: const Value('SN-B'),
            mergeSourceSlot: const Value(1),
            maxDepth: const Value(30.9),
            importedAt: Value(stamp),
            createdAt: Value(stamp.add(const Duration(seconds: 1))),
          ),
        );

    final repository = DiveRepository();
    final sources = await repository.getSourcesForExport([diveId]);
    expect(sources, hasLength(2));

    final dive = Dive(
      id: diveId,
      diveNumber: 1,
      dateTime: DateTime(2019, 6, 2, 10),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 31.5,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      dataSources: sources,
    );

    // Import into a clean database.
    await tearDownTestDatabase();
    db = await setUpTestDatabase();

    final diverId = await createTestDiver();
    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: const UddfImportSelections(dives: {0}),
      repositories: buildRepositories(),
      diverId: diverId,
      dataSourcesByDiveRef: parsed.dataSourcesByDiveRef,
    );

    final restored = await (db.select(db.diveDataSources)
          ..orderBy([(t) => OrderingTerm.desc(t.isPrimary)]))
        .get();

    expect(restored, hasLength(2));
    expect(restored[0].rawData, equals(fixture));
    expect(restored[1].rawData, isNull);
    expect(restored[0].maxDepth, 31.5);
    expect(restored[0].cns, 12.5);
    expect(restored[0].decoAlgorithm, 'ZHL16C');
    expect(restored[0].mergeSourceSlot, 0);
    expect(restored[1].mergeSourceSlot, 1);
    expect(restored[0].importedAt, stamp);

    // Re-parse needs the descriptor triple or it counts the source failed.
    final reparseable = await ReparseService(db: db).getSourcesForDiveReparse(
      restored[0].diveId,
    );
    expect(reparseable, hasLength(1));
    expect(reparseable.single.descriptorVendor, 'Shearwater');
    expect(reparseable.single.descriptorProduct, 'Perdix');
    expect(reparseable.single.descriptorModel, 5);

    // The dump datetime must not have become the dive time.
    final restoredDive =
        await (db.select(db.dives)..limit(1)).getSingle();
    expect(
      DateTime.fromMillisecondsSinceEpoch(restoredDive.diveDateTime),
      DateTime(2019, 6, 2, 10),
    );
  });
}
```

Both verified against the code at plan time: `ReparseService` takes a named `db` (`reparse_service.dart:34`), and `dives.diveDateTime` is an `IntColumn` holding epoch milliseconds (`database.dart:683`), so the conversion above is correct.

- [ ] **Step 2: Run it and fix whatever it finds**

```bash
flutter test test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart -r compact
```

Expected: PASS. This is the test most likely to expose a key-name mismatch between the export writer in Task 3 and the parser in Task 7. Fix the mismatch at whichever end is wrong and re-run.

- [ ] **Step 3: Run the whole suite once**

```bash
flutter test -r compact
```

Expected: PASS. Run this once, not repeatedly, and do not overlap it with another local test run.

- [ ] **Step 4: Format, analyze, and commit**

```bash
dart format . && flutter analyze lib test
```

```bash
git add test/core/services/export/uddf/uddf_raw_data_round_trip_test.dart
git commit -m "test(export): pin the UDDF raw dive data round trip (#228)"
```

---

## Self-Review Notes

**Spec coverage.** Every section of the spec maps to a task: document shape to Task 3, pairing to Tasks 3 and 7, the `<datetime>` scoping regression to Task 7, options to Task 4, fetching to Task 2, compression to Task 1, failure isolation to Tasks 1 and 3, bounding untrusted input to Task 1, restore to Task 9, the primary-flag rule to Task 9, computer resolution to Task 9, the shared ceiling to Task 1, and the ARB work to Task 10.

**One thing the spec did not anticipate,** found while reading the code for this plan and now Task 8: `saveComputerReading` adopts a dive's unattributed profile series only when the inserted row is the dive's sole source. Writing N rows in a loop defeats that guard, because the first insert adopts before the second row exists. The spec should be read as amended by Task 8.

**Types to keep consistent across tasks:** `DiveSourceExport.ordinal` is an `int` and pairs with the `ordinal` attribute written as a string in Task 3 and parsed back to `int` in Task 7. `encodedById` is `Map<String, String?>` keyed by `DiveSourceExport.id`, not by dive id. `dataSourcesByDiveRef` is keyed by the `dive_<id>` ref string, not the bare dive id.
