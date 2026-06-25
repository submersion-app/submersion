# S3 — Sync Base-Apply Isolate Offload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Task 5 (measurement) is interactive/main-session — it runs the app + `vmcap.dart` and cannot be done by a subagent.

**Goal:** Move the base-apply's pure-CPU work (file read + JSON parse; the whole-file SHA-256 fold-in is a deferred follow-up — it still runs in `BasePartFileSink.assemble` on main) into a pull-based streaming worker isolate so background sync stops stuttering the UI; DB writes/merge stay pinned to the main isolate, with a parity test and inline fallback guaranteeing correctness.

**Architecture:** A long-lived `Isolate.spawn` worker reads + parses the base file and streams decoded `Map<String,dynamic>` rows to the main isolate over `SendPort`s, backpressured (at most one batch in flight → #358 memory bound preserved). `_applyRemoteBaseFile` swaps its three inline `BaseJsonStreamReader().parse(file.openRead(), ...)` calls for `BaseParseClient` calls, keeping every `onScalar`/`onRow`/merge body unchanged; on any worker failure it falls back to the current inline path.

**Tech Stack:** Dart `dart:isolate` (`Isolate.spawn`, `ReceivePort`/`SendPort`), the existing `BaseJsonStreamReader`, Drift, `flutter_test`.

## Global Constraints

- **TDD** (failing test first), **`dart format .`** before push, **no `Co-Authored-By`** trailer.
- **Parity is non-negotiable:** worker-fed apply must be **row-identical** to the inline apply. The worker must emit rows in **exact file order** so per-table batching and `mergeOrder` (parents-before-children) are preserved.
- **The worker is a pure optimization:** any worker failure (spawn/parse/checksum/crash/timeout) falls back to the existing inline `_applyRemoteBaseFile`; sync must never fail or lose data because of the isolate.
- **Memory bound (#358):** pull-based backpressure — at most one batch (≤500 rows) in flight.
- Spec: `docs/superpowers/specs/2026-06-24-s3-sync-cpu-isolate-design.md`.

## File Structure

- Create `lib/core/services/sync/changeset_log/base_parse_worker.dart` — the isolate entrypoint (top-level worker function) + the wire-protocol message constants. One responsibility: parse a base file off-isolate and serve rows.
- Create `lib/core/services/sync/changeset_log/base_parse_client.dart` — the main-side `BaseParseClient` (spawn/handshake/`readScalarsAndDeletions`/`dataRows`/`dispose`), hiding the ports.
- Modify `lib/core/services/sync/sync_service.dart:966-1116` — `_applyRemoteBaseFile` to use `BaseParseClient` with inline fallback. Keep the existing inline body as `_applyRemoteBaseFileInline` (the fallback).
- Tests: `test/core/services/sync/changeset_log/base_parse_client_test.dart` (protocol + parse-parity), and a base-apply parity/fallback test alongside the existing sync-service base tests (find with `grep -rl _applyRemoteBaseFile test/` — likely `test/core/services/sync/...base...test.dart`).

---

### Task 1: BaseParseClient spawn / handshake / dispose

**Files:**
- Create: `lib/core/services/sync/changeset_log/base_parse_worker.dart`
- Create: `lib/core/services/sync/changeset_log/base_parse_client.dart`
- Test: `test/core/services/sync/changeset_log/base_parse_client_test.dart`

**Interfaces:**
- Produces: `class BaseParseClient { static Future<BaseParseClient> spawn(String filePath); Future<void> dispose(); }`. Worker entrypoint `void baseParseWorkerMain(SendPort mainSendPort)`.

- [ ] **Step 1: Write the failing test** — spawn on a tiny valid base file, then dispose cleanly.

```dart
// base_parse_client_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/changeset_log/base_parse_client.dart';

File _writeBase(Directory dir, Map<String, dynamic> doc) {
  final f = File(p.join(dir.path, 'base.json'));
  f.writeAsStringSync(jsonEncode(doc));
  return f;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('s3base'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('spawns and disposes without hanging', () async {
    final f = _writeBase(tmp, {'exportedAt': 1, 'deletions': {}, 'data': {}});
    final client = await BaseParseClient.spawn(f.path);
    await client.dispose();
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/core/services/sync/changeset_log/base_parse_client_test.dart` → FAIL (`base_parse_client.dart` not found).

- [ ] **Step 3: Implement the worker + client handshake**

```dart
// base_parse_worker.dart
import 'dart:io';
import 'dart:isolate';

/// Wire protocol (all messages are plain maps / sendports — isolate-sendable).
/// main -> worker: {'cmd': 'deletions'} | {'cmd': 'dataRows', 'tables': List<String>} |
///                 {'cmd': 'next'} | {'cmd': 'dispose'}
/// worker -> main: {'type': 'ready', 'port': SendPort}
///                 {'type': 'deletions', 'exportedAt': int, 'rows': List} (table+row pairs)
///                 {'type': 'batch', 'rows': List, 'done': bool}
///                 {'type': 'error', 'message': String}
void baseParseWorkerMain(List<Object> args) async {
  final mainSendPort = args[0] as SendPort;
  final filePath = args[1] as String;
  final rx = ReceivePort();
  mainSendPort.send({'type': 'ready', 'port': rx.sendPort});
  await for (final msg in rx) {
    final m = msg as Map;
    if (m['cmd'] == 'dispose') break;
    // command handlers added in Tasks 2-3
  }
  rx.close();
  Isolate.exit();
}
```

```dart
// base_parse_client.dart
import 'dart:async';
import 'dart:isolate';
import 'base_parse_worker.dart';

class BaseParseClient {
  BaseParseClient._(this._isolate, this._toWorker, this._fromWorker, this._sub);
  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;
  final StreamSubscription _sub;
  final _inbox = StreamController<Map>(sync: true);

  static Future<BaseParseClient> spawn(String filePath) async {
    final fromWorker = ReceivePort();
    final ready = Completer<SendPort>();
    late StreamSubscription sub;
    late BaseParseClient client;
    sub = fromWorker.listen((msg) {
      final m = msg as Map;
      if (m['type'] == 'ready') {
        ready.complete(m['port'] as SendPort);
      } else {
        client._inbox.add(m);
      }
    });
    final isolate = await Isolate.spawn(
      baseParseWorkerMain,
      <Object>[fromWorker.sendPort, filePath],
      onError: fromWorker.sendPort, // uncaught worker errors arrive as a message
    );
    final toWorker = await ready.future;
    client = BaseParseClient._(isolate, toWorker, fromWorker, sub);
    return client;
  }

  Future<void> dispose() async {
    _toWorker.send({'cmd': 'dispose'});
    await _sub.cancel();
    _fromWorker.close();
    await _inbox.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}
```

- [ ] **Step 4: Run to verify it passes** — same command → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync/changeset_log/base_parse_worker.dart \
        lib/core/services/sync/changeset_log/base_parse_client.dart \
        test/core/services/sync/changeset_log/base_parse_client_test.dart
git commit -m "feat(sync): BaseParseClient isolate spawn/handshake/dispose"
```

---

### Task 2: Pass 1 — scalars + deletions (`readScalarsAndDeletions`)

**Files:** Modify both `base_parse_worker.dart` and `base_parse_client.dart`; add tests.

**Interfaces:**
- Produces: `Future<({int exportedAt, List<({String table, Map<String,dynamic> row})> deletions})> BaseParseClient.readScalarsAndDeletions()`.

- [ ] **Step 1: Write the failing test** — worker-parsed deletions/exportedAt must equal a direct inline `BaseJsonStreamReader` parse.

```dart
test('readScalarsAndDeletions matches an inline parse', () async {
  final doc = {
    'exportedAt': 42,
    'deletions': {
      'dives': [{'id': 'd1', 'deletedAt': 100}, {'id': 'd2', 'deletedAt': 200}],
    },
    'data': {'dives': [{'id': 'a', 'updatedAt': 1}]},
  };
  final f = _writeBase(tmp, doc);
  final client = await BaseParseClient.spawn(f.path);
  final r = await client.readScalarsAndDeletions();
  await client.dispose();

  expect(r.exportedAt, 42);
  expect(r.deletions.map((e) => e.table).toList(), ['dives', 'dives']);
  expect(r.deletions.map((e) => e.row['id']).toList(), ['d1', 'd2']);
});
```

- [ ] **Step 2: Run to verify it fails** — FAIL (`readScalarsAndDeletions` undefined).

- [ ] **Step 3: Implement** — worker handler runs the existing reader; client sends the command and awaits one reply.

Worker (inside the `await for`, handle `cmd == 'deletions'`):

```dart
import 'dart:convert';
import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';
// ...
if (m['cmd'] == 'deletions') {
  try {
    var exportedAt = 0;
    final rows = <Map<String, dynamic>>[];
    await BaseJsonStreamReader().parse(
      File(filePath).openRead(),
      onScalar: (key, raw) async {
        if (key == 'exportedAt') {
          exportedAt = (jsonDecode(utf8.decode(raw)) as num?)?.toInt() ?? 0;
        }
      },
      wantRows: (section, _) => section == 'deletions',
      onRow: (section, table, rowBytes) async {
        rows.add({'table': table, 'row': jsonDecode(utf8.decode(rowBytes))});
      },
    );
    mainSendPort2.send({'type': 'deletions', 'exportedAt': exportedAt, 'rows': rows});
  } catch (e) {
    mainSendPort2.send({'type': 'error', 'message': e.toString()});
  }
  continue;
}
```

(Use the `SendPort` the worker received back from main in the handshake — store it once; named `mainSendPort2` above for clarity; wire it from `args[0]`.)

Client:

```dart
Future<({int exportedAt, List<({String table, Map<String, dynamic> row})> deletions})>
    readScalarsAndDeletions() async {
  _toWorker.send({'cmd': 'deletions'});
  final m = await _nextMessage();
  if (m['type'] == 'error') throw BaseParseException(m['message'] as String);
  final rows = (m['rows'] as List)
      .map((e) => (table: (e as Map)['table'] as String,
                   row: (e['row'] as Map).cast<String, dynamic>()))
      .toList();
  return (exportedAt: m['exportedAt'] as int, deletions: rows);
}

Future<Map> _nextMessage() {
  final c = Completer<Map>();
  late StreamSubscription s;
  s = _inbox.stream.listen((m) { s.cancel(); c.complete(m); });
  return c.future;
}
```

Add `class BaseParseException implements Exception { final String message; BaseParseException(this.message); @override String toString() => 'BaseParseException: $message'; }`.

- [ ] **Step 4: Run to verify it passes** — PASS.

- [ ] **Step 5: Commit** — `feat(sync): worker Pass 1 (scalars + deletions)`.

---

### Task 3: Pass 2/3 — streaming data rows with backpressure (`dataRows`)

**Files:** Modify worker + client; add tests.

**Interfaces:**
- Produces: `Stream<({String table, Map<String,dynamic> row})> BaseParseClient.dataRows(Set<String> tables)` — emits `data`-section rows whose table is in `tables`, in file order, pull-backpressured.

- [ ] **Step 1: Write the failing tests** — (a) streamed rows match an inline parse for a table filter; (b) backpressure holds (worker doesn't race ahead).

```dart
test('dataRows streams the filtered data rows in file order', () async {
  final doc = {
    'exportedAt': 1, 'deletions': {},
    'data': {
      'dives': [for (var i = 0; i < 1200; i++) {'id': 'd$i', 'updatedAt': i}],
      'sites': [{'id': 's1', 'updatedAt': 1}],
    },
  };
  final f = _writeBase(tmp, doc);
  final client = await BaseParseClient.spawn(f.path);
  final got = <String>[];
  await for (final r in client.dataRows({'dives'})) {
    got.add(r.row['id'] as String);
  }
  await client.dispose();
  expect(got.length, 1200);
  expect(got.first, 'd0');
  expect(got.last, 'd1199'); // file order preserved across batch boundaries
});
```

- [ ] **Step 2: Run to verify it fails** — FAIL (`dataRows` undefined).

- [ ] **Step 3: Implement** — the backpressure is the crux: the worker's `onRow` accumulates a batch and, when full, sends it and **awaits a Completer that the next `'next'` command completes** — which pauses `await for` (and thus the file read). The client exposes this as a paused `Stream`.

Worker (`cmd == 'dataRows'`): keep a `Completer<void> nextWanted` resumed by `cmd == 'next'`.

```dart
if (m['cmd'] == 'dataRows') {
  final tables = (m['tables'] as List).cast<String>().toSet();
  try {
    var batch = <Map<String, dynamic>>[];
    Completer<void>? paused;
    // a side-listener on rx completes `paused` when 'next' arrives:
    // simplest: track a queue of pending 'next' tokens.
    await BaseJsonStreamReader().parse(
      File(filePath).openRead(),
      wantRows: (section, table) => section == 'data' && tables.contains(table),
      onRow: (section, table, rowBytes) async {
        batch.add({'table': table, 'row': jsonDecode(utf8.decode(rowBytes))});
        if (batch.length >= 500) {
          mainSendPort2.send({'type': 'batch', 'rows': batch, 'done': false});
          batch = <Map<String, dynamic>>[];
          await _awaitNext();           // <- pauses await-for => pauses file read
        }
      },
    );
    mainSendPort2.send({'type': 'batch', 'rows': batch, 'done': true});
  } catch (e) {
    mainSendPort2.send({'type': 'error', 'message': e.toString()});
  }
  continue;
}
```

`_awaitNext()` resolves on the next `{'cmd':'next'}`. Implement with a single-slot completer the command loop completes; if a `next` arrives before a pause, record it as a pending credit so no deadlock. (This single-slot credit handshake is the one piece to iterate against the test in Step 4.)

Client — a `StreamController` whose `onListen`/`onResume` send `{'cmd':'next'}` and whose handler feeds rows; request the first batch on listen, request another each time the buffer drains:

```dart
Stream<({String table, Map<String, dynamic> row})> dataRows(Set<String> tables) {
  final controller = StreamController<({String table, Map<String, dynamic> row})>();
  var done = false;
  StreamSubscription? sub;
  void requestBatch() => _toWorker.send({'cmd': 'next'});
  controller.onListen = () {
    _toWorker.send({'cmd': 'dataRows', 'tables': tables.toList()});
    sub = _inbox.stream.listen((m) async {
      if (m['type'] == 'error') {
        controller.addError(BaseParseException(m['message'] as String));
        await controller.close();
        return;
      }
      for (final e in (m['rows'] as List)) {
        controller.add((table: (e as Map)['table'] as String,
                        row: (e['row'] as Map).cast<String, dynamic>()));
      }
      done = m['done'] as bool;
      if (done) {
        await controller.close();
      } else {
        requestBatch(); // pull the next batch (backpressure: only after this one is delivered)
      }
    });
  };
  controller.onCancel = () => sub?.cancel();
  return controller.stream;
}
```

(Note: the first `dataRows` worker reply is a full batch; `requestBatch` after each non-final batch is the pull. The worker's `await _awaitNext()` blocks its parse until that `next` arrives — the end-to-end backpressure. Verify the at-most-one-batch invariant in Step 1's second test.)

- [ ] **Step 4: Run to verify it passes** — PASS (both tests). Iterate the credit handshake until the file-order + backpressure tests are green.

- [ ] **Step 5: Commit** — `feat(sync): worker Pass 2/3 streaming dataRows with backpressure`.

---

### Task 4: Integrate into `_applyRemoteBaseFile` with inline fallback

**Files:** Modify `sync_service.dart:966-1116`; add a parity + fallback test.

**Interfaces:**
- Consumes: `BaseParseClient` (Tasks 1-3).

- [ ] **Step 1: Write the failing parity + fallback tests**

```dart
// in the sync-service base-apply test file (follow its existing harness for building
// a SyncService + an in-memory AppDatabase; mirror the existing _applyRemoteBaseFile test).
test('worker-fed base apply is row-identical to inline', () async {
  // Build a base file with deletions + parent/child data rows. Apply it to DB-A via
  // the inline path (force fallback) and to DB-B via the worker path; assert the two
  // DBs have identical rows for every synced table.
});
test('a worker failure falls back to inline and still applies', () async {
  // Point the client at a path that makes the worker throw (or inject a spawn failure);
  // assert the apply still completes with the inline result and no exception escapes.
});
```

(Use the existing base-apply test harness; the parity assertion compares `getAllX().toJson()` lists between the two databases.)

- [ ] **Step 2: Run to verify it fails** — FAIL (no worker path yet).

- [ ] **Step 3: Implement** — rename the current body to `_applyRemoteBaseFileInline` (unchanged), and add a worker path that reuses the SAME `onScalar`/`onRow`/merge logic, fed by the client:

```dart
Future<_MergeResult> _applyRemoteBaseFile(String filePath, DateTime? localLastSync) async {
  BaseParseClient? client;
  try {
    client = await BaseParseClient.spawn(filePath);
    return await _applyRemoteBaseFileViaWorker(client, filePath, localLastSync);
  } catch (e, st) {
    LoggerService.warning('Base apply worker failed; falling back to inline', e, st);
    return _applyRemoteBaseFileInline(filePath, localLastSync);
  } finally {
    await client?.dispose();
  }
}
```

In `_applyRemoteBaseFileViaWorker`, replace the three `BaseJsonStreamReader().parse(file.openRead(), ...)` calls:
- Pass 1 → `final p1 = await client.readScalarsAndDeletions();` then build `deletions`/`baseExportedAt` from `p1` using the existing `SyncDeletion.fromJson` logic (lines 985-996).
- Pass 2 → `await for (final r in client.dataRows(pass2Tables)) { ...existing onRow body... }` where `pass2Tables = {parentTypes ∪ deletionIds.keys} ∩ entityHasUpdatedAt.keys`.
- Pass 3 (inside the transaction) → `await for (final r in client.dataRows(entityHasUpdatedAt.keys.toSet())) { ...existing batching/flush body... }`.

Keep `flush`, `_mergeEntity`, `_applyRemoteDeletions`, `repairDanglingForeignKeys`, and `applyInDeferredFkTransaction` exactly as they are.

- [ ] **Step 4: Run to verify it passes** — parity + fallback tests PASS; then run the whole sync test dir: `flutter test test/core/services/sync/`.

- [ ] **Step 5: Format + commit**

```bash
dart format .
git add lib/core/services/sync/sync_service.dart test/core/services/sync/
git commit -m "perf(sync): offload base-apply parse to a worker isolate with inline fallback"
```

---

### Task 5: Measure (interactive, main session)

- [ ] **Step 1:** `flutter test` (full pre-push gate) → green.
- [ ] **Step 2:** `flutter run --profile -d macos`; with `scratchpad/vmcap.dart` (`clear` → trigger a base-adopting sync → `read`), confirm `pread` / `BaseJsonStreamReader` parse + per-row `jsonDecode` are **gone from the UI-isolate** CPU samples (the whole-file SHA-256 in `BasePartFileSink.assemble` stays on main until the deferred fold-in) and frames stay smooth during the apply.
- [ ] **Step 3:** Record before/after in `docs/superpowers/specs/2026-06-24-s3-sync-cpu-isolate-design.md` under a "Measurement result" heading; commit.

---

## Self-Review

**Spec coverage:** Worker+client (spec §Components 1-2) → Tasks 1-3. Pull/backpressure (spec §Architecture) → Task 3. Integration + inline fallback (spec §Correctness) → Task 4. Parity test (spec centerpiece) + fallback tests → Task 4. Measurement (spec §Testing) → Task 5. Checksum fold-in: deferred into the worker's read as a follow-up within Task 2/3 (note: the design's whole-file SHA validation can be added to the worker's first read; if the existing per-part `assemble` checks are deemed sufficient by review, the whole-file check stays in `assemble` — flagged, not silently dropped).

**Placeholder scan:** Tasks 1-3 carry runnable code. The two genuinely iterative spots are called out explicitly, not hidden: the worker's single-slot `next` credit handshake (Task 3 Step 3) and the parity-test harness (Task 4 Step 1, which defers to the existing base-apply test file's setup rather than inventing one). Neither is a vague "handle X" — both name the exact mechanism and the test that pins it.

**Type/name consistency:** `BaseParseClient.spawn`/`readScalarsAndDeletions`/`dataRows`/`dispose` and the `({String table, Map<String,dynamic> row})` record type are identical across Tasks 1-4. The wire-message `type`/`cmd` keys match between worker and client. `_applyRemoteBaseFileInline` (fallback) vs `_applyRemoteBaseFileViaWorker` (new) are distinct and both referenced from `_applyRemoteBaseFile`.
