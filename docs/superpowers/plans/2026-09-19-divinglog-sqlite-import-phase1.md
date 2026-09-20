# Diving Log / DiveLogDT SQLite Import, Phase 1, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import a Diving Log 5.0 / DiveLogDT SQLite logbook so a migrating diver keeps their dives, profiles, tanks, weights, sites and buddies instead of the bare profiles DL7 delivers.

**Architecture:** A schema-probing reader turns the file's bytes into typed rows, a pure codec decodes the fixed-width packed sample columns, and a mapper turns those rows into an `ImportPayload` using the reference keys in `payload_ref_keys.dart`. The reader knows SQLite and nothing about Submersion; the mapper knows Submersion and never opens a database. This mirrors the existing `MacDiveDbReader` / `MacDiveDiveMapper` / `MacDiveSqliteParser` trio exactly.

**Tech Stack:** Dart, Flutter, `package:sqlite3` ^3.5.1, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-19-divinglog-sqlite-import-design.md`

## Global Constraints

- Issue link: a phase 1 PR body must say `Refs #2187`. Only the phase 2 PR says `Closes #2187`. The "PR Issue Link" check blocks the merge otherwise.
- Branch: `ericgriffin/github-issue-2144-5c6603`. Run every command from this branch's own worktree, never from the main checkout.
- No em-dash characters (U+2014) in any file, commit message, or PR text. No en-dash as sentence punctuation. No double hyphen or spaced hyphen used as prose punctuation.
- No tool or vendor name, attribution line, co-author trailer, or session link in any commit message, PR body, review reply, comment, or file.
- No emojis in code, comments, or documentation.
- Immutability: never mutate an object or list in place. Build new ones.
- File size: 200 to 400 lines typical, 800 maximum.
- Run `dart format .` after completing any task, before committing.
- Every non-error `ImportWarning` MUST carry a `code`. The constructor asserts this. Use `ImportWarningCode.diagnostic` for one that should be recorded without being shown.
- The database is metric. `Logbook` scalar columns are plain metric (metres, minutes, Celsius, kilograms, litres, bar). Only the packed profile columns are fixed-point. Do not apply a profile divisor to a `Logbook` column.
- Anything displayed must respect the active diver's unit settings. This code stores metric and never formats for display, so no formatting belongs in it.

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/features/universal_import/data/services/divinglog_raw_types.dart` | Immutable typed rows: `DivingLogRawDive`, `DivingLogRawTank`, `DivingLogRawSample`, `DivingLogLogbook`, `DivingLogCapabilities`. No logic. |
| Create `lib/features/universal_import/data/services/divinglog_profile_codec.dart` | Pure decode of the five packed sample columns into `List<DivingLogRawSample>`. No I/O. |
| Create `lib/features/universal_import/data/services/divinglog_db_reader.dart` | Temp file, read-only open, `sqlite_master` and `pragma table_info` probe, per-table reads, returns `DivingLogLogbook`. |
| Create `lib/features/universal_import/data/services/divinglog_dive_mapper.dart` | `DivingLogLogbook` to `ImportPayload`. |
| Create `lib/features/universal_import/data/parsers/divinglog_sqlite_parser.dart` | `ImportParser` implementation, orchestration and error handling. |
| Modify `lib/features/universal_import/data/models/import_enums.dart` | Add `ImportFormat.divingLogSqlite`, its display name, `isSupported`, a `SourceOverrideOption`, and `SourceApp.divingLog.exportInstructions`. |
| Modify `lib/features/universal_import/data/parsers/parser_registry.dart` | Route the new format. |
| Modify `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Add the `DivingLogDbReader.matchesTables` branch to `_detectFormat`. |

Tests mirror each source file under `test/features/universal_import/...`.

---

### Task 1: Typed rows and the schema probe

**Files:**
- Create: `lib/features/universal_import/data/services/divinglog_raw_types.dart`
- Create: `lib/features/universal_import/data/services/divinglog_db_reader.dart`
- Test: `test/features/universal_import/data/services/divinglog_db_reader_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `DivingLogCapabilities({required Set<String> tables, required Map<String, Set<String>> columns})` with `bool hasTable(String)` and `bool hasColumn(String table, String column)`; `DivingLogDbReader.matchesTables(Set<String> tables) -> bool`; `DivingLogDbReader.probeCapabilities(Database db) -> DivingLogCapabilities`.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/services/divinglog_db_reader_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_db_reader.dart';

/// Builds a Diving Log shaped database on disk and returns its bytes.
/// `extraLogbookColumns` false drops the optional columns so the
/// degradation path can be exercised.
Uint8List buildDivingLogBytes({
  bool withTankTable = true,
  bool extraLogbookColumns = true,
}) {
  final dir = Directory.systemTemp.createTempSync('dl_test');
  final path = '${dir.path}/logbook.sql';
  final db = sqlite3.open(path);
  final optional = extraLogbookColumns
      ? ', Divemaster TEXT, Visibility INTEGER, SupplyType TEXT, '
            'Divesuit TEXT, Computer TEXT'
      : '';
  db.execute('''
CREATE TABLE Logbook (
  ID INTEGER PRIMARY KEY, UUID TEXT, Number INTEGER,
  Divedate TEXT, Entrytime TEXT,
  Country TEXT, City TEXT, Place TEXT,
  Buddy TEXT, Comments TEXT,
  Depth REAL, Divetime INTEGER,
  Airtemp REAL, Watertemp REAL, Weight REAL,
  ProfileInt INTEGER, Profile TEXT, Profile2 TEXT,
  Profile3 TEXT, Profile4 TEXT, Profile5 TEXT,
  TankSize REAL, PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER$optional
)''');
  db.execute('CREATE TABLE DeletedRecords (UUID TEXT)');
  if (withTankTable) {
    db.execute('''
CREATE TABLE Tank (
  LogID INTEGER, TankID INTEGER, TankSize REAL,
  PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER
)''');
  }
  db.close();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}

void main() {
  group('DivingLogDbReader.matchesTables', () {
    test('accepts a Diving Log table set', () {
      expect(
        DivingLogDbReader.matchesTables({'Logbook', 'DeletedRecords', 'Tank'}),
        isTrue,
      );
    });

    test('accepts a logbook without the optional Tank table', () {
      expect(DivingLogDbReader.matchesTables({'Logbook'}), isTrue);
    });

    test('rejects a MacDive table set', () {
      expect(
        DivingLogDbReader.matchesTables({
          'ZDIVE',
          'ZDIVESITE',
          'ZGAS',
          'ZTANKANDGAS',
        }),
        isFalse,
      );
    });

    test('rejects a Shearwater table set', () {
      expect(
        DivingLogDbReader.matchesTables({'dive_details', 'log_data'}),
        isFalse,
      );
    });
  });

  group('DivingLogDbReader.isDivingLogDb', () {
    test('accepts a Diving Log shaped file', () async {
      expect(
        await DivingLogDbReader.isDivingLogDb(buildDivingLogBytes()),
        isTrue,
      );
    });

    test('returns false for non-SQLite bytes without throwing', () async {
      final bytes = Uint8List.fromList('not a database'.codeUnits);
      expect(await DivingLogDbReader.isDivingLogDb(bytes), isFalse);
    });
  });

  group('capabilities', () {
    test('reports the Tank table missing when it is absent', () async {
      final caps = await DivingLogDbReader.readCapabilities(
        buildDivingLogBytes(withTankTable: false),
      );
      expect(caps.hasTable('Logbook'), isTrue);
      expect(caps.hasTable('Tank'), isFalse);
    });

    test('reports optional Logbook columns missing when they are absent',
        () async {
      final caps = await DivingLogDbReader.readCapabilities(
        buildDivingLogBytes(extraLogbookColumns: false),
      );
      expect(caps.hasColumn('Logbook', 'Depth'), isTrue);
      expect(caps.hasColumn('Logbook', 'Divemaster'), isFalse);
    });
  });
}
```

Add `import 'dart:typed_data';` at the top of that file as well.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_db_reader_test.dart
```

Expected: FAIL, the target library does not exist yet.

- [ ] **Step 3: Write the raw types**

Create `lib/features/universal_import/data/services/divinglog_raw_types.dart`:

```dart
/// Which tables and columns a particular Diving Log file actually has.
///
/// Diving Log 5.0, Diving Log 6.0 and DiveLogDT have drifted apart, so
/// every query is narrowed to columns this reports. A missing table skips
/// one entity, a missing column reads as null, and neither aborts the
/// import.
class DivingLogCapabilities {
  final Set<String> tables;
  final Map<String, Set<String>> columns;

  const DivingLogCapabilities({required this.tables, required this.columns});

  bool hasTable(String table) => tables.contains(table);

  bool hasColumn(String table, String column) =>
      columns[table]?.contains(column) ?? false;

  /// The subset of [wanted] that this file actually has, in the given
  /// order, so a SELECT can be built from it directly.
  List<String> availableColumns(String table, List<String> wanted) => [
    for (final c in wanted)
      if (hasColumn(table, c)) c,
  ];

  /// The subset of [wanted] this file lacks, for the diagnostic warning.
  List<String> missingColumns(String table, List<String> wanted) => [
    for (final c in wanted)
      if (!hasColumn(table, c)) c,
  ];
}
```

- [ ] **Step 4: Write the reader's probe half**

Create `lib/features/universal_import/data/services/divinglog_db_reader.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Reads a Diving Log 5.0 / DiveLogDT SQLite logbook.
///
/// Mirrors the [MacDiveDbReader] pattern: writes the input bytes to a temp
/// file, opens read-only, queries, and deletes the temp file on exit. Safe
/// for concurrent calls (each invocation uses a unique microsecond-suffixed
/// temp path).
///
/// Unlike the MacDive reader this probes the schema before querying.
/// DiveLogDT on macOS and iOS and Diving Log on Windows share a format but
/// have drifted, so a hard-coded column list would throw on a file we have
/// never seen. See the design doc for the reasoning.
class DivingLogDbReader {
  /// `Logbook` alone identifies the format. `Tank` and `DeletedRecords` are
  /// optional: an old or trimmed logbook may have neither, and requiring
  /// them would reject files we can read perfectly well.
  static const _requiredTables = ['Logbook'];

  /// Synchronous companion to [isDivingLogDb] for callers that have already
  /// probed the SQLite table set, matching [MacDiveDbReader.matchesTables].
  ///
  /// Guards against claiming another flavour's file: MacDive and Shearwater
  /// are checked first at the call site, but a Core Data export could in
  /// principle carry a `Logbook` table, so those markers are excluded here
  /// too.
  static bool matchesTables(Set<String> tables) {
    const foreignMarkers = ['ZDIVE', 'dive_details'];
    if (foreignMarkers.any(tables.contains)) return false;
    return _requiredTables.every(tables.contains);
  }

  /// True when [bytes] is a SQLite database shaped like a Diving Log
  /// logbook. Returns false (does not throw) for non-SQLite input.
  static Future<bool> isDivingLogDb(Uint8List bytes) async {
    try {
      final caps = await readCapabilities(bytes);
      return matchesTables(caps.tables);
    } catch (_) {
      return false;
    }
  }

  /// Opens [bytes] and reports which tables and columns exist.
  static Future<DivingLogCapabilities> readCapabilities(
    Uint8List bytes,
  ) async {
    return _withDb(bytes, probeCapabilities);
  }

  /// Probes an already-open [db]. Split out so reads that already hold a
  /// handle do not reopen the file.
  static DivingLogCapabilities probeCapabilities(Database db) {
    final tableRows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final tables = tableRows.map<String>((r) => r['name'] as String).toSet();

    final columns = <String, Set<String>>{};
    for (final table in tables) {
      try {
        final info = db.select('PRAGMA table_info("$table")');
        columns[table] = info.map<String>((r) => r['name'] as String).toSet();
      } catch (_) {
        columns[table] = const <String>{};
      }
    }
    return DivingLogCapabilities(tables: tables, columns: columns);
  }

  /// Writes [bytes] to a temp file, opens read-only, runs [body], and
  /// always deletes the temp file.
  static Future<T> _withDb<T>(
    Uint8List bytes,
    T Function(Database db) body,
  ) async {
    final tmpFile = File(_tmpPath());
    try {
      await tmpFile.writeAsBytes(bytes);
      final db = sqlite3.open(tmpFile.path, mode: OpenMode.readOnly);
      try {
        return body(db);
      } finally {
        db.close();
      }
    } finally {
      _deleteTempFile(tmpFile);
    }
  }

  static String _tmpPath() =>
      '${Directory.systemTemp.path}/divinglog_import_'
      '${DateTime.now().microsecondsSinceEpoch}.sqlite';

  static void _deleteTempFile(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_db_reader_test.dart
```

Expected: PASS, all eight tests.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_raw_types.dart lib/features/universal_import/data/services/divinglog_db_reader.dart test/features/universal_import/data/services/divinglog_db_reader_test.dart
git commit -m "feat(import): probe the schema of a Diving Log SQLite logbook

Refs #2187. DiveLogDT and Diving Log share a format but have drifted, so
the reader discovers which tables and columns a file actually has instead
of hard-coding a column list that would throw on an unseen schema."
```

---

### Task 2: The packed profile codec

**Files:**
- Modify: `lib/features/universal_import/data/services/divinglog_raw_types.dart`
- Create: `lib/features/universal_import/data/services/divinglog_profile_codec.dart`
- Test: `test/features/universal_import/data/services/divinglog_profile_codec_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `DivingLogRawSample` with fields `timeSeconds`, `depthMeters`, `inDeco`, `ascentWarning`, `temperatureCelsius`, `pressureBar`, `tankId`, `rbtSeconds`, `heartRate`, `ndlSeconds`, `ttsSeconds`, `stopDepthMeters`, `ppO2Cell1/2/3`, `otu`, `cns`, `setpoint`; and `DivingLogProfileCodec.decode({required int intervalSeconds, String? profile, String? profile2, String? profile3, String? profile4, String? profile5}) -> List<DivingLogRawSample>`.

This is the highest-risk code in the phase. The two worked examples below come from the format's own documentation and are real vectors, not invented ones. Do not change them.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/services/divinglog_profile_codec_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_profile_codec.dart';

void main() {
  group('DivingLogProfileCodec.decode', () {
    test('decodes the documented Profile example', () {
      // 004500010000: 4.5 m, not in deco, ascending too fast.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500010000',
      );
      expect(samples, hasLength(1));
      expect(samples.single.timeSeconds, 0);
      expect(samples.single.depthMeters, closeTo(4.5, 1e-9));
      expect(samples.single.inDeco, isFalse);
      expect(samples.single.ascentWarning, isTrue);
    });

    test('decodes the documented Profile2 example', () {
      // 25518051099: 25.5 C, 180.5 bar, tank 1, 99 min RBT.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500010000',
        profile2: '25518051099',
      );
      final s = samples.single;
      expect(s.temperatureCelsius, closeTo(25.5, 1e-9));
      expect(s.pressureBar, closeTo(180.5, 1e-9));
      expect(s.tankId, 1);
      expect(s.rbtSeconds, 99 * 60);
    });

    test('spaces samples by the recording interval', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 30,
        profile: '004500010000' '010000000000' '015000000000',
      );
      expect(samples.map((s) => s.timeSeconds), [0, 30, 60]);
      expect(samples[1].depthMeters, closeTo(10.0, 1e-9));
      expect(samples[2].depthMeters, closeTo(15.0, 1e-9));
    });

    test('tolerates a short Profile2 that runs out before Profile', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500010000' '010000000000',
        profile2: '25518051099',
      );
      expect(samples, hasLength(2));
      expect(samples[0].temperatureCelsius, closeTo(25.5, 1e-9));
      expect(samples[1].temperatureCelsius, isNull);
    });

    test('reads deco, stop depth and tts from Profile and Profile4', () {
      // Profile flags deco at index 5; Profile4 is NNNSSSDDD.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '030001000000',
        profile4: '012003006',
      );
      final s = samples.single;
      expect(s.inDeco, isTrue);
      expect(s.ttsSeconds, 12 * 60);
      expect(s.ndlSeconds, isNull);
      expect(s.stopDepthMeters, closeTo(6.0, 1e-9));
    });

    test('reads ndl from Profile4 when not in deco', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '030000000000',
        profile4: '025000000',
      );
      expect(samples.single.ndlSeconds, 25 * 60);
      expect(samples.single.ttsSeconds, isNull);
    });

    test('decodes the documented Profile5 example', () {
      // 1121131141548026411: 1.12/1.13/1.14 bar, OTU 154.8, CNS 26.4,
      // setpoint 1.1.
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500000000',
        profile5: '1121131141548026411',
      );
      final s = samples.single;
      expect(s.ppO2Cell1, closeTo(1.12, 1e-9));
      expect(s.ppO2Cell2, closeTo(1.13, 1e-9));
      expect(s.ppO2Cell3, closeTo(1.14, 1e-9));
      expect(s.otu, closeTo(154.8, 1e-9));
      expect(s.cns, closeTo(26.4, 1e-9));
      expect(s.setpoint, closeTo(1.1, 1e-9));
    });

    test('reads heart rate from Profile3', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500000000',
        profile3: '00000000072000',
      );
      expect(samples.single.heartRate, 72);
    });

    test('returns no samples for a null or empty profile', () {
      expect(DivingLogProfileCodec.decode(intervalSeconds: 20), isEmpty);
      expect(
        DivingLogProfileCodec.decode(intervalSeconds: 20, profile: ''),
        isEmpty,
      );
    });

    test('ignores a trailing partial record', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 20,
        profile: '004500000000' '0100',
      );
      expect(samples, hasLength(1));
    });

    test('falls back to a one second interval when the interval is zero', () {
      final samples = DivingLogProfileCodec.decode(
        intervalSeconds: 0,
        profile: '004500000000' '010000000000',
      );
      expect(samples.map((s) => s.timeSeconds), [0, 1]);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_profile_codec_test.dart
```

Expected: FAIL, `divinglog_profile_codec.dart` does not exist.

- [ ] **Step 3: Add the sample type**

Append to `lib/features/universal_import/data/services/divinglog_raw_types.dart`:

```dart
/// One decoded profile sample. Every field beyond time and depth is
/// optional because the five packed columns are independently present.
class DivingLogRawSample {
  final int timeSeconds;
  final double depthMeters;
  final bool inDeco;
  final bool ascentWarning;
  final double? temperatureCelsius;
  final double? pressureBar;
  final int? tankId;
  final int? rbtSeconds;
  final int? heartRate;
  final int? ndlSeconds;
  final int? ttsSeconds;
  final double? stopDepthMeters;
  final double? ppO2Cell1;
  final double? ppO2Cell2;
  final double? ppO2Cell3;
  final double? otu;
  final double? cns;
  final double? setpoint;

  const DivingLogRawSample({
    required this.timeSeconds,
    required this.depthMeters,
    this.inDeco = false,
    this.ascentWarning = false,
    this.temperatureCelsius,
    this.pressureBar,
    this.tankId,
    this.rbtSeconds,
    this.heartRate,
    this.ndlSeconds,
    this.ttsSeconds,
    this.stopDepthMeters,
    this.ppO2Cell1,
    this.ppO2Cell2,
    this.ppO2Cell3,
    this.otu,
    this.cns,
    this.setpoint,
  });
}
```

- [ ] **Step 4: Write the codec**

Create `lib/features/universal_import/data/services/divinglog_profile_codec.dart`:

```dart
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Decodes Diving Log's packed sample columns.
///
/// Samples are fixed-width ASCII, one stride per sample, spread across five
/// parallel columns. Each column is consumed with its own cursor because
/// they are independently optional and can run out at different points: a
/// dive logged without air integration has `Profile` but no `Profile2`.
///
/// Field layouts, with the divisors these strides imply:
///
/// - [profile], stride 12, `DDDDDCRASWEE`: depth in centimetres (5), deco
///   flag (1), RBT warning, ascent warning, decostop ignored, work warning,
///   two characters of computer-specific extra.
/// - [profile2], stride 11, `TTTFFFFIRRR`: temperature in tenths of a
///   degree Celsius (3), tank pressure in tenths of a bar (4), tank id (1),
///   remaining bottom time in minutes (3).
/// - [profile3], stride 14: heart rate at offset 8, width 3.
/// - [profile4], stride 9: no-decompression limit in minutes, or time to
///   surface when in deco (3), stop time in minutes (3), stop depth in
///   metres (3).
/// - [profile5], stride 19, `AAABBBCCCOOOONNNNSS`: three measured ppO2
///   cells in hundredths of a bar, OTU in tenths, CNS in tenths of a
///   percent, setpoint in tenths of a bar.
///
/// Sample timestamps are the sample index times the recording interval.
class DivingLogProfileCodec {
  static const _strideProfile = 12;
  static const _strideProfile2 = 11;
  static const _strideProfile3 = 14;
  static const _strideProfile4 = 9;
  static const _strideProfile5 = 19;

  const DivingLogProfileCodec._();

  static List<DivingLogRawSample> decode({
    required int intervalSeconds,
    String? profile,
    String? profile2,
    String? profile3,
    String? profile4,
    String? profile5,
  }) {
    final p1 = profile ?? '';
    if (p1.length < _strideProfile) return const [];

    // A logbook row with a zero or negative interval still has ordered
    // samples; one second keeps them distinct and monotonic.
    final interval = intervalSeconds > 0 ? intervalSeconds : 1;

    final p2 = profile2 ?? '';
    final p3 = profile3 ?? '';
    final p4 = profile4 ?? '';
    final p5 = profile5 ?? '';

    final samples = <DivingLogRawSample>[];
    var index = 0;
    var o1 = 0;

    while (o1 + _strideProfile <= p1.length) {
      final o2 = index * _strideProfile2;
      final o3 = index * _strideProfile3;
      final o4 = index * _strideProfile4;
      final o5 = index * _strideProfile5;

      final hasP2 = o2 + _strideProfile2 <= p2.length;
      final hasP3 = o3 + _strideProfile3 <= p3.length;
      final hasP4 = o4 + _strideProfile4 <= p4.length;
      final hasP5 = o5 + _strideProfile5 <= p5.length;

      final inDeco = _digit(p1, o1 + 5) == 1;
      final ndlOrTts = hasP4 ? _int(p4, o4, 3) : null;

      samples.add(
        DivingLogRawSample(
          timeSeconds: index * interval,
          depthMeters: (_int(p1, o1, 5) ?? 0) / 100.0,
          inDeco: inDeco,
          ascentWarning: _digit(p1, o1 + 7) == 1,
          temperatureCelsius: hasP2 ? _scaled(p2, o2, 3, 10.0) : null,
          pressureBar: hasP2 ? _scaled(p2, o2 + 3, 4, 10.0) : null,
          tankId: hasP2 ? _int(p2, o2 + 7, 1) : null,
          rbtSeconds: hasP2 ? _minutes(_int(p2, o2 + 8, 3)) : null,
          heartRate: hasP3 ? _int(p3, o3 + 8, 3) : null,
          ndlSeconds: inDeco ? null : _minutes(ndlOrTts),
          ttsSeconds: inDeco ? _minutes(ndlOrTts) : null,
          stopDepthMeters: hasP4 ? _int(p4, o4 + 6, 3)?.toDouble() : null,
          ppO2Cell1: hasP5 ? _scaled(p5, o5, 3, 100.0) : null,
          ppO2Cell2: hasP5 ? _scaled(p5, o5 + 3, 3, 100.0) : null,
          ppO2Cell3: hasP5 ? _scaled(p5, o5 + 6, 3, 100.0) : null,
          otu: hasP5 ? _scaled(p5, o5 + 9, 4, 10.0) : null,
          cns: hasP5 ? _scaled(p5, o5 + 13, 4, 10.0) : null,
          setpoint: hasP5 ? _scaled(p5, o5 + 17, 2, 10.0) : null,
        ),
      );

      index++;
      o1 += _strideProfile;
    }
    return samples;
  }

  /// Reads [width] characters at [offset] as an integer, or null when the
  /// span is not entirely digits (real files pad with spaces).
  static int? _int(String s, int offset, int width) {
    if (offset + width > s.length) return null;
    return int.tryParse(s.substring(offset, offset + width).trim());
  }

  static double? _scaled(String s, int offset, int width, double divisor) {
    final raw = _int(s, offset, width);
    return raw == null ? null : raw / divisor;
  }

  static int? _digit(String s, int offset) => _int(s, offset, 1);

  /// A zero here means "not recorded" rather than "zero minutes", which is
  /// why it collapses to null instead of Duration.zero.
  static int? _minutes(int? value) =>
      value == null || value == 0 ? null : value * 60;
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_profile_codec_test.dart
```

Expected: PASS, all eleven tests.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_raw_types.dart lib/features/universal_import/data/services/divinglog_profile_codec.dart test/features/universal_import/data/services/divinglog_profile_codec_test.dart
git commit -m "feat(import): decode Diving Log packed profile columns

Refs #2187. Samples are fixed-width ASCII across five parallel columns,
each consumed with its own cursor because they are independently optional.
Tested against the two worked examples in the format documentation."
```

---

### Task 3: Read dive rows and tanks

**Files:**
- Modify: `lib/features/universal_import/data/services/divinglog_raw_types.dart`
- Modify: `lib/features/universal_import/data/services/divinglog_db_reader.dart`
- Modify: `test/features/universal_import/data/services/divinglog_db_reader_test.dart`

**Interfaces:**
- Consumes: `DivingLogCapabilities` and `_withDb` from Task 1; `DivingLogProfileCodec.decode` and `DivingLogRawSample` from Task 2.
- Produces: `DivingLogRawDive`, `DivingLogRawTank`, `DivingLogLogbook({required List<DivingLogRawDive> dives, required DivingLogCapabilities capabilities, required List<String> missingColumnNotes})`, and `DivingLogDbReader.readAll(Uint8List bytes) -> Future<DivingLogLogbook>`.

- [ ] **Step 1: Write the failing test**

Append these groups to `test/features/universal_import/data/services/divinglog_db_reader_test.dart`, inside `main()`. They need a helper that inserts rows, so add it beside `buildDivingLogBytes`:

```dart
/// Inserts one dive, optionally tombstoned, optionally with Tank rows.
Uint8List buildDivingLogWithRows({
  bool tombstoneTheDive = false,
  bool withTankRows = false,
}) {
  final dir = Directory.systemTemp.createTempSync('dl_rows');
  final path = '${dir.path}/logbook.sql';
  final db = sqlite3.open(path);
  db.execute('''
CREATE TABLE Logbook (
  ID INTEGER PRIMARY KEY, UUID TEXT, Number INTEGER,
  Divedate TEXT, Entrytime TEXT,
  Country TEXT, City TEXT, Place TEXT,
  Buddy TEXT, Divemaster TEXT, Comments TEXT,
  Depth REAL, Divetime INTEGER,
  Airtemp REAL, Watertemp REAL, Weight REAL,
  Divesuit TEXT, Computer TEXT, Visibility INTEGER, SupplyType TEXT,
  ProfileInt INTEGER, Profile TEXT, Profile2 TEXT,
  Profile3 TEXT, Profile4 TEXT, Profile5 TEXT,
  TankSize REAL, PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER
)''');
  db.execute('CREATE TABLE DeletedRecords (UUID TEXT)');
  db.execute('''
CREATE TABLE Tank (
  LogID INTEGER, TankID INTEGER, TankSize REAL,
  PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER
)''');
  db.execute('''
INSERT INTO Logbook VALUES (
  1, 'uuid-1', 42, '2024-06-01', '09:30',
  'Bonaire', 'Kralendijk', 'Salt Pier',
  'Alice, Bob', 'Carol', 'lovely dive',
  18.5, 47, 29.0, 27.0, 5.0,
  '3mm shorty', 'Perdix', 1, 'Nitrox',
  20, '004500000000', '25518051099', NULL, NULL, NULL,
  11.1, 210.0, 70.0, 232.0, 32.0, 0.0, 0
)''');
  if (tombstoneTheDive) {
    db.execute("INSERT INTO DeletedRecords VALUES ('uuid-1')");
  }
  if (withTankRows) {
    db.execute(
      'INSERT INTO Tank VALUES (1, 0, 11.1, 210.0, 70.0, 232.0, 32.0, 0.0, 0)',
    );
    db.execute(
      'INSERT INTO Tank VALUES (1, 1, 7.0, 200.0, 180.0, 232.0, 50.0, 0.0, 1)',
    );
  }
  db.close();
  final bytes = File(path).readAsBytesSync();
  dir.deleteSync(recursive: true);
  return bytes;
}
```

and the tests:

```dart
  group('DivingLogDbReader.readAll', () {
    test('reads a dive row with its scalar columns in source units',
        () async {
      final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
      expect(book.dives, hasLength(1));
      final d = book.dives.single;
      expect(d.id, 1);
      expect(d.uuid, 'uuid-1');
      expect(d.number, 42);
      expect(d.diveDate, '2024-06-01');
      expect(d.entryTime, '09:30');
      expect(d.country, 'Bonaire');
      expect(d.city, 'Kralendijk');
      expect(d.place, 'Salt Pier');
      expect(d.buddy, 'Alice, Bob');
      expect(d.divemaster, 'Carol');
      expect(d.comments, 'lovely dive');
      // Logbook.Depth is metres, not the profile's centimetres.
      expect(d.depthMeters, closeTo(18.5, 1e-9));
      expect(d.diveTimeMinutes, 47);
      expect(d.airTempCelsius, closeTo(29.0, 1e-9));
      expect(d.waterTempCelsius, closeTo(27.0, 1e-9));
      expect(d.weightKg, closeTo(5.0, 1e-9));
      expect(d.divesuit, '3mm shorty');
      expect(d.computer, 'Perdix');
      expect(d.visibilityCode, 1);
      expect(d.supplyType, 'Nitrox');
    });

    test('decodes the dive profile through the codec', () async {
      final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
      final samples = book.dives.single.samples;
      expect(samples, hasLength(1));
      expect(samples.single.depthMeters, closeTo(4.5, 1e-9));
      expect(samples.single.temperatureCelsius, closeTo(25.5, 1e-9));
    });

    test('excludes dives listed in DeletedRecords', () async {
      final book = await DivingLogDbReader.readAll(
        buildDivingLogWithRows(tombstoneTheDive: true),
      );
      expect(book.dives, isEmpty);
    });

    test('falls back to the Logbook cylinder when Tank has no rows',
        () async {
      final book = await DivingLogDbReader.readAll(buildDivingLogWithRows());
      final tanks = book.dives.single.tanks;
      expect(tanks, hasLength(1));
      expect(tanks.single.tankId, 0);
      expect(tanks.single.sizeLiters, closeTo(11.1, 1e-9));
      expect(tanks.single.startPressureBar, closeTo(210.0, 1e-9));
      expect(tanks.single.endPressureBar, closeTo(70.0, 1e-9));
      expect(tanks.single.workingPressureBar, closeTo(232.0, 1e-9));
      expect(tanks.single.o2Percent, closeTo(32.0, 1e-9));
      expect(tanks.single.isDouble, isFalse);
    });

    test('prefers Tank rows over the Logbook cylinder, ordered by TankID',
        () async {
      final book = await DivingLogDbReader.readAll(
        buildDivingLogWithRows(withTankRows: true),
      );
      final tanks = book.dives.single.tanks;
      expect(tanks, hasLength(2));
      expect(tanks.map((t) => t.tankId), [0, 1]);
      expect(tanks[1].o2Percent, closeTo(50.0, 1e-9));
      expect(tanks[1].isDouble, isTrue);
    });

    test('records missing optional columns as notes rather than throwing',
        () async {
      final book = await DivingLogDbReader.readAll(
        buildDivingLogBytes(extraLogbookColumns: false),
      );
      expect(book.dives, isEmpty);
      expect(book.missingColumnNotes.join(' '), contains('Divemaster'));
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_db_reader_test.dart
```

Expected: FAIL, `readAll` is not defined.

- [ ] **Step 3: Add the row types**

Append to `lib/features/universal_import/data/services/divinglog_raw_types.dart`:

```dart
/// One cylinder, from the `Tank` table or the `Logbook` cylinder columns.
class DivingLogRawTank {
  final int tankId;
  final double? sizeLiters;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? workingPressureBar;
  final double? o2Percent;
  final double? hePercent;

  /// `DblTank` set means a twinset and [sizeLiters] is per cylinder, so the
  /// imported volume doubles.
  final bool isDouble;

  const DivingLogRawTank({
    required this.tankId,
    this.sizeLiters,
    this.startPressureBar,
    this.endPressureBar,
    this.workingPressureBar,
    this.o2Percent,
    this.hePercent,
    this.isDouble = false,
  });
}

/// One `Logbook` row with its cylinders and decoded samples.
///
/// Field units are the source's, not Submersion's: metres, minutes,
/// degrees Celsius, kilograms, litres, bar. The mapper converts.
class DivingLogRawDive {
  final int id;
  final String? uuid;
  final int? number;
  final String? diveDate;
  final String? entryTime;
  final String? country;
  final String? city;
  final String? place;
  final String? buddy;
  final String? divemaster;
  final String? comments;
  final double? depthMeters;
  final int? diveTimeMinutes;
  final double? airTempCelsius;
  final double? waterTempCelsius;
  final double? weightKg;
  final String? divesuit;
  final String? computer;

  /// Diving Log's visibility code: 1 good, 2 medium, 3 bad. 0 and null mean
  /// unset.
  final int? visibilityCode;
  final String? supplyType;
  final List<DivingLogRawTank> tanks;
  final List<DivingLogRawSample> samples;

  const DivingLogRawDive({
    required this.id,
    this.uuid,
    this.number,
    this.diveDate,
    this.entryTime,
    this.country,
    this.city,
    this.place,
    this.buddy,
    this.divemaster,
    this.comments,
    this.depthMeters,
    this.diveTimeMinutes,
    this.airTempCelsius,
    this.waterTempCelsius,
    this.weightKg,
    this.divesuit,
    this.computer,
    this.visibilityCode,
    this.supplyType,
    this.tanks = const [],
    this.samples = const [],
  });
}

/// Everything read from one Diving Log file.
class DivingLogLogbook {
  final List<DivingLogRawDive> dives;
  final DivingLogCapabilities capabilities;

  /// Human-readable notes about columns this file lacked, recorded once per
  /// import as a diagnostic rather than shown per dive.
  final List<String> missingColumnNotes;

  const DivingLogLogbook({
    required this.dives,
    required this.capabilities,
    this.missingColumnNotes = const [],
  });
}
```

- [ ] **Step 4: Implement readAll**

Add to `DivingLogDbReader` in `divinglog_db_reader.dart`, and add the import of `divinglog_profile_codec.dart`:

```dart
  /// Every `Logbook` column phase 1 wants. Any the file lacks is dropped
  /// from the SELECT and read as null.
  static const _logbookColumns = [
    'ID', 'UUID', 'Number', 'Divedate', 'Entrytime',
    'Country', 'City', 'Place', 'Buddy', 'Divemaster', 'Comments',
    'Depth', 'Divetime', 'Airtemp', 'Watertemp', 'Weight',
    'Divesuit', 'Computer', 'Visibility', 'SupplyType',
    'ProfileInt', 'Profile', 'Profile2', 'Profile3', 'Profile4', 'Profile5',
    'TankSize', 'PresS', 'PresE', 'PresW', 'O2', 'He', 'DblTank',
  ];

  static const _tankColumns = [
    'LogID', 'TankID', 'TankSize', 'PresS', 'PresE', 'PresW',
    'O2', 'He', 'DblTank',
  ];

  /// Reads every dive, its cylinders and its decoded profile.
  ///
  /// Throws [FormatException] when there is no `Logbook` table, which the
  /// parser turns into a fatal import warning. Everything else degrades.
  static Future<DivingLogLogbook> readAll(Uint8List bytes) async {
    return _withDb(bytes, (db) {
      final caps = probeCapabilities(db);
      if (!caps.hasTable('Logbook')) {
        throw const FormatException('No Logbook table');
      }

      final notes = <String>[];
      final missing = caps.missingColumns('Logbook', _logbookColumns);
      if (missing.isNotEmpty) {
        notes.add('Logbook is missing: ${missing.join(', ')}');
      }

      final tombstones = _readTombstones(db, caps);
      final tanksByLogId = _readTanks(db, caps);
      final available = caps.availableColumns('Logbook', _logbookColumns);
      final quoted = available.map((c) => '"$c"').join(', ');
      final rows = db.select('SELECT $quoted FROM Logbook');

      final dives = <DivingLogRawDive>[];
      for (final row in rows) {
        final uuid = _str(row, 'UUID');
        if (uuid != null && tombstones.contains(uuid)) continue;
        final id = _int(row, 'ID');
        if (id == null) continue;

        final inline = _inlineTank(row);
        dives.add(
          DivingLogRawDive(
            id: id,
            uuid: uuid,
            number: _int(row, 'Number'),
            diveDate: _str(row, 'Divedate'),
            entryTime: _str(row, 'Entrytime'),
            country: _str(row, 'Country'),
            city: _str(row, 'City'),
            place: _str(row, 'Place'),
            buddy: _str(row, 'Buddy'),
            divemaster: _str(row, 'Divemaster'),
            comments: _str(row, 'Comments'),
            depthMeters: _double(row, 'Depth'),
            diveTimeMinutes: _int(row, 'Divetime'),
            airTempCelsius: _double(row, 'Airtemp'),
            waterTempCelsius: _double(row, 'Watertemp'),
            weightKg: _double(row, 'Weight'),
            divesuit: _str(row, 'Divesuit'),
            computer: _str(row, 'Computer'),
            visibilityCode: _int(row, 'Visibility'),
            supplyType: _str(row, 'SupplyType'),
            tanks: tanksByLogId[id] ?? (inline == null ? const [] : [inline]),
            samples: DivingLogProfileCodec.decode(
              intervalSeconds: _int(row, 'ProfileInt') ?? 0,
              profile: _str(row, 'Profile'),
              profile2: _str(row, 'Profile2'),
              profile3: _str(row, 'Profile3'),
              profile4: _str(row, 'Profile4'),
              profile5: _str(row, 'Profile5'),
            ),
          ),
        );
      }

      return DivingLogLogbook(
        dives: dives,
        capabilities: caps,
        missingColumnNotes: notes,
      );
    });
  }

  static Set<String> _readTombstones(
    Database db,
    DivingLogCapabilities caps,
  ) {
    if (!caps.hasTable('DeletedRecords') ||
        !caps.hasColumn('DeletedRecords', 'UUID')) {
      return const {};
    }
    final rows = db.select('SELECT UUID FROM DeletedRecords');
    return {
      for (final r in rows)
        if (_str(r, 'UUID') case final String u) u,
    };
  }

  static Map<int, List<DivingLogRawTank>> _readTanks(
    Database db,
    DivingLogCapabilities caps,
  ) {
    if (!caps.hasTable('Tank') || !caps.hasColumn('Tank', 'LogID')) {
      return const {};
    }
    final available = caps.availableColumns('Tank', _tankColumns);
    final quoted = available.map((c) => '"$c"').join(', ');
    final order = caps.hasColumn('Tank', 'TankID') ? ' ORDER BY TankID' : '';
    final rows = db.select('SELECT $quoted FROM Tank$order');

    final out = <int, List<DivingLogRawTank>>{};
    for (final row in rows) {
      final logId = _int(row, 'LogID');
      if (logId == null) continue;
      out[logId] = [
        ...?out[logId],
        DivingLogRawTank(
          tankId: _int(row, 'TankID') ?? out[logId]?.length ?? 0,
          sizeLiters: _double(row, 'TankSize'),
          startPressureBar: _double(row, 'PresS'),
          endPressureBar: _double(row, 'PresE'),
          workingPressureBar: _double(row, 'PresW'),
          o2Percent: _double(row, 'O2'),
          hePercent: _double(row, 'He'),
          isDouble: (_int(row, 'DblTank') ?? 0) > 0,
        ),
      ];
    }
    return out;
  }

  /// The cylinder carried on the `Logbook` row itself, used when the `Tank`
  /// table is absent or holds no row for this dive. Null when the row has
  /// no cylinder data at all, so a dive without gas does not gain an empty
  /// tank.
  static DivingLogRawTank? _inlineTank(Row row) {
    final size = _double(row, 'TankSize');
    final start = _double(row, 'PresS');
    final end = _double(row, 'PresE');
    final o2 = _double(row, 'O2');
    if (size == null && start == null && end == null && o2 == null) {
      return null;
    }
    return DivingLogRawTank(
      tankId: 0,
      sizeLiters: size,
      startPressureBar: start,
      endPressureBar: end,
      workingPressureBar: _double(row, 'PresW'),
      o2Percent: o2,
      hePercent: _double(row, 'He'),
      isDouble: (_int(row, 'DblTank') ?? 0) > 0,
    );
  }

  /// Reads a column that the SELECT may not have included at all, so a
  /// missing column and a null value are the same thing to callers.
  static Object? _cell(Row row, String column) {
    try {
      return row[column];
    } catch (_) {
      return null;
    }
  }

  static String? _str(Row row, String column) {
    final v = _cell(row, column);
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(Row row, String column) {
    final v = _cell(row, column);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return v == null ? null : int.tryParse(v.toString().trim());
  }

  static double? _double(Row row, String column) {
    final v = _cell(row, column);
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return v == null ? null : double.tryParse(v.toString().trim());
  }
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_db_reader_test.dart
```

Expected: PASS, all fourteen tests.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_raw_types.dart lib/features/universal_import/data/services/divinglog_db_reader.dart test/features/universal_import/data/services/divinglog_db_reader_test.dart
git commit -m "feat(import): read Diving Log dives, cylinders and profiles

Refs #2187. Dives listed in DeletedRecords are skipped so tombstoned
records do not reappear on import. The Tank table supplies cylinders when
present, otherwise the Logbook row's own cylinder columns do."
```

---

### Task 4: Map the logbook onto an import payload

**Files:**
- Create: `lib/features/universal_import/data/services/divinglog_dive_mapper.dart`
- Test: `test/features/universal_import/data/services/divinglog_dive_mapper_test.dart`

**Interfaces:**
- Consumes: `DivingLogLogbook`, `DivingLogRawDive`, `DivingLogRawTank`, `DivingLogRawSample` from Task 3.
- Produces: `DivingLogDiveMapper.toPayload(DivingLogLogbook logbook) -> ImportPayload`.

Reference keys come from `payload_ref_keys.dart` and must be spelled exactly: `buddyRefs`, `diveGuideRefs`, `tagRefs`, and a nested `site` map holding `uddfId`. Do not invent new keys.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/services/divinglog_dive_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_dive_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

DivingLogRawDive dive({
  int id = 1,
  String? uuid = 'uuid-1',
  String? place = 'Salt Pier',
  String? city = 'Kralendijk',
  String? country = 'Bonaire',
  String? buddy,
  String? divemaster,
  String? divesuit,
  String? comments,
  double? weightKg,
  int? visibilityCode,
  String? supplyType,
  List<DivingLogRawTank> tanks = const [],
  List<DivingLogRawSample> samples = const [],
}) => DivingLogRawDive(
  id: id,
  uuid: uuid,
  number: 42,
  diveDate: '2024-06-01',
  entryTime: '09:30',
  country: country,
  city: city,
  place: place,
  buddy: buddy,
  divemaster: divemaster,
  comments: comments,
  depthMeters: 18.5,
  diveTimeMinutes: 47,
  airTempCelsius: 29.0,
  waterTempCelsius: 27.0,
  weightKg: weightKg,
  divesuit: divesuit,
  computer: 'Perdix',
  visibilityCode: visibilityCode,
  supplyType: supplyType,
  tanks: tanks,
  samples: samples,
);

DivingLogLogbook book(List<DivingLogRawDive> dives) => DivingLogLogbook(
  dives: dives,
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
);

void main() {
  group('DivingLogDiveMapper.toPayload', () {
    test('maps the core dive fields', () {
      final payload = DivingLogDiveMapper.toPayload(book([dive()]));
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['dateTime'], DateTime.utc(2024, 6, 1, 9, 30));
      expect(d['diveNumber'], 42);
      expect(d['maxDepth'], closeTo(18.5, 1e-9));
      expect(d['duration'], const Duration(minutes: 47));
      expect(d['airTemp'], closeTo(29.0, 1e-9));
      expect(d['waterTemp'], closeTo(27.0, 1e-9));
      expect(d['diveComputerModel'], 'Perdix');
      expect(d['sourceUuid'], 'uuid-1');
    });

    test('skips a dive with no readable date', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          DivingLogRawDive(id: 1, diveDate: null),
        ]),
      );
      expect(payload.entitiesOf(ImportEntityType.dives), isEmpty);
      expect(
        payload.warnings.where(
          (w) => w.code == ImportWarningCode.divesSkipped,
        ),
        hasLength(1),
      );
    });

    test('defaults a missing entry time to midnight', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          DivingLogRawDive(id: 1, diveDate: '2024-06-01', entryTime: null),
        ]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['dateTime'], DateTime.utc(2024, 6, 1));
    });

    test('collapses repeated dives at one place to a single site', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(id: 1), dive(id: 2, uuid: 'uuid-2')]),
      );
      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites, hasLength(1));
      expect(sites.single['name'], 'Salt Pier');
      expect(sites.single['country'], 'Bonaire');
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives.every((d) => d['site']['uddfId'] == sites.single['uddfId']),
          isTrue);
    });

    test('keeps two different places apart', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(id: 1), dive(id: 2, uuid: 'u2', place: 'Karpata')]),
      );
      expect(payload.entitiesOf(ImportEntityType.sites), hasLength(2));
    });

    test('splits the buddy column and puts the divemaster in diveGuideRefs',
        () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(buddy: 'Alice, Bob', divemaster: 'Carol')]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['buddyRefs'], ['Alice', 'Bob']);
      expect(d['diveGuideRefs'], ['Carol']);
      final buddies = payload
          .entitiesOf(ImportEntityType.buddies)
          .map((b) => b['name'])
          .toList();
      expect(buddies, containsAll(['Alice', 'Bob', 'Carol']));
      expect(buddies, hasLength(3));
    });

    test('does not duplicate a buddy who is also the divemaster', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(buddy: 'Carol', divemaster: 'Carol')]),
      );
      expect(payload.entitiesOf(ImportEntityType.buddies), hasLength(1));
    });

    test('maps weight to weightUsed in kilograms', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(weightKg: 5.0)]),
      );
      expect(
        payload.entitiesOf(ImportEntityType.dives).single['weightUsed'],
        closeTo(5.0, 1e-9),
      );
    });

    test('maps the visibility code onto the Visibility enum', () {
      for (final (code, expected) in [
        (1, 'good'),
        (2, 'moderate'),
        (3, 'poor'),
      ]) {
        final payload = DivingLogDiveMapper.toPayload(
          book([dive(visibilityCode: code)]),
        );
        expect(
          payload.entitiesOf(ImportEntityType.dives).single['visibility'],
          expected,
        );
      }
    });

    test('omits visibility for the unset code', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(visibilityCode: 0)]),
      );
      expect(
        payload.entitiesOf(ImportEntityType.dives).single
            .containsKey('visibility'),
        isFalse,
      );
    });

    test('puts the suit in notes rather than creating equipment', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(divesuit: '3mm shorty', comments: 'lovely dive')]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d['notes'], contains('lovely dive'));
      expect(d['notes'], contains('3mm shorty'));
      expect(payload.entitiesOf(ImportEntityType.equipment), isEmpty);
    });

    test('emits the supply type as a tag', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([dive(supplyType: 'Nitrox')]),
      );
      expect(
        payload.entitiesOf(ImportEntityType.dives).single['tagRefs'],
        ['Nitrox'],
      );
      expect(
        payload.entitiesOf(ImportEntityType.tags).single['name'],
        'Nitrox',
      );
    });

    test('doubles the volume of a twinset', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            tanks: const [
              DivingLogRawTank(tankId: 0, sizeLiters: 7.0, isDouble: true),
            ],
          ),
        ]),
      );
      final tanks =
          payload.entitiesOf(ImportEntityType.dives).single['tanks'] as List;
      expect(tanks.single['volume'], closeTo(14.0, 1e-9));
    });

    test('emits a gas switch when the profile tank id changes', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            tanks: const [
              DivingLogRawTank(tankId: 0, o2Percent: 32.0),
              DivingLogRawTank(tankId: 1, o2Percent: 50.0),
            ],
            samples: const [
              DivingLogRawSample(
                timeSeconds: 0,
                depthMeters: 20.0,
                tankId: 0,
              ),
              DivingLogRawSample(
                timeSeconds: 20,
                depthMeters: 18.0,
                tankId: 0,
              ),
              DivingLogRawSample(
                timeSeconds: 40,
                depthMeters: 6.0,
                tankId: 1,
              ),
            ],
          ),
        ]),
      );
      final switches = payload
          .entitiesOf(ImportEntityType.dives)
          .single['gasSwitches'] as List;
      expect(switches, hasLength(1));
      expect(switches.single['timestamp'], 40);
      expect(switches.single['tankRef'], 'divinglog:1');
    });

    test('emits no gas switch when the tank never changes', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            tanks: const [DivingLogRawTank(tankId: 0, o2Percent: 32.0)],
            samples: const [
              DivingLogRawSample(
                timeSeconds: 0,
                depthMeters: 20.0,
                tankId: 0,
              ),
              DivingLogRawSample(
                timeSeconds: 20,
                depthMeters: 18.0,
                tankId: 0,
              ),
            ],
          ),
        ]),
      );
      final d = payload.entitiesOf(ImportEntityType.dives).single;
      expect(d.containsKey('gasSwitches'), isFalse);
    });

    test('maps profile samples and raises one OTU warning per file', () {
      final payload = DivingLogDiveMapper.toPayload(
        book([
          dive(
            samples: const [
              DivingLogRawSample(
                timeSeconds: 0,
                depthMeters: 4.5,
                temperatureCelsius: 25.5,
                otu: 154.8,
                cns: 26.4,
              ),
              DivingLogRawSample(
                timeSeconds: 20,
                depthMeters: 9.0,
                otu: 160.0,
              ),
            ],
          ),
        ]),
      );
      final profile =
          payload.entitiesOf(ImportEntityType.dives).single['profile'] as List;
      expect(profile, hasLength(2));
      expect(profile.first['timestamp'], 0);
      expect(profile.first['depth'], closeTo(4.5, 1e-9));
      expect(profile.first['temperature'], closeTo(25.5, 1e-9));
      expect(profile.first['cns'], closeTo(26.4, 1e-9));
      expect(profile.first.containsKey('otu'), isFalse);
      expect(
        payload.warnings
            .where((w) => w.message.toLowerCase().contains('otu'))
            .length,
        1,
      );
    });
  });
}
```

Add `import 'package:submersion/features/universal_import/data/models/import_warning.dart';` to that test file.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/services/divinglog_dive_mapper_test.dart
```

Expected: FAIL, `divinglog_dive_mapper.dart` does not exist.

- [ ] **Step 3: Write the mapper**

Create `lib/features/universal_import/data/services/divinglog_dive_mapper.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Turns a [DivingLogLogbook] into an [ImportPayload].
///
/// Reference keys (`buddyRefs`, `diveGuideRefs`, `tagRefs`, the nested
/// `site` map) are the ones registered in `payload_ref_keys.dart`, so
/// `PayloadMerger` and `PayloadDiverExpander` resolve them without any new
/// plumbing here.
class DivingLogDiveMapper {
  const DivingLogDiveMapper._();

  static ImportPayload toPayload(DivingLogLogbook logbook) {
    final warnings = <ImportWarning>[];
    final dives = <Map<String, dynamic>>[];
    final sitesByKey = <String, Map<String, dynamic>>{};
    final buddiesByName = <String, Map<String, dynamic>>{};
    final tagsByName = <String, Map<String, dynamic>>{};
    var sawOtu = false;

    for (var i = 0; i < logbook.dives.length; i++) {
      final raw = logbook.dives[i];
      final start = _startTime(raw);
      if (start == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            code: ImportWarningCode.divesSkipped,
            message: 'Skipped dive ${i + 1}: no readable date',
            entityType: ImportEntityType.dives,
            itemIndex: i,
          ),
        );
        continue;
      }

      final map = <String, dynamic>{'dateTime': start};
      if (raw.uuid != null) map['sourceUuid'] = raw.uuid;
      if (raw.number != null) map['diveNumber'] = raw.number;
      if (raw.depthMeters != null) map['maxDepth'] = raw.depthMeters;
      if (raw.diveTimeMinutes != null) {
        map['duration'] = Duration(minutes: raw.diveTimeMinutes!);
      }
      if (raw.airTempCelsius != null) map['airTemp'] = raw.airTempCelsius;
      if (raw.waterTempCelsius != null) {
        map['waterTemp'] = raw.waterTempCelsius;
      }
      if (raw.weightKg != null) map['weightUsed'] = raw.weightKg;
      if (raw.computer != null) map['diveComputerModel'] = raw.computer;

      final visibility = _visibility(raw.visibilityCode);
      if (visibility != null) map['visibility'] = visibility;

      // The suit goes to notes, not equipment. The CSV importer learned
      // that the gear path duplicates suits: the exposure_suit type plus a
      // name-and-type dedupe that never matches. Equipment arrives in phase
      // 2 from the equipment table, where it has real identity.
      final notes = [
        if (raw.comments != null) raw.comments!,
        if (raw.divesuit != null) 'Suit: ${raw.divesuit}',
      ].join('\n\n');
      if (notes.isNotEmpty) map['notes'] = notes;

      final siteKey = _siteKey(raw);
      if (siteKey != null) {
        sitesByKey.putIfAbsent(siteKey, () {
          final site = <String, dynamic>{
            'uddfId': siteKey,
            'name': raw.place ?? raw.city ?? raw.country!,
          };
          if (raw.country != null) site['country'] = raw.country;
          if (raw.city != null) site['region'] = raw.city;
          return site;
        });
        map['site'] = <String, dynamic>{'uddfId': siteKey};
      }

      final buddyNames = _names(raw.buddy);
      final guideNames = _names(raw.divemaster);
      for (final name in [...buddyNames, ...guideNames]) {
        buddiesByName.putIfAbsent(
          name.toLowerCase(),
          () => <String, dynamic>{'name': name, 'uddfId': name},
        );
      }
      if (buddyNames.isNotEmpty) map['buddyRefs'] = buddyNames;
      if (guideNames.isNotEmpty) map['diveGuideRefs'] = guideNames;

      if (raw.supplyType != null) {
        final tag = raw.supplyType!;
        tagsByName.putIfAbsent(
          tag.toLowerCase(),
          () => <String, dynamic>{'name': tag, 'uddfId': tag},
        );
        map['tagRefs'] = [tag];
      }

      // Built before the profile because the gas-switch builder resolves
      // its tankRef against these.
      final tanks = _tanks(raw.tanks);
      if (tanks.isNotEmpty) map['tanks'] = tanks;

      final profile = _profile(raw.samples);
      if (profile.isNotEmpty) map['profile'] = profile;
      final switches = _gasSwitches(raw.samples, tanks);
      if (switches.isNotEmpty) map['gasSwitches'] = switches;
      if (raw.samples.any((s) => s.otu != null)) sawOtu = true;

      dives.add(map);
    }

    if (sawOtu) {
      warnings.add(
        const ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.diagnostic,
          message:
              'Per-sample OTU was present in the file but Submersion has no '
              'field for it, so it was not imported.',
        ),
      );
    }
    for (final note in logbook.missingColumnNotes) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.info,
          code: ImportWarningCode.diagnostic,
          message: note,
        ),
      );
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (dives.isNotEmpty) entities[ImportEntityType.dives] = dives;
    if (sitesByKey.isNotEmpty) {
      entities[ImportEntityType.sites] = sitesByKey.values.toList();
    }
    if (buddiesByName.isNotEmpty) {
      entities[ImportEntityType.buddies] = buddiesByName.values.toList();
    }
    if (tagsByName.isNotEmpty) {
      entities[ImportEntityType.tags] = tagsByName.values.toList();
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: const {'source': 'divinglog_sqlite'},
    );
  }

  /// `Divedate` is `YYYY-MM-DD` and `Entrytime` is `HH:MM`. Dive times are
  /// wall clocks stored UTC-flagged, per the house convention.
  static DateTime? _startTime(DivingLogRawDive raw) {
    final date = raw.diveDate;
    if (date == null) return null;
    final dateDigits = date.replaceAll(RegExp(r'[^0-9]'), '');
    if (dateDigits.length < 8) return null;
    final year = int.tryParse(dateDigits.substring(0, 4));
    final month = int.tryParse(dateDigits.substring(4, 6));
    final day = int.tryParse(dateDigits.substring(6, 8));
    if (year == null || month == null || day == null) return null;

    var hour = 0;
    var minute = 0;
    final time = raw.entryTime;
    if (time != null) {
      final timeDigits = time.replaceAll(RegExp(r'[^0-9]'), '');
      if (timeDigits.length >= 4) {
        hour = int.tryParse(timeDigits.substring(0, 2)) ?? 0;
        minute = int.tryParse(timeDigits.substring(2, 4)) ?? 0;
      }
    }
    return DateTime.utc(year, month, day, hour, minute);
  }

  /// Keyed on the whole country/city/place triple so 500 dives at a handful
  /// of places collapse to a handful of sites.
  static String? _siteKey(DivingLogRawDive raw) {
    final parts = [
      raw.country,
      raw.city,
      raw.place,
    ].whereType<String>().toList();
    if (parts.isEmpty) return null;
    return 'divinglog_site_${parts.join('|').toLowerCase()}';
  }

  /// Diving Log stores several buddies in one free-text column.
  static List<String> _names(String? raw) {
    if (raw == null) return const [];
    return [
      for (final part in raw.split(RegExp(r'[,;/]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// 1 good, 2 medium, 3 bad. 0 and null mean unset.
  static String? _visibility(int? code) => switch (code) {
    1 => 'good',
    2 => 'moderate',
    3 => 'poor',
    _ => null,
  };

  static List<Map<String, dynamic>> _tanks(List<DivingLogRawTank> tanks) => [
    for (var i = 0; i < tanks.length; i++)
      <String, dynamic>{
        'order': i,
        'uddfTankId': 'divinglog:${tanks[i].tankId}',
        'gasMix': GasMix(
          o2: tanks[i].o2Percent ?? 21.0,
          he: tanks[i].hePercent ?? 0.0,
        ),
        if (tanks[i].sizeLiters != null)
          'volume': tanks[i].isDouble
              ? tanks[i].sizeLiters! * 2
              : tanks[i].sizeLiters,
        if (tanks[i].startPressureBar != null)
          'startPressure': tanks[i].startPressureBar,
        if (tanks[i].endPressureBar != null)
          'endPressure': tanks[i].endPressureBar,
        if (tanks[i].workingPressureBar != null)
          'workingPressure': tanks[i].workingPressureBar,
      },
  ];

  /// A change in the profile's tank id is the only gas-switch signal the
  /// format has; there is no event table. The first sample establishes the
  /// starting cylinder rather than counting as a switch.
  static List<Map<String, dynamic>> _gasSwitches(
    List<DivingLogRawSample> samples,
    List<Map<String, dynamic>> tanks,
  ) {
    if (samples.isEmpty || tanks.isEmpty) return const [];
    final switches = <Map<String, dynamic>>[];
    int? currentTankId;
    for (final s in samples) {
      final tankId = s.tankId;
      if (tankId == null) continue;
      if (currentTankId != null && tankId != currentTankId) {
        final ref = tanks.firstWhere(
          (t) => t['uddfTankId'] == 'divinglog:$tankId',
          orElse: () => const <String, dynamic>{},
        );
        if (ref['uddfTankId'] case final String id) {
          switches.add(<String, dynamic>{
            'timestamp': s.timeSeconds,
            'tankRef': id,
          });
        }
      }
      currentTankId = tankId;
    }
    return switches;
  }

  static List<Map<String, dynamic>> _profile(
    List<DivingLogRawSample> samples,
  ) => [
    for (final s in samples)
      <String, dynamic>{
        'timestamp': s.timeSeconds,
        'depth': s.depthMeters,
        if (s.temperatureCelsius != null) 'temperature': s.temperatureCelsius,
        if (s.heartRate != null) 'heartRate': s.heartRate,
        if (s.cns != null) 'cns': s.cns,
        if (s.ndlSeconds != null) 'ndl': s.ndlSeconds,
        if (s.ttsSeconds != null) 'tts': s.ttsSeconds,
        if (s.rbtSeconds != null) 'rbt': s.rbtSeconds,
        if (s.stopDepthMeters != null) 'ceiling': s.stopDepthMeters,
        if (s.setpoint != null) 'setpoint': s.setpoint,
        if (s.ppO2Cell1 != null) 'o2Sensor1': s.ppO2Cell1,
        if (s.ppO2Cell2 != null) 'o2Sensor2': s.ppO2Cell2,
        if (s.ppO2Cell3 != null) 'o2Sensor3': s.ppO2Cell3,
        if (s.inDeco) 'decoType': 2,
        // Explicitly typed: the importer casts this with
        // `as List<Map<String, dynamic>>?`, and an inferred
        // `List<Map<String, Object>>` only survives that cast by
        // covariance. Spelling it out removes the dependence.
        if (s.pressureBar != null)
          'allTankPressures': <Map<String, dynamic>>[
            {'pressure': s.pressureBar, 'tankIndex': s.tankId ?? 0},
          ],
      },
  ];
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/services/divinglog_dive_mapper_test.dart
```

Expected: PASS, all sixteen tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/services/divinglog_dive_mapper.dart test/features/universal_import/data/services/divinglog_dive_mapper_test.dart
git commit -m "feat(import): map a Diving Log logbook onto an import payload

Refs #2187. Sites collapse on the country/city/place triple so a long
logbook yields a handful of sites rather than one per dive. The divemaster
lands in diveGuideRefs rather than being flattened into the buddy list,
and the suit goes to notes because the gear path duplicates suits."
```

---

### Task 5: Wire the parser into the import pipeline

**Files:**
- Create: `lib/features/universal_import/data/parsers/divinglog_sqlite_parser.dart`
- Modify: `lib/features/universal_import/data/models/import_enums.dart`
- Modify: `lib/features/universal_import/data/parsers/parser_registry.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`
- Test: `test/features/universal_import/data/parsers/divinglog_sqlite_parser_test.dart`

**Interfaces:**
- Consumes: `DivingLogDbReader.isDivingLogDb`, `DivingLogDbReader.readAll`, `DivingLogDiveMapper.toPayload`.
- Produces: `DivingLogSqliteParser` implementing `ImportParser`; `ImportFormat.divingLogSqlite`.

- [ ] **Step 1: Write the failing test**

Create `test/features/universal_import/data/parsers/divinglog_sqlite_parser_test.dart`. It reuses the fixture builder from the reader test, so copy `buildDivingLogWithRows` into this file verbatim (the engineer may be reading tasks out of order; do not import it across test files).

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/divinglog_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';

// (paste buildDivingLogWithRows from the reader test here)

void main() {
  group('DivingLogSqliteParser', () {
    test('parses a Diving Log file into dives and sites', () async {
      final payload = await const DivingLogSqliteParser().parse(
        buildDivingLogWithRows(),
      );
      expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
      expect(payload.entitiesOf(ImportEntityType.sites), hasLength(1));
      expect(payload.metadata['source'], 'divinglog_sqlite');
    });

    test('reports a non-SQLite file as an error with no entities', () async {
      final bytes = Uint8List.fromList('not a database'.codeUnits);
      final payload = await const DivingLogSqliteParser().parse(bytes);
      expect(payload.entities, isEmpty);
      expect(
        payload.warnings.any(
          (w) => w.severity == ImportWarningSeverity.error,
        ),
        isTrue,
      );
    });

    test('reports an empty file as an error', () async {
      final payload = await const DivingLogSqliteParser().parse(
        Uint8List(0),
      );
      expect(payload.entities, isEmpty);
      expect(
        payload.warnings.any(
          (w) => w.severity == ImportWarningSeverity.error,
        ),
        isTrue,
      );
    });

    test('is registered for its format', () {
      expect(
        parserForFormat(ImportFormat.divingLogSqlite),
        isA<DivingLogSqliteParser>(),
      );
    });

    test('the format is marked supported', () {
      expect(ImportFormat.divingLogSqlite.isSupported, isTrue);
      expect(ImportFormat.divingLogSqlite.displayName, 'Diving Log');
    });

    test('Diving Log has export instructions naming the logbook', () {
      final text = SourceApp.divingLog.exportInstructions;
      expect(text, isNotNull);
      expect(text!.toLowerCase(), contains('logbook'));
    });
  });
}
```

Add `import 'package:submersion/features/universal_import/data/models/import_warning.dart';` to that file.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/universal_import/data/parsers/divinglog_sqlite_parser_test.dart
```

Expected: FAIL, `ImportFormat.divingLogSqlite` is not defined.

- [ ] **Step 3: Add the enum members**

In `lib/features/universal_import/data/models/import_enums.dart`:

Add `divingLogSqlite,` to the `ImportFormat` enum, directly after `divingLogXml,`.

Add to the `displayName` switch, after the `divingLogXml` case if present, otherwise beside `macdiveSqlite`:

```dart
    divingLogSqlite => 'Diving Log',
```

Add `divingLogSqlite ||` to the `isSupported` switch's true branch, beside `macdiveSqlite ||`.

Replace the `divingLog` arm of `exportInstructions` (it currently has no arm and falls through to `_ => null`) by adding, before the `_ => null` line:

```dart
    divingLog =>
      'In Diving Log or DiveLogDT, export your logbook (the SQLite file, '
          'not DL7) and import it here. The DL7 export carries only depth '
          'and time, so sites, buddies, equipment, weights and trips are '
          'not in it.',
```

Add to `SourceOverrideOption.supported`, after the Diving Log CSV entry:

```dart
    SourceOverrideOption(
      sourceApp: SourceApp.divingLog,
      format: ImportFormat.divingLogSqlite,
      displayName: 'Diving Log (Logbook)',
    ),
```

- [ ] **Step 4: Write the parser**

Create `lib/features/universal_import/data/parsers/divinglog_sqlite_parser.dart`:

```dart
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_dive_mapper.dart';

/// Parses a Diving Log 5.0 / DiveLogDT SQLite logbook into an
/// [ImportPayload].
///
/// Orchestrates [DivingLogDbReader] to [DivingLogDiveMapper] with error
/// handling; the same shape as [MacDiveSqliteParser].
class DivingLogSqliteParser implements ImportParser {
  const DivingLogSqliteParser();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.divingLogSqlite,
  ];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    if (fileBytes.isEmpty) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Empty file',
          ),
        ],
      );
    }

    if (!await DivingLogDbReader.isDivingLogDb(fileBytes)) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'File is not a Diving Log SQLite logbook. Expected a '
                'Logbook table.',
          ),
        ],
      );
    }

    try {
      final logbook = await DivingLogDbReader.readAll(fileBytes);
      if (logbook.dives.isEmpty) {
        return const ImportPayload(
          entities: {},
          warnings: [
            ImportWarning(
              severity: ImportWarningSeverity.error,
              message: 'Diving Log logbook contains no dives.',
            ),
          ],
        );
      }
      return DivingLogDiveMapper.toPayload(logbook);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Failed to read Diving Log logbook: $e',
          ),
        ],
      );
    }
  }
}
```

- [ ] **Step 5: Register the parser**

In `lib/features/universal_import/data/parsers/parser_registry.dart`, add the import:

```dart
import 'package:submersion/features/universal_import/data/parsers/divinglog_sqlite_parser.dart';
```

and the switch arm, beside `macdiveSqlite`:

```dart
    ImportFormat.divingLogSqlite => const DivingLogSqliteParser(),
```

- [ ] **Step 6: Wire detection**

In `lib/features/universal_import/presentation/providers/universal_import_providers.dart`, add the import:

```dart
import 'package:submersion/features/universal_import/data/services/divinglog_db_reader.dart';
```

and extend the chain in `_detectFormat`, after the `MacDiveDbReader` branch. Diving Log is checked last because its marker table is a single common name, so the more specific flavours claim their files first:

```dart
      } else if (DivingLogDbReader.matchesTables(tables)) {
        detection = const DetectionResult(
          format: ImportFormat.divingLogSqlite,
          sourceApp: SourceApp.divingLog,
          confidence: 0.95,
        );
      }
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
flutter test test/features/universal_import/data/parsers/divinglog_sqlite_parser_test.dart
```

Expected: PASS, all six tests.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/features/universal_import/data/parsers/divinglog_sqlite_parser.dart lib/features/universal_import/data/parsers/parser_registry.dart lib/features/universal_import/data/models/import_enums.dart lib/features/universal_import/presentation/providers/universal_import_providers.dart test/features/universal_import/data/parsers/divinglog_sqlite_parser_test.dart
git commit -m "feat(import): recognise and import Diving Log SQLite logbooks

Refs #2187. Detection routes through _detectFormat, which probes the
table set once and asks each reader, with Diving Log checked last because
its marker table has a common name. Also replaces the Diving Log export
instructions, which previously pointed nobody anywhere."
```

---

### Task 6: Whole-project verification

**Files:** none created. This task proves the previous five did not break anything else.

**Interfaces:**
- Consumes: everything.
- Produces: a branch ready for a pull request.

- [ ] **Step 1: Format the whole project**

```bash
dart format .
```

Expected: any reformatted files are ones this branch touched. If it reformats files this branch did not touch, do not commit those.

- [ ] **Step 2: Analyze the whole project**

```bash
flutter analyze 2>&1 | tail -30
```

Expected: `No issues found!`. Infos are fatal in CI, so treat any info as a failure and fix it. Do not pipe this through `grep`, which masks the exit status.

- [ ] **Step 3: Run the architecture guard tests**

These scan all of `lib/`, so an affected-directory run never includes them and new files under `lib/` must be checked explicitly.

```bash
flutter test test/architecture
```

Expected: PASS.

- [ ] **Step 4: Run the full suite once**

```bash
flutter test
```

Expected: PASS. Run this once, not repeatedly, and do not overlap it with another local test run.

- [ ] **Step 5: Measure a realistic logbook**

The reporter has about 500 dives with profiles, and the spec requires this
be measured rather than assumed. Write this throwaway test, run it, record
the number in the PR body, then delete the file.

Create `test/features/universal_import/divinglog_scale_probe_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/features/universal_import/data/parsers/divinglog_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  test('imports 500 dives with hour-long profiles in reasonable time',
      () async {
    final dir = Directory.systemTemp.createTempSync('dl_scale');
    final path = '${dir.path}/logbook.sql';
    final db = sqlite3.open(path);
    db.execute('''
CREATE TABLE Logbook (
  ID INTEGER PRIMARY KEY, UUID TEXT, Number INTEGER,
  Divedate TEXT, Entrytime TEXT,
  Country TEXT, City TEXT, Place TEXT,
  Buddy TEXT, Divemaster TEXT, Comments TEXT,
  Depth REAL, Divetime INTEGER,
  Airtemp REAL, Watertemp REAL, Weight REAL,
  Divesuit TEXT, Computer TEXT, Visibility INTEGER, SupplyType TEXT,
  ProfileInt INTEGER, Profile TEXT, Profile2 TEXT,
  Profile3 TEXT, Profile4 TEXT, Profile5 TEXT,
  TankSize REAL, PresS REAL, PresE REAL, PresW REAL,
  O2 REAL, He REAL, DblTank INTEGER
)''');
    db.execute('CREATE TABLE DeletedRecords (UUID TEXT)');

    // One hour at 20 second samples is 180 samples per dive.
    final profile = StringBuffer();
    final profile2 = StringBuffer();
    for (var i = 0; i < 180; i++) {
      profile.write('0${(1000 + i).toString().padLeft(4, '0')}000000');
      profile2.write('25518050099');
    }
    for (var n = 1; n <= 500; n++) {
      db.execute(
        'INSERT INTO Logbook VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
        '?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          n, 'uuid-\$n', n, '2024-06-01', '09:30',
          'Bonaire', 'Kralendijk', 'Site \${n % 12}',
          'Alice, Bob', 'Carol', 'notes',
          18.5, 60, 29.0, 27.0, 5.0,
          '3mm', 'Perdix', 1, 'Nitrox',
          20, profile.toString(), profile2.toString(), null, null, null,
          11.1, 210.0, 70.0, 232.0, 32.0, 0.0, 0,
        ],
      );
    }
    db.close();
    final bytes = Uint8List.fromList(File(path).readAsBytesSync());

    final stopwatch = Stopwatch()..start();
    final payload = await const DivingLogSqliteParser().parse(bytes);
    stopwatch.stop();

    expect(payload.entitiesOf(ImportEntityType.dives), hasLength(500));
    // 12 distinct places, not 500.
    expect(payload.entitiesOf(ImportEntityType.sites), hasLength(12));
    // 3 people, not 1500.
    expect(payload.entitiesOf(ImportEntityType.buddies), hasLength(3));
    // ignore: avoid_print
    print('500 dives parsed in \${stopwatch.elapsedMilliseconds} ms');

    dir.deleteSync(recursive: true);
  });
}
```

```bash
flutter test test/features/universal_import/divinglog_scale_probe_test.dart
```

Expected: PASS, and the printed time is a few seconds at most. If it is not,
stop and report rather than shipping it. Then delete the file:

```bash
rm test/features/universal_import/divinglog_scale_probe_test.dart
```

This probe also proves the two collapse behaviours at a realistic size,
which is the thing most likely to be silently wrong: a mapper that keys
sites or buddies badly produces 500 sites and 1500 buddies, and a small
fixture will not show it.

- [ ] **Step 6: Commit any fixes**

```bash
dart format .
git add -u
git commit -m "chore(import): satisfy analyze and the architecture guards

Refs #2187."
```

Skip this step if steps 1 through 4 produced no changes.

- [ ] **Step 7: Push and open the pull request**

```bash
git push -u origin ericgriffin/github-issue-2144-5c6603
```

Then open the PR with this body, which must contain `Refs #2187` outside any code block or HTML comment, or the "PR Issue Link" check blocks the merge:

```
Refs #2187. Reported in discussion #2144.

Phase 1 of the Diving Log / DiveLogDT SQLite importer. A diver migrating
from DiveLogDT via DL7 loses every site, buddy, equipment item, weight,
tank and trip, because DL7 does not carry them. DiveLogDT's own logbook is
a SQLite database it exports directly, and it is the same format Diving Log
uses on Windows, so this importer serves both.

This phase brings across dives, profiles, tanks, weights, sites and
buddies from the `Logbook` and `Tank` tables. Equipment and trips need the
relational tables and land in phase 2, once a sample file is available to
map against, which is why this says Refs rather than Closes.

Design: `docs/superpowers/specs/2026-09-19-divinglog-sqlite-import-design.md`
```

Do not add any attribution line, co-author trailer, tool name, or session
link to the commit messages or the PR body.

---

## Notes for the executor

- The worktree is already initialized (submodules and `flutter pub get` have
  been run). If `flutter analyze` reports hundreds of errors about missing
  generated files, the worktree lost its codegen; re-initialize it rather
  than bypassing the pre-push hook.
- `flutter test` output piped through `grep` hides the exit status. Read the
  unpiped output.
- Nothing in this phase touches l10n, so no ARB files change and the
  generated-l10n staleness check has nothing to do. The export-instruction
  string added in Task 5 sits in an existing non-localized switch, matching
  every other entry in it.
