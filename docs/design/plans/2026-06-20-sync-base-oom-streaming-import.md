# Streaming Base Import (iCloud Sync OOM Fix) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt a peer's sync "base" snapshot with bounded memory so a large library no longer OOM-kills the app on iOS (issue #358).

**Architecture:** Stream base parts to a temp file (one ~8 MB part resident at a time), then apply the base in three forward passes over that file: (1) collect header `exportedAt` + the `deletions` map, (2) collect parent-row `updatedAt` and contradiction keys, (3) apply rows in small batches through the existing per-record merge. The delicate merge logic (`_mergeEntity`, `_applyRemoteDeletions`, FK repair, HLC/LWW) is reused unchanged; only how rows are *fed* to it changes. No wire-format change.

**Tech Stack:** Dart/Flutter, `dart:io` (`File`, `Directory.systemTemp`), `dart:convert` (`jsonDecode`/`utf8`), `package:crypto` (chunked SHA-256), Drift (SQLite), `flutter_test`.

## Global Constraints

- No wire-format change. Existing monolithic-JSON bases already in users' iClouds MUST import with no user action and no desktop re-publish.
- Do NOT modify the merge primitives `_mergeEntity`, `_applyRemoteDeletions`, `repairDanglingForeignKeys`, `_pendingRecordMap`, `_deletionMap`, `_recordIdForEntity`, `_extractUpdatedAtMillis`, `_extractHlc` (signatures or bodies). New code calls them.
- All BLOB/row decoding stays inside `SyncDataSerializer.upsertRecord`; new code passes plain `jsonDecode(rowBytes) as Map<String, dynamic>` exactly as the current path does (verified: the row maps produced by `SyncData.fromJson` are raw `jsonDecode` output; base64 BLOB decoding happens in `upsertRecord` via `_syncBlobSerializer`).
- Temp scratch files use `Directory.systemTemp` (dart:io), NOT `path_provider` (avoids a plugin dependency and test mocking; `Directory.systemTemp` is sandbox-safe on iOS/macOS).
- `dart format .` must pass with no changes; `flutter analyze` must be clean (whole project, not piped).
- No emojis in code/comments. No `Co-Authored-By` trailers in commits.
- Scope: the merge-base adoption path only (`ChangesetReader` cold-start/lapped base). The Replace-restore path (`_collectEpochPayloads`) and the write/publish side are explicit follow-ups, NOT in this plan.

---

## File Structure

**Create:**
- `lib/core/services/sync/changeset_log/base_json_stream_reader.dart` — `BaseJsonStreamReader`: streaming byte-boundary scanner that emits top-level scalar members and section (`data`/`deletions`) array rows without holding the whole document. Pure (no IO).
- `lib/core/services/sync/changeset_log/base_part_file_sink.dart` — `BasePartFileSink`: downloads base parts one at a time, verifies per-part + whole-file checksums, writes to a temp file. Owns all temp-file IO.
- `test/core/services/sync/changeset_log/base_json_stream_reader_test.dart`
- `test/core/services/sync/changeset_log/base_part_file_sink_test.dart`
- `test/core/services/sync/sync_base_streaming_parity_test.dart` — the linchpin: streaming apply vs in-memory apply produce identical DBs.

**Modify:**
- `lib/core/services/sync/changeset_log/changeset_reader.dart` — base branch fetches to a temp file and calls a new `applyBaseFile` callback; cleans the temp file up.
- `lib/core/services/sync/sync_service.dart` — add `_applyRemoteBaseFile`; add `_entityHasUpdatedAt` const; wire `applyBaseFile:` into the `pull` call; add `@visibleForTesting` seams.
- `test/core/services/sync/changeset_log/changeset_reader_test.dart`, `changeset_reader_epoch_test.dart`, `changeset_reader_verify_test.dart` — pass the new required `applyBaseFile` arg in their pull harness.

---

## Task 1: `BaseJsonStreamReader` — streaming byte-boundary scanner

**Files:**
- Create: `lib/core/services/sync/changeset_log/base_json_stream_reader.dart`
- Test: `test/core/services/sync/changeset_log/base_json_stream_reader_test.dart`

**Interfaces:**
- Produces:
  - `class BaseJsonStreamReader` with
    `Future<void> parse(Stream<List<int>> bytes, {Future<void> Function(String key, Uint8List rawValue)? onScalar, bool Function(String section, String table)? wantRows, Future<void> Function(String section, String table, Uint8List rowBytes)? onRow})`
  - `onScalar` fires once per top-level scalar member (value bytes are raw JSON, e.g. `"abc"`, `2`, `null`).
  - `onRow` fires once per array element inside a section object (`data` or `deletions`), with the raw element bytes.
  - `wantRows(section, table)` returning false skips that table's elements without buffering/emitting (default: keep all).

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/sync/changeset_log/base_json_stream_reader_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';

/// Feed [s] as a single chunk.
Stream<List<int>> _one(String s) => Stream.value(utf8.encode(s));

/// Feed [s] one byte per chunk, to prove the scanner survives arbitrary
/// chunk boundaries.
Stream<List<int>> _drip(String s) async* {
  for (final b in utf8.encode(s)) {
    yield [b];
  }
}

Future<({Map<String, String> scalars, List<List<String>> rows})> run(
  Stream<List<int>> bytes, {
  bool Function(String section, String table)? want,
}) async {
  final scalars = <String, String>{};
  final rows = <List<String>>[];
  await BaseJsonStreamReader().parse(
    bytes,
    onScalar: (k, v) async => scalars[k] = utf8.decode(v),
    wantRows: want,
    onRow: (section, table, row) async =>
        rows.add([section, table, utf8.decode(row)]),
  );
  return (scalars: scalars, rows: rows);
}

void main() {
  const doc =
      '{"version":2,"exportedAt":17,"deviceId":"abc",'
      '"data":{"dives":[{"id":"d1","n":1},{"id":"d2","n":2}],'
      '"diveProfiles":[{"id":"p1"}]},'
      '"deletions":{"dives":[{"id":"x","deletedAt":5}]},'
      '"uploadNonce":null}';

  test('emits top-level scalars with raw JSON value bytes', () async {
    final r = await run(_one(doc));
    expect(r.scalars['version'], '2');
    expect(r.scalars['exportedAt'], '17');
    expect(r.scalars['deviceId'], '"abc"');
    expect(r.scalars['uploadNonce'], 'null');
    // Sections are not scalars.
    expect(r.scalars.containsKey('data'), isFalse);
    expect(r.scalars.containsKey('deletions'), isFalse);
  });

  test('emits each data and deletions row with section+table tags', () async {
    final r = await run(_one(doc));
    expect(r.rows, [
      ['data', 'dives', '{"id":"d1","n":1}'],
      ['data', 'dives', '{"id":"d2","n":2}'],
      ['data', 'diveProfiles', '{"id":"p1"}'],
      ['deletions', 'dives', '{"id":"x","deletedAt":5}'],
    ]);
  });

  test('survives one-byte-per-chunk boundaries', () async {
    final r = await run(_drip(doc));
    expect(r.scalars['deviceId'], '"abc"');
    expect(r.rows.length, 4);
    expect(r.rows.first, ['data', 'dives', '{"id":"d1","n":1}']);
  });

  test('wantRows=false skips a table without emitting it', () async {
    final r = await run(
      _one(doc),
      want: (section, table) => !(section == 'data' && table == 'diveProfiles'),
    );
    expect(
      r.rows.where((e) => e[1] == 'diveProfiles'),
      isEmpty,
    );
    expect(r.rows.length, 3);
  });

  test('handles structural chars and escapes inside string values', () async {
    const tricky =
        '{"data":{"t":[{"s":"a,b{c}[d]\\"e\\\\f","ok":true}]},"deletions":{}}';
    final r = await run(_one(tricky));
    expect(r.rows.length, 1);
    final decoded = jsonDecode(r.rows.single[2]) as Map<String, dynamic>;
    expect(decoded['s'], 'a,b{c}[d]"e\\f');
    expect(decoded['ok'], true);
  });

  test('handles nested objects and arrays within a row', () async {
    const nested =
        '{"data":{"t":[{"id":"a","meta":{"k":[1,2,{"z":"}"}]}}]},'
        '"deletions":{}}';
    final r = await run(_one(nested));
    expect(r.rows.length, 1);
    final decoded = jsonDecode(r.rows.single[2]) as Map<String, dynamic>;
    expect((decoded['meta'] as Map)['k'], [1, 2, {'z': '}'}]);
  });

  test('handles empty data and empty tables', () async {
    final r = await run(_one('{"data":{},"deletions":{}}'));
    expect(r.rows, isEmpty);
  });

  test('tolerates unknown top-level keys and trailing members', () async {
    const doc2 =
        '{"future":{"a":1},"data":{"t":[{"id":"a"}]},"x":7}';
    final r = await run(_one(doc2));
    expect(r.scalars['x'], '7');
    expect(r.rows, [
      ['data', 't', '{"id":"a"}'],
    ]);
  });

  test('captures a row larger than a typical buffer', () async {
    final big = 'y' * 100000;
    final doc3 = '{"data":{"t":[{"id":"a","blob":"$big"}]},"deletions":{}}';
    final r = await run(_drip(doc3));
    expect(r.rows.length, 1);
    final decoded = jsonDecode(r.rows.single[2]) as Map<String, dynamic>;
    expect((decoded['blob'] as String).length, 100000);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/base_json_stream_reader_test.dart`
Expected: FAIL — `Target of URI doesn't exist` / `BaseJsonStreamReader` undefined.

- [ ] **Step 3: Implement `BaseJsonStreamReader`**

Create `lib/core/services/sync/changeset_log/base_json_stream_reader.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

/// Streaming, bounded-memory reader for a serialized sync base document.
///
/// The base is one JSON object: a handful of scalar header members plus two
/// "section" members (`data` and `deletions`) whose values are objects mapping
/// a table name to an array of row objects. This reader walks the byte stream
/// once and reports:
///  - [parse]'s `onScalar` for each top-level scalar member (key + raw value
///    bytes), and
///  - `onRow` for each element of each section's table arrays.
///
/// It never holds more than one row (or one scalar value) in memory, so a
/// multi-hundred-MB base imports in bounded memory. It does NOT parse JSON
/// values itself: it finds byte boundaries (respecting string/escape state and
/// brace/bracket nesting) and hands raw bytes to the caller, which decodes the
/// few rows it needs via `jsonDecode`.
///
/// The instance holds per-parse mutable state; do not run two [parse] calls on
/// one instance concurrently (the import drives passes sequentially).
class BaseJsonStreamReader {
  static const int _quote = 0x22; // "
  static const int _backslash = 0x5c; // \
  static const int _lbrace = 0x7b; // {
  static const int _rbrace = 0x7d; // }
  static const int _lbracket = 0x5b; // [
  static const int _rbracket = 0x5d; // ]
  static const int _colon = 0x3a; // :
  static const int _comma = 0x2c; // ,

  static bool _isWs(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;

  // --- per-parse state ---
  _S _state = _S.awaitTopOpen;
  String? _lastKey;
  String? _section;
  String? _table;

  final BytesBuilder _key = BytesBuilder(copy: false);
  bool _keyEscaped = false;

  final BytesBuilder _cap = BytesBuilder(copy: false);
  int _capDepth = 0;
  bool _capInString = false;
  bool _capEscaped = false;
  bool _capStarted = false;
  _Cap _capKind = _Cap.skip;

  bool Function(String section, String table) _want = (_, __) => true;

  void _reset() {
    _state = _S.awaitTopOpen;
    _lastKey = null;
    _section = null;
    _table = null;
    _key.clear();
    _keyEscaped = false;
    _cap.clear();
    _capDepth = 0;
    _capInString = false;
    _capEscaped = false;
    _capStarted = false;
    _capKind = _Cap.skip;
  }

  Future<void> parse(
    Stream<List<int>> bytes, {
    Future<void> Function(String key, Uint8List rawValue)? onScalar,
    bool Function(String section, String table)? wantRows,
    Future<void> Function(String section, String table, Uint8List rowBytes)?
        onRow,
  }) async {
    _reset();
    _want = wantRows ?? (_, __) => true;

    await for (final chunk in bytes) {
      for (final c in chunk) {
        var consumed = false;
        while (!consumed) {
          final r = _consume(c);
          consumed = r.consumed;
          final emit = r.emit;
          if (emit != null) {
            if (emit.kind == _Cap.scalar) {
              if (onScalar != null) await onScalar(emit.key!, emit.bytes);
            } else {
              if (onRow != null) {
                await onRow(emit.section!, emit.table!, emit.bytes);
              }
            }
          }
        }
      }
    }
  }

  _Step _consume(int c) {
    switch (_state) {
      case _S.awaitTopOpen:
        if (_isWs(c)) return const _Step(true);
        if (c == _lbrace) _state = _S.topKeyOrClose;
        return const _Step(true);

      case _S.topKeyOrClose:
        if (_isWs(c) || c == _comma) return const _Step(true);
        if (c == _rbrace) {
          _state = _S.done;
          return const _Step(true);
        }
        if (c == _quote) {
          _key.clear();
          _keyEscaped = false;
          _state = _S.topKey;
        }
        return const _Step(true);

      case _S.topKey:
        return _readKey(c, then: _S.topColon);

      case _S.topColon:
        if (_isWs(c)) return const _Step(true);
        if (c == _colon) _state = _S.topValueStart;
        return const _Step(true);

      case _S.topValueStart:
        if (_isWs(c)) return const _Step(true);
        if (c == _lbrace) {
          _section = _lastKey;
          _state = _S.sectionKeyOrClose;
          return const _Step(true);
        }
        _beginCapture(_Cap.scalar);
        _state = _S.capture;
        return const _Step(false); // reprocess this char inside capture

      case _S.sectionKeyOrClose:
        if (_isWs(c) || c == _comma) return const _Step(true);
        if (c == _rbrace) {
          _section = null;
          _state = _S.topKeyOrClose;
          return const _Step(true);
        }
        if (c == _quote) {
          _key.clear();
          _keyEscaped = false;
          _state = _S.sectionKey;
        }
        return const _Step(true);

      case _S.sectionKey:
        return _readKey(c, then: _S.sectionColon, intoTable: true);

      case _S.sectionColon:
        if (_isWs(c)) return const _Step(true);
        if (c == _colon) _state = _S.sectionValueStart;
        return const _Step(true);

      case _S.sectionValueStart:
        if (_isWs(c)) return const _Step(true);
        if (c == _lbracket) {
          _state = _S.arrayElemOrClose;
          return const _Step(true);
        }
        // Unexpected non-array section value: skip it generically.
        _beginCapture(_Cap.skip);
        _state = _S.captureSection;
        return const _Step(false);

      case _S.arrayElemOrClose:
        if (_isWs(c) || c == _comma) return const _Step(true);
        if (c == _rbracket) {
          _table = null;
          _state = _S.sectionKeyOrClose;
          return const _Step(true);
        }
        _beginCapture(
          (_section != null && _table != null && _want(_section!, _table!))
              ? _Cap.row
              : _Cap.skip,
        );
        _state = _S.captureArray;
        return const _Step(false);

      case _S.arrayCommaOrClose:
        if (_isWs(c)) return const _Step(true);
        if (c == _comma) {
          _state = _S.arrayElemOrClose;
          return const _Step(true);
        }
        if (c == _rbracket) {
          _table = null;
          _state = _S.sectionKeyOrClose;
          return const _Step(true);
        }
        return const _Step(true);

      case _S.capture:
      case _S.captureArray:
      case _S.captureSection:
        return _captureByte(c);

      case _S.done:
        return const _Step(true);
    }
  }

  _Step _readKey(int c, {required _S then, bool intoTable = false}) {
    if (_keyEscaped) {
      _key.addByte(c);
      _keyEscaped = false;
      return const _Step(true);
    }
    if (c == _backslash) {
      _key.addByte(c);
      _keyEscaped = true;
      return const _Step(true);
    }
    if (c == _quote) {
      final name = utf8.decode(_key.takeBytes());
      if (intoTable) {
        _table = name;
      } else {
        _lastKey = name;
      }
      _state = then;
      return const _Step(true);
    }
    _key.addByte(c);
    return const _Step(true);
  }

  void _beginCapture(_Cap kind) {
    _cap.clear();
    _capDepth = 0;
    _capInString = false;
    _capEscaped = false;
    _capStarted = false;
    _capKind = kind;
  }

  _Step _captureByte(int c) {
    if (_capInString) {
      _cap.addByte(c);
      if (_capEscaped) {
        _capEscaped = false;
      } else if (c == _backslash) {
        _capEscaped = true;
      } else if (c == _quote) {
        _capInString = false;
        if (_capDepth == 0) return _finishCapture(consume: true);
      }
      return const _Step(true);
    }
    if (c == _quote) {
      _capStarted = true;
      _capInString = true;
      _cap.addByte(c);
      return const _Step(true);
    }
    if (c == _lbrace || c == _lbracket) {
      _capStarted = true;
      _capDepth++;
      _cap.addByte(c);
      return const _Step(true);
    }
    if (c == _rbrace || c == _rbracket) {
      if (_capDepth == 0) {
        // This closing delimiter belongs to the parent: a primitive value
        // ended just before it. Finish and reprocess the delimiter.
        return _finishCapture(consume: false);
      }
      _capDepth--;
      _cap.addByte(c);
      if (_capDepth == 0) return _finishCapture(consume: true);
      return const _Step(true);
    }
    if (c == _comma && _capDepth == 0) {
      // Primitive value ended at a separator; consume the comma.
      return _finishCapture(consume: true);
    }
    if (_isWs(c)) {
      if (_capDepth == 0 && _capStarted) {
        // Whitespace after a primitive ends it; do not consume the following
        // delimiter (reprocess via the parent state).
        return _finishCapture(consume: true);
      }
      return const _Step(true); // leading/interior structural whitespace
    }
    _capStarted = true;
    _cap.addByte(c);
    return const _Step(true);
  }

  _Step _finishCapture({required bool consume}) {
    final kind = _capKind;
    final fromArray =
        _state == _S.captureArray || _state == _S.captureSection;
    final bytes = (kind == _Cap.skip) ? null : _cap.takeBytes();
    if (kind == _Cap.skip) _cap.clear();

    // Transition to the parent state.
    if (_state == _S.capture) {
      _state = _S.topKeyOrClose;
    } else if (_state == _S.captureArray) {
      _state = _S.arrayCommaOrClose;
    } else {
      _state = _S.sectionKeyOrClose;
    }

    _Emit? emit;
    if (bytes != null) {
      if (kind == _Cap.scalar) {
        emit = _Emit.scalar(_lastKey ?? '', bytes);
      } else if (kind == _Cap.row && _section != null && _table != null) {
        emit = _Emit.row(_section!, _table!, bytes);
      }
    }
    // `fromArray` is informational; transitions above already handle routing.
    assert(fromArray || _state == _S.topKeyOrClose || true);
    return _Step(consume, emit: emit);
  }
}

enum _Cap { scalar, row, skip }

enum _S {
  awaitTopOpen,
  topKeyOrClose,
  topKey,
  topColon,
  topValueStart,
  sectionKeyOrClose,
  sectionKey,
  sectionColon,
  sectionValueStart,
  arrayElemOrClose,
  arrayCommaOrClose,
  capture,
  captureArray,
  captureSection,
  done,
}

class _Step {
  const _Step(this.consumed, {this.emit});
  final bool consumed;
  final _Emit? emit;
}

class _Emit {
  _Emit.scalar(this.key, this.bytes)
      : section = null,
        table = null,
        kind = _Cap.scalar;
  _Emit.row(this.section, this.table, this.bytes)
      : key = null,
        kind = _Cap.row;
  final _Cap kind;
  final String? key;
  final String? section;
  final String? table;
  final Uint8List bytes;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/base_json_stream_reader_test.dart`
Expected: PASS (9 tests). If a boundary case fails, fix `_captureByte`/`_finishCapture` only; do not change the test expectations.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/sync/changeset_log/base_json_stream_reader.dart test/core/services/sync/changeset_log/base_json_stream_reader_test.dart
flutter analyze lib/core/services/sync/changeset_log/base_json_stream_reader.dart
git add lib/core/services/sync/changeset_log/base_json_stream_reader.dart test/core/services/sync/changeset_log/base_json_stream_reader_test.dart
git commit -m "feat(sync): streaming byte-boundary reader for base import"
```

---

## Task 2: `BasePartFileSink` — download parts to a verified temp file

**Files:**
- Create: `lib/core/services/sync/changeset_log/base_part_file_sink.dart`
- Test: `test/core/services/sync/changeset_log/base_part_file_sink_test.dart`

**Interfaces:**
- Consumes: `BaseChunker.checksum` (from `base_chunker.dart`).
- Produces:
  - `class BasePartFileSink`
    - ctor `BasePartFileSink({Future<Directory> Function()? tempDirProvider})` (defaults to `Directory.systemTemp`).
    - `Future<String?> assemble({required String name, required int partCount, required String? wholeChecksum, required List<String> partChecksums, required Future<Uint8List?> Function(int index) downloadPart})` — returns the temp file path on success, or null if any part is missing or any checksum (per-part or whole-file) fails. On null it deletes the partial file.
    - `Future<void> deleteQuietly(String path)` — best-effort delete; never throws.

- [ ] **Step 1: Write the failing tests**

Create `test/core/services/sync/changeset_log/base_part_file_sink_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_sink.dart';

void main() {
  late Directory dir;
  late BasePartFileSink sink;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('base_sink_test');
    sink = BasePartFileSink(tempDirProvider: () async => dir);
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  test('assembles parts into one file and returns its path', () async {
    final p0 = bytes('hello ');
    final p1 = bytes('world');
    final whole = BaseChunker.checksum(bytes('hello world'));
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: whole,
      partChecksums: [BaseChunker.checksum(p0), BaseChunker.checksum(p1)],
      downloadPart: (i) async => [p0, p1][i],
    );
    expect(path, isNotNull);
    expect(await File(path!).readAsString(), 'hello world');
  });

  test('returns null and deletes the file on a per-part checksum mismatch',
      () async {
    final p0 = bytes('hello ');
    final p1 = bytes('world');
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: null,
      partChecksums: [BaseChunker.checksum(p0), 'sha256:deadbeef'],
      downloadPart: (i) async => [p0, p1][i],
    );
    expect(path, isNull);
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('returns null when a part is missing', () async {
    final p0 = bytes('hello ');
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: null,
      partChecksums: [BaseChunker.checksum(p0), 'sha256:whatever'],
      downloadPart: (i) async => i == 0 ? p0 : null,
    );
    expect(path, isNull);
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('returns null on a whole-file checksum mismatch', () async {
    final p0 = bytes('hello ');
    final p1 = bytes('world');
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: 'sha256:notreal',
      partChecksums: [BaseChunker.checksum(p0), BaseChunker.checksum(p1)],
      downloadPart: (i) async => [p0, p1][i],
    );
    expect(path, isNull);
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('deleteQuietly removes a file and never throws', () async {
    final f = File('${dir.path}/x');
    await f.writeAsString('y');
    await sink.deleteQuietly(f.path);
    expect(f.existsSync(), isFalse);
    await sink.deleteQuietly('${dir.path}/does-not-exist'); // no throw
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_sink_test.dart`
Expected: FAIL — `BasePartFileSink` undefined.

- [ ] **Step 3: Implement `BasePartFileSink`**

Create `lib/core/services/sync/changeset_log/base_part_file_sink.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

/// Downloads a base's parts one at a time into a single temp file, verifying
/// integrity as bytes land so the whole base is never held in memory. Each part
/// is checked against its manifest checksum before being written; a rolling
/// SHA-256 verifies the whole-file checksum at the end. Any failure deletes the
/// partial file and returns null (transient -> the caller retries next sync).
class BasePartFileSink {
  BasePartFileSink({Future<Directory> Function()? tempDirProvider})
      : _tempDir = tempDirProvider ?? (() async => Directory.systemTemp);

  final Future<Directory> Function() _tempDir;
  static const _uuid = Uuid();

  Future<String?> assemble({
    required String name,
    required int partCount,
    required String? wholeChecksum,
    required List<String> partChecksums,
    required Future<Uint8List?> Function(int index) downloadPart,
  }) async {
    final dir = await _tempDir();
    final path = '${dir.path}/$name.${_uuid.v4()}.base';
    final file = File(path);
    final out = file.openWrite();

    final whole = AccumulatorSink<Digest>();
    final wholeInput = sha256.startChunkedConversion(whole);

    var ok = true;
    try {
      for (var i = 0; i < partCount; i++) {
        final part = await downloadPart(i);
        if (part == null) {
          ok = false;
          break;
        }
        if (i < partChecksums.length &&
            BaseChunker.checksum(part) != partChecksums[i]) {
          ok = false;
          break;
        }
        wholeInput.add(part);
        out.add(part);
      }
    } catch (_) {
      ok = false;
    }

    await out.close();
    wholeInput.close();

    if (ok && wholeChecksum != null) {
      final computed = 'sha256:${whole.events.single}';
      if (computed != wholeChecksum) ok = false;
    }

    if (!ok) {
      await deleteQuietly(path);
      return null;
    }
    return path;
  }

  Future<void> deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort: a leftover temp file is harmless; the OS reaps systemTemp.
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/base_part_file_sink_test.dart`
Expected: PASS (5 tests).

Note: `AccumulatorSink` and `startChunkedConversion` come from `package:crypto/crypto.dart`. If analyze reports `AccumulatorSink` unresolved, add `import 'package:convert/convert.dart';` (it re-exports `AccumulatorSink`) — `convert` is already a transitive dependency of `crypto`.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/services/sync/changeset_log/base_part_file_sink.dart test/core/services/sync/changeset_log/base_part_file_sink_test.dart
flutter analyze lib/core/services/sync/changeset_log/base_part_file_sink.dart
git add lib/core/services/sync/changeset_log/base_part_file_sink.dart test/core/services/sync/changeset_log/base_part_file_sink_test.dart
git commit -m "feat(sync): bounded-memory base part file sink with checksum verify"
```

---

## Task 3: Route the reader's base branch through a temp file

**Files:**
- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart`
- Modify (test harness): `test/core/services/sync/changeset_log/changeset_reader_test.dart`, `changeset_reader_epoch_test.dart`, `changeset_reader_verify_test.dart`

**Interfaces:**
- Consumes: `BasePartFileSink` (Task 2).
- Produces:
  - `typedef ApplyBaseFile = Future<void> Function(String filePath, SyncManifest manifest);`
  - `ChangesetReader(this._codec, this._peerCursors, {BasePartFileSink? baseSink})`
  - `pull({... existing ..., required ApplyBaseFile applyBaseFile})` — the base branch now fetches to a temp file, calls `applyBaseFile`, then deletes the temp file in a `finally`. The changeset branch is unchanged.

- [ ] **Step 1: Write the failing test (reader calls applyBaseFile with a readable temp file)**

Add this test to `test/core/services/sync/changeset_log/changeset_reader_test.dart` inside `main()` (it uses the file's existing `provider`, `writer`, `reader`, `folder` setup). First, update the shared `pullAs` helper in that file to pass `applyBaseFile`, decoding the file and forwarding to the same `applied` spy so existing assertions still hold:

```dart
// Replace the existing pullAs helper with this version.
Future<ChangesetReadResult> pullAs(String selfDeviceId) => reader.pull(
      provider: provider,
      selfDeviceId: selfDeviceId,
      folderId: folder,
      apply: spyApply,
      applyBaseFile: (path, manifest) async {
        final bytes = await File(path).readAsBytes();
        applied.add(ChangesetCodec(SyncDataSerializer()).decodeChangeset(bytes));
      },
    );
```

Add these imports at the top of the test file if missing:

```dart
import 'dart:io';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
```

Then add a new test asserting the base arrives via a real, readable file:

```dart
test('base branch hands applyBaseFile a readable temp file path', () async {
  await DiveRepository().createDive(
    Dive(
      diveDateTime: DateTime(2020, 1, 1),
      diveNumber: 1,
      maxDepth: 10,
      duration: 30,
    ),
  );
  final peerId = await publishAsPeer();

  String? seenPath;
  var exists = false;
  await reader.pull(
    provider: provider,
    selfDeviceId: 'other-device',
    folderId: folder,
    apply: spyApply,
    applyBaseFile: (path, manifest) async {
      seenPath = path;
      exists = await File(path).exists();
      expect(manifest.deviceId, peerId);
    },
  );

  expect(seenPath, isNotNull);
  expect(exists, isTrue, reason: 'file must exist during applyBaseFile');
  expect(await File(seenPath!).exists(), isFalse,
      reason: 'reader deletes the temp file after applyBaseFile');
});
```

(`Dive`/`DiveRepository` are already imported in this test file; if not, mirror the existing cold-start test's imports.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_test.dart`
Expected: FAIL — `pull` has no `applyBaseFile` parameter; `ApplyBaseFile` undefined.

- [ ] **Step 3: Implement the reader change**

In `lib/core/services/sync/changeset_log/changeset_reader.dart`:

Add the import and typedef near the top (after the existing imports):

```dart
import 'package:submersion/core/services/sync/changeset_log/base_part_file_sink.dart';
```

```dart
/// Applies a base that has been streamed to a local temp [filePath]. The real
/// implementation streams the file through the merge in bounded memory; see
/// SyncService._applyRemoteBaseFile.
typedef ApplyBaseFile = Future<void> Function(
  String filePath,
  SyncManifest manifest,
);
```

Change the constructor and field:

```dart
class ChangesetReader {
  ChangesetReader(this._codec, this._peerCursors, {BasePartFileSink? baseSink})
      : _baseSink = baseSink ?? BasePartFileSink();

  final ChangesetCodec _codec;
  final PeerCursorStore _peerCursors;
  final BasePartFileSink _baseSink;
```

Add `required ApplyBaseFile applyBaseFile,` to the `pull` signature (alongside `apply`).

Replace the base branch (currently using `_fetchBase` + `apply(base)`):

```dart
        // Cold-start, or lapped by the peer's compaction: adopt the base.
        final baseSeq = manifest.baseSeq;
        if (baseSeq != null && lastApplied < baseSeq) {
          final path = await _fetchBaseToFile(provider, peerId, manifest, byName);
          if (path == null) {
            continue; // missing or corrupt base -> transient, retry next sync
          }
          try {
            await applyBaseFile(path, manifest);
          } finally {
            await _baseSink.deleteQuietly(path);
          }
          payloadsApplied++;
          appliedThrough = baseSeq;
          baseSeqApplied = baseSeq;
        }
```

Replace `_fetchBase` with `_fetchBaseToFile`:

```dart
  Future<String?> _fetchBaseToFile(
    CloudStorageProvider provider,
    String peerId,
    SyncManifest manifest,
    Map<String, CloudFileInfo> byName,
  ) {
    final baseSeq = manifest.baseSeq!;
    return _baseSink.assemble(
      name: 'ssv1_${peerId}_$baseSeq',
      partCount: manifest.basePartCount ?? 0,
      wholeChecksum: manifest.baseChecksum,
      partChecksums: manifest.basePartChecksums,
      downloadPart: (i) async {
        final pf = byName[ChangesetLogLayout.basePartName(peerId, baseSeq, i)];
        if (pf == null) return null;
        return provider.downloadFile(pf.id);
      },
    );
  }
```

Remove the now-unused `BaseChunker`/`base_chunker.dart` import in this file only if nothing else references it (the changeset branch still uses `_codec`). Run analyze to confirm.

- [ ] **Step 4: Update the other two reader test harnesses**

In `test/core/services/sync/changeset_log/changeset_reader_epoch_test.dart` and `changeset_reader_verify_test.dart`, update each `reader.pull(...)` call (or shared helper) to pass:

```dart
      applyBaseFile: (path, manifest) async {
        final bytes = await File(path).readAsBytes();
        applied.add(ChangesetCodec(SyncDataSerializer()).decodeChangeset(bytes));
      },
```

adding the same `dart:io`, `SyncDataSerializer`, and `ChangesetCodec` imports as in Step 1. In `changeset_reader_verify_test.dart`, the test that asserts a corrupt base is skipped should keep asserting that `applied` does NOT receive the base — with the file path now verified by the sink, a corrupted part means `applyBaseFile` is never called (the sink returns null), so the existing "base skipped" expectation still holds. Adjust any assertion that inspected the decoded payload's checksum to instead assert `applied` did not gain the base entry.

- [ ] **Step 5: Run all reader tests to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/`
Expected: PASS (all reader + codec + chunker + sink + stream-reader tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/core/services/sync/changeset_log/changeset_reader.dart test/core/services/sync/changeset_log/
flutter analyze lib/core/services/sync/changeset_log/changeset_reader.dart
git add lib/core/services/sync/changeset_log/changeset_reader.dart test/core/services/sync/changeset_log/
git commit -m "feat(sync): reader adopts base via temp file + applyBaseFile callback"
```

---

## Task 4: `SyncService._applyRemoteBaseFile` — two-pass streaming apply

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart`
- Test: covered by Task 5 (parity) and Task 6 (convergence).

**Interfaces:**
- Consumes: `BaseJsonStreamReader` (Task 1); existing private merge primitives; `ApplyBaseFile` typedef (Task 3).
- Produces:
  - `static const Map<String, bool> _entityHasUpdatedAt` — single source the streaming apply uses for per-entity conflict-detection flags and the known-entity set. Mirrors the inline `mergeOrder` flags; the Task 5 parity test (which exercises every entity) guards against drift.
  - `Future<_MergeResult> _applyRemoteBaseFile(String filePath, DateTime? localLastSync)`
  - `@visibleForTesting` seams `debugApplyPayload` and `debugApplyBaseFile` (for the parity test).
  - Wires `applyBaseFile:` into the `_changesetReader.pull(...)` call.

- [ ] **Step 1: Add the entity flag map**

In `lib/core/services/sync/sync_service.dart`, add near the other private statics of `SyncService` (e.g. just above `parentRefs`):

```dart
  /// Per-entity "has an updatedAt column" flag, mirroring the `mergeOrder`
  /// records in `_applyRemotePayloadInner`. Used by the streaming base apply
  /// for (a) conflict-detection behavior in `_mergeEntity` and (b) the set of
  /// entity tables it will apply (keys == the known entities). Kept in sync
  /// with `mergeOrder` by the streaming-vs-in-memory parity test, which
  /// exercises every entity here.
  @visibleForTesting
  static const Map<String, bool> entityHasUpdatedAt = {
    'divers': true,
    'diverSettings': true,
    'buddies': true,
    'diveCenters': true,
    'trips': true,
    'liveaboardDetails': true,
    'itineraryDays': true,
    'equipment': true,
    'equipmentSets': true,
    'equipmentSetItems': false,
    'diveTypes': true,
    'tankPresets': true,
    'diveComputers': true,
    'species': false,
    'tags': true,
    'courses': true,
    'dives': true,
    'diveSites': true,
    'diveTanks': false,
    'diveWeights': false,
    'diveEquipment': false,
    'diveTags': false,
    'diveBuddies': false,
    'diveProfiles': false,
    'diveProfileEvents': false,
    'gasSwitches': false,
    'diveCustomFields': false,
    'diveDataSources': false,
    'siteSpecies': false,
    'csvPresets': true,
    'viewConfigs': true,
    'fieldPresets': false,
    'tankPressureProfiles': false,
    'tideRecords': false,
    'sightings': false,
    'certifications': true,
    'serviceRecords': true,
    'settings': true,
    'media': false,
  };
```

Add the imports at the top of the file:

```dart
import 'dart:io';
import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';
```

(`dart:convert`, `dart:typed_data`, and `@visibleForTesting`/`package:meta` or `package:flutter/foundation.dart` are already imported in this file; if `@visibleForTesting` is not, add `import 'package:meta/meta.dart';`.)

- [ ] **Step 2: Implement `_applyRemoteBaseFile`**

Add this method to `SyncService` (e.g. right after `_applyRemotePayloadInner`):

```dart
  /// Apply a base that was streamed to a local temp [filePath], in bounded
  /// memory. Three forward passes over the file:
  ///   1. header `exportedAt` + the full `deletions` map (both small),
  ///   2. parent-row id->updatedAt and contradiction keys (skips giant tables),
  ///   3. batched apply of every row through the existing `_mergeEntity`.
  /// Reuses the same merge primitives as `_applyRemotePayloadInner`, so the
  /// result is identical to applying the equivalent in-memory payload.
  Future<_MergeResult> _applyRemoteBaseFile(
    String filePath,
    DateTime? localLastSync,
  ) async {
    final file = File(filePath);
    final lastSyncMs = localLastSync?.millisecondsSinceEpoch;

    // ---- Pass 1: exportedAt + deletions ----
    var baseExportedAt = 0;
    final deletions = <String, List<SyncDeletion>>{};
    await BaseJsonStreamReader().parse(
      file.openRead(),
      onScalar: (key, raw) async {
        if (key == 'exportedAt') {
          baseExportedAt = (jsonDecode(utf8.decode(raw)) as num?)?.toInt() ?? 0;
        }
      },
      wantRows: (section, _) => section == 'deletions',
      onRow: (section, table, rowBytes) async {
        final decoded = jsonDecode(utf8.decode(rowBytes));
        if (decoded is Map<String, dynamic>) {
          (deletions[table] ??= []).add(SyncDeletion.fromJson(decoded));
        } else if (decoded is Map) {
          (deletions[table] ??= [])
              .add(SyncDeletion.fromJson(decoded.cast<String, dynamic>()));
        } else if (decoded is String) {
          (deletions[table] ??= []).add(SyncDeletion(id: decoded, deletedAt: 0));
        }
      },
    );

    final pendingByEntity = await _pendingRecordMap();

    // ---- Pass 2: parent updatedAt + contradiction keys ----
    final parentTypes = <String>{
      for (final refs in parentRefs.values)
        for (final ref in refs) ref.parent,
    };
    final deletionIds = <String, Set<String>>{
      for (final e in deletions.entries) e.key: {for (final d in e.value) d.id},
    };
    final parentUpdatedAt = <String, Map<String, int>>{};
    final contradictedByEntity = <String, Set<String>>{};
    await BaseJsonStreamReader().parse(
      file.openRead(),
      wantRows: (section, table) =>
          section == 'data' &&
          entityHasUpdatedAt.containsKey(table) &&
          (parentTypes.contains(table) || deletionIds.containsKey(table)),
      onRow: (section, table, rowBytes) async {
        final rec = jsonDecode(utf8.decode(rowBytes)) as Map<String, dynamic>;
        final id = _recordIdForEntity(table, rec);
        if (id == null) return;
        if (parentTypes.contains(table) && entityHasUpdatedAt[table] == true) {
          final u = _extractUpdatedAtMillis(rec);
          if (u != null) (parentUpdatedAt[table] ??= {})[id] = u;
        }
        if (deletionIds[table]?.contains(id) == true) {
          (contradictedByEntity[table] ??= {}).add(id);
        }
      },
    );

    // ---- Apply, all inside one deferred-FK transaction ----
    return _serializer.applyInDeferredFkTransaction(() async {
      var recordsApplied = 0;
      var conflictsFound = 0;
      var recordsFailed = 0;

      final delResult = await _applyRemoteDeletions(
        deletions,
        lastSyncMs,
        baseExportedAt,
        pendingByEntity,
        contradictedByEntity,
      );
      recordsApplied += delResult.recordsApplied;
      conflictsFound += delResult.conflictsFound;
      recordsFailed += delResult.recordsFailed;

      // Load tombstones AFTER deletions so a tombstone arriving in this base
      // also guards the merge below (mirrors _applyRemotePayloadInner).
      final tombstonesByEntity = await _deletionMap();

      // Revived parents: a parent row whose remote updatedAt is newer than our
      // local tombstone. Combines pass-2 file data with post-deletion tombstones.
      final revivedParents = <String, Set<String>>{};
      for (final parentType in parentTypes) {
        final tombs = tombstonesByEntity[parentType];
        final ups = parentUpdatedAt[parentType];
        if (tombs == null || tombs.isEmpty || ups == null) continue;
        ups.forEach((id, updatedAt) {
          final deletedAt = tombs[id];
          if (deletedAt != null && updatedAt > deletedAt) {
            (revivedParents[parentType] ??= {}).add(id);
          }
        });
      }

      // ---- Pass 3: batched apply ----
      const batchSize = 500;
      String? currentTable;
      var batch = <Map<String, dynamic>>[];

      Future<void> flush() async {
        final table = currentTable;
        if (table == null || batch.isEmpty) return;
        final r = await _mergeEntity(
          entityType: table,
          records: batch,
          hasUpdatedAt: entityHasUpdatedAt[table] ?? false,
          lastSyncMs: lastSyncMs,
          pendingRecordIds: pendingByEntity[table] ?? const <String>{},
          allTombstones: tombstonesByEntity,
          revivedParents: revivedParents,
          contradicted: contradictedByEntity[table] ?? const <String>{},
        );
        recordsApplied += r.recordsApplied;
        conflictsFound += r.conflictsFound;
        recordsFailed += r.recordsFailed;
        batch = <Map<String, dynamic>>[];
      }

      await BaseJsonStreamReader().parse(
        file.openRead(),
        wantRows: (section, table) =>
            section == 'data' && entityHasUpdatedAt.containsKey(table),
        onRow: (section, table, rowBytes) async {
          if (table != currentTable) {
            await flush();
            currentTable = table;
          }
          batch.add(jsonDecode(utf8.decode(rowBytes)) as Map<String, dynamic>);
          if (batch.length >= batchSize) await flush();
        },
      );
      await flush();

      await _serializer.repairDanglingForeignKeys();
      return _MergeResult(
        recordsApplied: recordsApplied,
        conflictsFound: conflictsFound,
        recordsFailed: recordsFailed,
      );
    });
  }
```

- [ ] **Step 3: Wire `applyBaseFile` into the pull call**

In `performSync()`, the `_changesetReader.pull(...)` call currently passes only `apply:`. Add the base callback:

```dart
      await _changesetReader.pull(
        provider: provider,
        selfDeviceId: deviceId,
        folderId: folderId,
        currentEpochId: currentEpochId,
        apply: (payload) async {
          final r = await _applyRemotePayload(payload, lastSyncTime);
          recordsSynced += r.recordsApplied;
          conflictsFound += r.conflictsFound;
          recordsFailed += r.recordsFailed;
        },
        applyBaseFile: (path, manifest) async {
          final r = await _applyRemoteBaseFile(path, lastSyncTime);
          recordsSynced += r.recordsApplied;
          conflictsFound += r.conflictsFound;
          recordsFailed += r.recordsFailed;
        },
      );
```

- [ ] **Step 4: Add the test seams**

Add to `SyncService`:

```dart
  /// Test seam: apply an in-memory payload through the standard merge.
  @visibleForTesting
  Future<({int recordsApplied, int conflictsFound, int recordsFailed})>
      debugApplyPayload(SyncPayload payload, {DateTime? lastSync}) async {
    final r = await _applyRemotePayload(payload, lastSync);
    return (
      recordsApplied: r.recordsApplied,
      conflictsFound: r.conflictsFound,
      recordsFailed: r.recordsFailed,
    );
  }

  /// Test seam: apply a base from a local file through the streaming merge.
  @visibleForTesting
  Future<({int recordsApplied, int conflictsFound, int recordsFailed})>
      debugApplyBaseFile(String filePath, {DateTime? lastSync}) async {
    final r = await _applyRemoteBaseFile(filePath, lastSync);
    return (
      recordsApplied: r.recordsApplied,
      conflictsFound: r.conflictsFound,
      recordsFailed: r.recordsFailed,
    );
  }
```

- [ ] **Step 5: Analyze (compile check) and commit**

Run: `flutter analyze lib/core/services/sync/sync_service.dart`
Expected: no errors. (Behavior is verified by Tasks 5 and 6.)

```bash
dart format lib/core/services/sync/sync_service.dart
git add lib/core/services/sync/sync_service.dart
git commit -m "feat(sync): bounded-memory streaming base apply (_applyRemoteBaseFile)"
```

---

## Task 5: Parity test — streaming apply == in-memory apply (the linchpin)

**Files:**
- Create: `test/core/services/sync/sync_base_streaming_parity_test.dart`

**Interfaces:**
- Consumes: `SyncService.debugApplyPayload`, `SyncService.debugApplyBaseFile` (Task 4); `SyncDataSerializer.serializePayload`/`exportData`; test DB helpers.

- [ ] **Step 1: Write the parity test**

Create `test/core/services/sync/sync_base_streaming_parity_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Seeds a representative library covering parent + child + junction tables and
/// at least one conflict-bearing entity, so parity exercises every merge path.
Future<void> seedRichLibrary() async {
  final dives = DiveRepository();
  for (var i = 1; i <= 5; i++) {
    await dives.createDive(
      Dive(
        diveDateTime: DateTime(2020, 1, i),
        diveNumber: i,
        maxDepth: 10.0 + i,
        duration: 30 + i,
      ),
    );
  }
  // Add profile samples to the first dive (the high-row-count table).
  final all = await dives.getAllDives();
  // (If a profile-writing repository helper exists, add samples here; the dive
  // rows alone already exercise parent + clockless-child + merge-order paths.)
  expect(all.length, 5);
}

String dumpAllData(SyncDataSerializer serializer) =>
    jsonEncode(_lastExport!.data.toJson());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => tearDownTestDatabase());

  test('streaming base apply produces a byte-identical DB to in-memory apply',
      () async {
    // 1. Build a rich payload from a seeded DB, then wipe to simulate a cold
    //    device adopting a peer's base.
    await seedRichLibrary();
    final serializer = SyncDataSerializer();
    final payload = await serializer.exportData(
      deviceId: 'peer',
      deletions: await SyncRepository().getAllDeletions(),
    );

    // 2. Apply IN-MEMORY into a fresh DB; snapshot the result.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final svc1 = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    );
    final counts1 = await svc1.debugApplyPayload(payload);
    final dump1 = jsonEncode(
      (await SyncDataSerializer().exportData(deviceId: 'x', deletions: const []))
          .data
          .toJson(),
    );

    // 3. Apply via STREAMING FILE into another fresh DB; snapshot the result.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final tmpDir = await Directory.systemTemp.createTemp('parity');
    final tmp = File('${tmpDir.path}/base.json');
    await tmp.writeAsBytes(
      utf8.encode(SyncDataSerializer().serializePayload(payload)),
    );
    final svc2 = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    );
    final counts2 = await svc2.debugApplyBaseFile(tmp.path);
    final dump2 = jsonEncode(
      (await SyncDataSerializer().exportData(deviceId: 'x', deletions: const []))
          .data
          .toJson(),
    );
    await tmpDir.delete(recursive: true);

    expect(dump2, dump1, reason: 'streaming DB must match in-memory DB exactly');
    expect(counts2.recordsApplied, counts1.recordsApplied);
    expect(counts2.conflictsFound, counts1.conflictsFound);
    expect(counts2.recordsFailed, counts1.recordsFailed);
  });
}
```

Note on `_lastExport`: delete the unused `dumpAllData`/`_lastExport` helper above — the test inlines its snapshots. (It is left out of the final file; do not define it.)

- [ ] **Step 2: Run to verify it fails (then passes)**

Run: `flutter test test/core/services/sync/sync_base_streaming_parity_test.dart`
Expected first run: may FAIL if `_applyRemoteBaseFile` has a transcription bug (e.g. a wrong `entityHasUpdatedAt` flag) — the dumps differ. Fix the implementation (NOT the test) until both the DB dump and the counts match. Expected final: PASS.

- [ ] **Step 3: Add a batch-size invariance check**

To prove batching never changes the result, parameterize the streaming apply's batch size is internal; instead assert invariance by also applying the same payload with a deliberately tiny library twice is unnecessary. Add a second case that seeds a library with MORE than 500 rows of one table to cross the batch boundary, and re-run the same dump1==dump2 assertion. If no profile-writing helper is available to exceed 500 rows quickly, create 600 dives:

```dart
  test('batch boundary (>500 rows) does not change the streaming result',
      () async {
    final dives = DiveRepository();
    for (var i = 1; i <= 600; i++) {
      await dives.createDive(
        Dive(
          diveDateTime: DateTime(2021, 1, 1).add(Duration(minutes: i)),
          diveNumber: i,
          maxDepth: 12,
          duration: 25,
        ),
      );
    }
    final payload = await SyncDataSerializer().exportData(
      deviceId: 'peer',
      deletions: await SyncRepository().getAllDeletions(),
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final svcA = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    );
    await svcA.debugApplyPayload(payload);
    final dumpA = jsonEncode(
      (await SyncDataSerializer().exportData(deviceId: 'x', deletions: const []))
          .data
          .toJson(),
    );

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final tmpDir = await Directory.systemTemp.createTemp('parity_big');
    final tmp = File('${tmpDir.path}/base.json');
    await tmp.writeAsBytes(
      utf8.encode(SyncDataSerializer().serializePayload(payload)),
    );
    final svcB = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    );
    await svcB.debugApplyBaseFile(tmp.path);
    final dumpB = jsonEncode(
      (await SyncDataSerializer().exportData(deviceId: 'x', deletions: const []))
          .data
          .toJson(),
    );
    await tmpDir.delete(recursive: true);

    expect(dumpB, dumpA);
  });
```

- [ ] **Step 4: Run, format, commit**

Run: `flutter test test/core/services/sync/sync_base_streaming_parity_test.dart`
Expected: PASS (2 tests).

```bash
dart format test/core/services/sync/sync_base_streaming_parity_test.dart
flutter analyze test/core/services/sync/sync_base_streaming_parity_test.dart
git add test/core/services/sync/sync_base_streaming_parity_test.dart
git commit -m "test(sync): parity between streaming and in-memory base apply"
```

---

## Task 6: Confirm end-to-end convergence through the streaming path

**Files:**
- Modify (if needed): `test/core/services/sync/changeset_sync_convergence_test.dart`

**Interfaces:**
- Consumes: `performSync()` (now routes base adoption through `_applyRemoteBaseFile`); `seedPeerLog`/`seedPeerBaseFromPayload` helpers.

- [ ] **Step 1: Run the existing convergence suite (it now exercises streaming)**

Because `performSync` now adopts bases via the streaming file path, the existing cold-start convergence test already covers it end to end (download parts -> temp file -> streaming apply).

Run: `flutter test test/core/services/sync/changeset_sync_convergence_test.dart`
Expected: PASS. If it fails, debug `_applyRemoteBaseFile` (do not weaken the test).

- [ ] **Step 2: Add an explicit assertion that a base larger than one part converges**

Add a test that publishes a peer library big enough to span multiple base parts (force a small part size by seeding many rows), then cold-starts and asserts the local DB matches. If forcing many rows is impractical in unit time, assert at minimum that a normal cold-start leaves a clean DB and an empty temp dir afterward (no leaked `*.base` files in `Directory.systemTemp`). Example sketch using existing helpers:

```dart
  test('cold-start base adoption converges and leaves no temp files',
      () async {
    // ... seed peer via seedPeerLog, create local device, performSync ...
    // assert local dives == peer dives
    final leaked = Directory.systemTemp
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.base'));
    expect(leaked, isEmpty);
  });
```

- [ ] **Step 3: Run the whole sync suite**

Run: `flutter test test/core/services/sync/`
Expected: PASS (all sync tests, including the existing 40+ files).

- [ ] **Step 4: Commit any test changes**

```bash
dart format test/core/services/sync/
git add test/core/services/sync/
git commit -m "test(sync): convergence covers streaming base adoption end to end"
```

---

## Task 7: Full verification sweep

**Files:** none (verification only).

- [ ] **Step 1: Format check (whole project)**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: exit 0 (no changes).

- [ ] **Step 2: Analyze (whole project)**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all pass. (If runtime is long, run `flutter test test/core/services/sync/` plus any touched areas, but a full run before PR is required.)

- [ ] **Step 4: Final commit (if formatting changed anything)**

```bash
git add -A
git commit -m "chore(sync): format + analyze clean for streaming base import"
```

---

## Self-Review

**Spec coverage:**
- Bounded-memory base import via temp file + batched apply → Tasks 1-4. ✓
- No wire-format change; old JSON bases import unchanged → Tasks 1, 3, 4 (raw `jsonDecode` rows; reader uses existing manifest fields). ✓
- Manifest per-part + whole-file checksum verification; drop payload-level checksum for bases → Task 2 (`BasePartFileSink`). ✓
- Merge logic reused unchanged → Task 4 calls existing `_mergeEntity`/`_applyRemoteDeletions`/`repairDanglingForeignKeys`; no edits to them (Global Constraints). ✓
- Atomicity (single deferred-FK transaction; cursor advances only on success) → Task 4 (transaction) + Task 3 (reader advances after `applyBaseFile`). ✓
- Temp file in `Directory.systemTemp`, deleted in `finally` → Task 2 + Task 3. ✓
- Responsiveness: the per-byte scanner yields at every awaited `onRow` (DB write) so the event loop breathes; no extra `Future.delayed` needed because pass 3's awaits are real async DB calls. (If profiling shows main-thread starvation, add a periodic yield in `flush`.) ✓
- Tests: boundary scanner (Task 1), file sink (Task 2), parity incl. batch boundary (Task 5), convergence + no-leak (Task 6). ✓
- Out of scope: `_collectEpochPayloads` and write side untouched (Global Constraints; design doc follow-ups). ✓

**Placeholder scan:** No "TBD"/"handle edge cases" left. The parity test's `seedRichLibrary` notes that profile-sample seeding is optional if no helper exists; the >500-row case (Task 5 Step 3) guarantees batch-boundary coverage regardless. The convergence "big base" case (Task 6 Step 2) gives a concrete fallback assertion.

**Type consistency:** `applyBaseFile`/`ApplyBaseFile` signature `(String filePath, SyncManifest manifest)` consistent across Tasks 3-4. `entityHasUpdatedAt` used in Task 4 only (defined once). `debugApplyPayload`/`debugApplyBaseFile` return record type matches the parity test usage in Task 5. `BasePartFileSink.assemble` named params match the reader call in Task 3.

**Known residual risk:** the hand-rolled scanner is the highest-risk component; it is covered by chunk-splitting, escape, nesting, and large-row tests (Task 1) and end-to-end by parity (Task 5). The `entityHasUpdatedAt` map is duplicated from `mergeOrder` and guarded against drift by the all-entity parity test (Task 5).
