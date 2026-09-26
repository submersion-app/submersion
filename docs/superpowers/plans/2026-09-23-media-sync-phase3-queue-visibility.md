# Media Sync Slice 10: The Queue Never Waits Silently

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every way the media transfer queue can stop moving leaves a
reason the user can see, and every stranded or deferred row is picked up
again without an outside trigger (spec 7.1, issue #2126). Turns harness
scenarios S8 and S10 green.

**Architecture:** The queue repository gains two pieces of process-wide,
per-database, in-memory state: leases on the entries a worker is running,
so a reclaim can run on every drain without touching a live transfer, and a
single "hold" describing why the drain stopped, which `watchSummary` merges
into its snapshot. The worker records a hold for every stop (offline,
store unreachable, detached, marker mismatch), reclaims stranded rows at the
start of every drain, and leaves a reason on every row it parks. The
preflight answers with a verdict instead of a bool, and a marker mismatch is
also persisted so the pending-setup card can offer a reconnect.

**Tech Stack:** Flutter, Dart, Drift (local cache database), Riverpod,
SharedPreferences, flutter gen-l10n (11 locales).

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`,
section 7.1. Harness seeds: `test/features/media/two_device/store_scenarios_test.dart`
(S8, S10).

## Global Constraints

- No em-dashes (U+2014) anywhere, and no en-dashes or spaced hyphens as
  prose punctuation, in code, comments, docs, commits or PR text.
- No mention of Claude, Claude Code or Anthropic in anything written to the
  repository or GitHub.
- No emojis in code, comments or docs.
- `dart format .` before every commit; `flutter analyze` must report no
  issues (infos are fatal in CI).
- Every new user-facing string goes into all 11 ARB files
  (`lib/l10n/arb/app_*.arb`), translated; only `app_en.arb` is kept
  alphabetical, the others are feature-grouped (insert next to a
  neighbouring key). Regenerate with `flutter gen-l10n`.
- Platform-agnostic paths only (`p.join`, never a literal `/tmp`).
- PR body: `Closes #2126` and `Part of #2090`.

## Decisions (from the user, 2026-09-23)

1. **Preflight throw:** a throw while the device is offline defers quietly
   (hold kind `offline`, no suspended notice). Any other throw suspends the
   worker with a reason (hold kind `storeUnreachable`). S8 stays as written.
2. **Marker mismatch card:** ships in this slice as a new
   `SetupItemKind.mediaStoreReconnect`. The spec's "epoch failure" wording is
   dropped: no epoch concept exists in the media store code.

## File Structure

| File | Change |
| --- | --- |
| `lib/features/media_store/domain/media_transfer_hold.dart` | Create: `MediaTransferHoldKind`, `MediaTransferHold` |
| `lib/features/media_store/domain/media_transfer_summary.dart` | Add `hold`; `waitingReason` prefers the hold's message |
| `lib/features/media_store/data/media_transfer_queue_repository.dart` | Leases (`holdWhile`), lease-aware `requeueStale`, `hasOutstandingWork`, `fail`, `defer(reason:)`, hold board (`recordHold`, `currentHold`), merged `watchSummary` |
| `lib/features/media_store/data/media_store_worker.dart` | Reclaim per drain, leases around work, verdict preflight, `isOffline`, holds, budget reason, delete-without-processor fails |
| `lib/features/media_store/data/media_store_preflight.dart` | `check()` verdict; persists marker mismatch |
| `lib/core/services/media_store/media_store_attach_state.dart` | Marker mismatch flag |
| `lib/core/services/accounts/pending_setup_service.dart` | `SetupItemKind.mediaStoreReconnect` |
| `lib/features/settings/presentation/widgets/pending_setup_card.dart` | Render the reconnect item |
| `lib/features/media_store/presentation/providers/media_store_providers.dart` | Drop the once-per-process reclaim provider; resume gate on outstanding work; wire `isOffline` and `check` |
| `lib/features/media_store/presentation/widgets/media_transfers_suspended_notice.dart` | Subtitle names the hold |
| `lib/features/media_store/presentation/widgets/media_transfer_summary_row.dart` | Offline line |
| `lib/l10n/arb/app_*.arb` | 4 new keys |
| `test/helpers/two_device_media_harness.dart` | Preflight type |
| `test/features/media/two_device/store_scenarios_test.dart` | Unskip S8, S10 |
| `docs/superpowers/specs/2026-09-18-media-sync-program-design.md` | Amend 7.1 |

---

### Task 1: Leases, and a reclaim on every drain (S10)

**Files:**
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart`
- Modify: `lib/features/media_store/data/media_store_worker.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart:89-112,518-526`
- Delete: `test/features/media_store/media_transfer_queue_reclaim_provider_test.dart`
- Create: `test/features/media_store/media_transfer_queue_lease_test.dart`
- Modify: `test/features/media/two_device/store_scenarios_test.dart` (unskip S10)

**Interfaces:**
- Produces: `Future<T> MediaTransferQueueRepository.holdWhile<T>(int id, Future<T> Function() work)`;
  `requeueStale()` now skips held ids; `MediaStoreWorker.drain()` reclaims first.

Why leases: the once-per-process reclaim provider exists because a rebuilt
runtime's worker could otherwise flip a row a superseded worker is still
uploading. A lease names exactly the rows some worker in this process is
running, so a reclaim that skips them is safe at any time, and moving it into
`drain` (spec 7.1) covers resume and rebuild as well as launch. Leases are
keyed on the database object through an `Expando`, so every repository
instance over the same database shares them (production builds three) while
the harness's two devices, each with its own database, do not.

- [ ] **Step 1: Write the failing tests**

`test/features/media_store/media_transfer_queue_lease_test.dart`:

```dart
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  test('reclaim returns a stranded transferring row to pending', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markTransferring(id);
    expect(await repo.nextPending(DateTime.now()), isNull);

    expect(await repo.requeueStale(), 1);

    expect((await repo.allForTesting()).single.state, 'pending');
  });

  test('reclaim leaves a row a worker still holds', () async {
    // A rebuilt runtime's worker reclaims on its first drain while the
    // superseded worker may still be uploading. Another repository over the
    // same database stands in for that second worker.
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final release = Completer<void>();
    final held = repo.holdWhile(id, () async {
      await repo.markTransferring(id);
      await release.future;
    });
    await pumpEventQueue();

    expect(await MediaTransferQueueRepository(database: db).requeueStale(), 0);
    expect((await repo.allForTesting()).single.state, 'transferring');

    release.complete();
    await held;
    expect(await repo.requeueStale(), 1, reason: 'released once it settles');
  });

  test('a lease on one database does not cover another', () async {
    final other = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final otherRepo = MediaTransferQueueRepository(database: other);
    final id = await otherRepo.enqueueUpload(mediaId: 'm1');
    await otherRepo.markTransferring(id);
    final release = Completer<void>();
    final held = repo.holdWhile(id, () => release.future);

    expect(await otherRepo.requeueStale(), 1);

    release.complete();
    await held;
  });

  test('two holders of one id keep it held until both settle', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    await repo.markTransferring(id);
    final first = Completer<void>();
    final second = Completer<void>();
    final a = repo.holdWhile(id, () => first.future);
    final b = repo.holdWhile(id, () => second.future);

    first.complete();
    await a;
    expect(await repo.requeueStale(), 0);

    second.complete();
    await b;
    expect(await repo.requeueStale(), 1);
  });
}
```

Worker tests, appended to `test/features/media_store/media_store_worker_budget_test.dart`
(read its setup first and reuse its queue, pipeline fake and budget helpers):

```dart
  test('a drain reclaims a row stranded in transferring', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.markTransferring(id); // a previous process died here

    await worker.drain();

    expect(processed, ['m1'], reason: 'reclaimed, then taken by the drain');
  });

  test('a drain does not reclaim the row a timed-out transfer still runs',
      () async {
    // The budget stops the drain waiting, not the transfer. A second drain
    // must not flip that row back to pending and run it twice.
    ... build a worker whose pipeline marks the row transferring and then
    waits on a Completer, with a 1ms entryBudget ...
    await worker.drain(); // times out, moves on
    await worker.drain(); // reclaims at start
    expect((await queue.allForTesting()).single.state, 'transferring');
    expect(starts, 1);
    release.complete();
  });
```

The executor fills the `...` from the file's existing fakes: the second test
needs a pipeline fake that calls `queue.markTransferring(entry.id)`, bumps a
`starts` counter, then awaits a `Completer`. Name each fake exactly as the
file already does.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media_store/media_transfer_queue_lease_test.dart test/features/media_store/media_store_worker_budget_test.dart`
Expected: compile failure, `holdWhile` is not defined.

- [ ] **Step 3: Implement leases in the repository**

In `MediaTransferQueueRepository`, below the constructor:

```dart
  /// Entries some worker in this process is running, per database, counted
  /// so two overlapping holders of one id (a budget-expired transfer that
  /// never reached markTransferring, then picked up again) keep it held
  /// until both settle. Keyed on the database object, so every repository
  /// over one database shares them and two databases never do.
  static final Expando<Map<int, int>> _leases = Expando('media queue leases');

  Map<int, int> get _held => _leases[_db] ??= <int, int>{};

  /// Runs [work] with [id] leased: [requeueStale] leaves the row alone until
  /// [work] settles. The lease outlives any timeout a caller puts on the
  /// returned future, which is the point: a timed-out transfer keeps running
  /// and still owns its row.
  Future<T> holdWhile<T>(int id, Future<T> Function() work) async {
    final held = _held;
    held[id] = (held[id] ?? 0) + 1;
    try {
      return await work();
    } finally {
      final left = (held[id] ?? 1) - 1;
      if (left <= 0) {
        held.remove(id);
      } else {
        held[id] = left;
      }
    }
  }
```

Replace the `requeueStale` doc's second paragraph ("Callers MUST invoke
this only when no transfer is actively running: ...") with:

```dart
  /// Safe to run at any time: rows a worker in this process holds through
  /// [holdWhile] are skipped, so only a row no live transfer owns (its
  /// process died, or its worker was never started) is reclaimed. The worker
  /// runs this at the start of every drain.
```

and change its WHERE to:

```dart
    )..where((t) {
      final held = _held.keys.toList();
      final stranded = t.state.equals('transferring');
      return held.isEmpty ? stranded : stranded & t.id.isNotIn(held);
    })).write(
```

- [ ] **Step 4: Reclaim in `drain`, lease every entry**

In `MediaStoreWorker.drain`, first statement inside the `try`:

```dart
      // Rows a dead process or a superseded worker left in 'transferring'
      // are invisible to nextPending. Leases keep this off any row a live
      // transfer in this process owns, so it runs on every drain: launch,
      // resume and rebuild alike (spec 7.1).
      await _reclaimStranded();
```

and the helper, next to `_withinBudget`:

```dart
  /// Never throws: a failed reclaim leaves the stranded rows for the next
  /// drain, and must not stop this one taking the rows that are due.
  Future<void> _reclaimStranded() async {
    try {
      final reclaimed = await _queue.requeueStale();
      if (reclaimed > 0) {
        _log.info('Reclaimed $reclaimed stranded transfer(s)');
      }
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Could not reclaim stranded transfers',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
```

In `_withinBudget`, replace `await work().timeout(_entryBudget);` with
`await _queue.holdWhile(entry.id, work).timeout(_entryBudget);` and add to
its doc: "The lease taken here outlives the timeout, so a later drain's
reclaim leaves that row to the transfer still running it."

- [ ] **Step 5: Drop the once-per-process provider**

In `media_store_providers.dart`, delete `mediaTransferQueueReclaimProvider`
and its doc (lines 89-112), delete the `await ref.read(mediaTransferQueueReclaimProvider.future);`
and the comment above it (lines 518-526), and in the
`mediaCacheEvictionProvider` doc replace "Cached like
[mediaTransferQueueReclaimProvider] so a runtime rebuild does not repeat it.
Unlike that one it is deliberately NOT awaited by the runtime: reclaim must
precede any drain for correctness, whereas eviction is housekeeping and must
never delay one." with "Cached so a runtime rebuild does not repeat it, and
deliberately NOT awaited by the runtime: eviction is housekeeping and must
never delay a drain." Delete
`test/features/media_store/media_transfer_queue_reclaim_provider_test.dart`
(its first case moved to the lease test; its second asserted the behaviour
leases replace).

- [ ] **Step 6: Unskip S10**

Remove the `skip:` argument from S10 in `store_scenarios_test.dart`.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/media_store test/features/media/two_device`
Expected: PASS, S10 included.

- [ ] **Step 8: Commit**

```bash
git add lib/features/media_store test/features/media_store test/features/media/two_device/store_scenarios_test.dart
git commit -m "fix(media-store): every drain reclaims stranded rows, leases keep live ones"
```

---

### Task 2: The resume gate wakes a queue with any outstanding work

**Files:**
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart:226-269`
- Test: `test/features/media_store/media_transfer_resume_provider_test.dart`

**Interfaces:**
- Produces: `Future<bool> MediaTransferQueueRepository.hasOutstandingWork()`.

A queue holding only deferred rows, or only rows stranded in
`transferring`, answers null to `nextPending`, so the resume gate never
built the runtime: no drain to reclaim the stranded rows, no worker to arm a
wakeup for the deferred ones.

- [ ] **Step 1: Write the failing tests**

In `media_transfer_resume_provider_test.dart`, replace the test that
asserts a deferred-only queue does NOT build the runtime (the one under the
"A row parked behind markFailed's backoff" comment) with:

```dart
  // A deferred row has no trigger but the worker's wakeup, and the worker
  // exists only once the runtime is built (spec 7.1).
  test('a queue holding only deferred rows builds the runtime', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.defer(id, DateTime.now().add(const Duration(hours: 25)));
    final harness = buildContainer(attached: true);

    await harness.container.read(mediaTransferResumeProvider)();

    expect(harness.builds, hasLength(1));
  });

  // A row stranded in transferring is reclaimed only by a drain.
  test('a queue holding only a stranded row builds the runtime', () async {
    final id = await queue.enqueueUpload(mediaId: 'm1');
    await queue.markTransferring(id);
    final harness = buildContainer(attached: true);

    await harness.container.read(mediaTransferResumeProvider)();

    expect(harness.builds, hasLength(1));
  });

  test('a queue of finished and failed rows does not build it', () async {
    final done = await queue.enqueueUpload(mediaId: 'm1');
    await queue.markDone(done);
    final failed = await queue.enqueueUpload(mediaId: 'm2');
    await queue.fail(failed, 'gone');
    final harness = buildContainer(attached: true);

    await harness.container.read(mediaTransferResumeProvider)();

    expect(harness.builds, isEmpty);
  });
```

(`fail` arrives in Task 4; until then write the failed row with
`markFailed` five times. Task 4 swaps it.)

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/media_store/media_transfer_resume_provider_test.dart`
Expected: FAIL, `builds` is empty for the deferred and stranded cases.

- [ ] **Step 3: Implement**

Repository:

```dart
  /// Whether any row is still outstanding: pending (due or deferred) or
  /// stranded in transferring. The resume gate's question, because each of
  /// those needs a built runtime to move: a drain to take or reclaim it, or
  /// the worker's wakeup to come back for it.
  Future<bool> hasOutstandingWork() async {
    final row =
        await (_db.select(_db.mediaTransferQueue)
              ..where((t) => t.state.isIn(['pending', 'transferring']))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }
```

Provider: replace `if (await queue.nextPending(DateTime.now()) == null) return;`
with `if (!await queue.hasOutstandingWork()) return;`, and in the doc
replace from "[MediaTransferQueueRepository.nextPending] is one indexed
local read" to the end of that paragraph with:

```dart
/// [MediaTransferQueueRepository.hasOutstandingWork] is one local read that
/// means "some row still needs a runtime": a due row for the drain, a row
/// stranded in transferring for its reclaim, or a deferred row for the
/// worker's wakeup (spec 7.1). Finished and failed rows need nothing.
```

- [ ] **Step 4: Run to verify they pass**, same command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store test/features/media_store/media_transfer_resume_provider_test.dart
git commit -m "fix(media-store): resume wakes a queue holding only deferred or stranded rows"
```

---

### Task 3: Holds reach the summary

**Files:**
- Create: `lib/features/media_store/domain/media_transfer_hold.dart`
- Modify: `lib/features/media_store/domain/media_transfer_summary.dart`
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart`
- Test: `test/features/media_store/media_transfer_summary_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum MediaTransferHoldKind { offline, storeUnreachable, detached, markerMismatch }
  class MediaTransferHold {
    const MediaTransferHold(this.kind, this.message);
    final MediaTransferHoldKind kind;
    final String message; // diagnostic English, shown raw like row errors
    bool get suspends => kind != MediaTransferHoldKind.offline;
  }
  void MediaTransferQueueRepository.recordHold(MediaTransferHold? hold);
  MediaTransferHold? MediaTransferQueueRepository.currentHold;
  MediaTransferSummary.hold; // null when nothing holds the drain
  ```

A suspended drain leaves its rows untouched, so the rows cannot carry the
reason. The hold lives beside the leases (per database, in memory): it
describes this process's worker, it dies with the process, and the next
drain re-derives it.

- [ ] **Step 1: Write the failing tests** (append to `media_transfer_summary_test.dart`,
reusing its database setup)

```dart
  test('a hold names why due work is not moving', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    const hold = MediaTransferHold(
      MediaTransferHoldKind.storeUnreachable,
      'Could not check the media store: marker unreadable',
    );

    queue.recordHold(hold);
    final summary = await queue.watchSummary().first;

    expect(summary.hold, hold);
    expect(summary.waitingReason, hold.message);
  });

  test('recording or clearing a hold re-emits the summary', () async {
    await queue.enqueueUpload(mediaId: 'm1');
    final seen = <MediaTransferHold?>[];
    final sub = queue.watchSummary().listen((s) => seen.add(s.hold));
    await pumpEventQueue();

    queue.recordHold(
      const MediaTransferHold(MediaTransferHoldKind.offline, 'Offline'),
    );
    await pumpEventQueue();
    queue.recordHold(null);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen.map((h) => h?.kind), [
      null,
      MediaTransferHoldKind.offline,
      null,
    ]);
  });

  test('another repository over the same database sees the hold', () async {
    // Production's worker and the summary provider hold different instances.
    queue.recordHold(
      const MediaTransferHold(MediaTransferHoldKind.detached, 'Detached'),
    );

    expect(
      MediaTransferQueueRepository(database: db).currentHold?.kind,
      MediaTransferHoldKind.detached,
    );
    queue.recordHold(null);
  });
```

- [ ] **Step 2: Run to verify they fail** (compile failure: no `MediaTransferHold`).

- [ ] **Step 3: Implement**

`media_transfer_hold.dart`:

```dart
/// Why the media transfer drain stopped with work left behind.
enum MediaTransferHoldKind {
  /// No network. Quiet: the queue says it is waiting for a connection and
  /// does not report a suspension, because nothing is wrong with the store.
  offline,

  /// Online, but the store could not be checked (the marker read threw or
  /// timed out). Suspends with the error, retried on the preflight window.
  storeUnreachable,

  /// This device is no longer attached to the store the worker was built
  /// for.
  detached,

  /// The store no longer carries the marker this device attached to: wiped
  /// and re-minted, or repointed. Needs the user to reconnect.
  markerMismatch,
}

/// The one reason the drain is holding, recorded by the worker and read by
/// the summary (spec 7.1: the queue never waits silently).
class MediaTransferHold {
  const MediaTransferHold(this.kind, this.message);

  final MediaTransferHoldKind kind;

  /// Diagnostic English, shown raw the way row errors are: the surfaces
  /// localize by [kind] and show this beneath.
  final String message;

  /// Whether this hold is a suspension the user is told about. Offline is
  /// not: an ordinary moment without network must not read as a broken
  /// store.
  bool get suspends => kind != MediaTransferHoldKind.offline;

  @override
  bool operator ==(Object other) =>
      other is MediaTransferHold &&
      other.kind == kind &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() => 'MediaTransferHold($kind, $message)';
}
```

`MediaTransferSummary`: add `final MediaTransferHold? hold;` with doc "Why
the drain is holding, when it is. Due rows stay 'queued' under a hold: they
are not deferred, only waiting for the drain to be allowed to run.", a
`this.hold` constructor parameter, and include `hold` in `==`, `hashCode`
and `toString`. Rewrite the `waitingReason` doc to: "Why work is not
moving: the hold's message when the drain is holding, else the most
recently recorded failure among the [waiting] rows. Null when neither
applies (a cellular hold consumes no attempt and records no error)."

Repository, beside the leases:

```dart
  static final Expando<_HoldBoard> _boards = Expando('media queue holds');

  _HoldBoard get _board => _boards[_db] ??= _HoldBoard();

  /// Why the drain over this database is holding, or null when it is not.
  MediaTransferHold? get currentHold => _board.hold;

  /// Records (or, with null, clears) the drain's hold. Every repository over
  /// this database sees it, and every open [watchSummary] re-emits.
  void recordHold(MediaTransferHold? hold) => _board.set(hold);
```

and at the end of the file:

```dart
class _HoldBoard {
  MediaTransferHold? hold;
  final _changes = StreamController<void>.broadcast(sync: true);

  Stream<void> get changes => _changes.stream;

  void set(MediaTransferHold? next) {
    if (next == hold) return;
    hold = next;
    _changes.add(null);
  }
}
```

(`import 'dart:async';` and the hold import at the top.) Replace
`watchSummary`'s body:

```dart
    final clock = now ?? DateTime.now;
    final query = _db.select(_db.mediaTransferQueue)
      ..where((t) => t.state.isIn(['pending', 'transferring']));
    final board = _board;
    return Stream.multi((controller) {
      List<MediaTransferQueueEntry>? rows;
      void emit() {
        final current = rows;
        if (current != null) {
          controller.add(_summarize(current, clock(), board.hold));
        }
      }

      final rowSub = query.watch().listen((next) {
        rows = next;
        emit();
      }, onError: controller.addError);
      final holdSub = board.changes.listen((_) => emit());
      controller.onCancel = () async {
        await holdSub.cancel();
        await rowSub.cancel();
      };
    });
```

and give `_summarize` a third parameter `MediaTransferHold? hold`, passing
`hold: hold` and `waitingReason: hold?.message ?? reason`. Add to the
`watchSummary` doc: "A change of hold re-emits too, with no row written."

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/media_store`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store test/features/media_store/media_transfer_summary_test.dart
git commit -m "feat(media-store): the transfer summary says why the drain is holding"
```

---

### Task 4: The worker records every stop (S8)

**Files:**
- Modify: `lib/features/media_store/data/media_store_worker.dart`
- Modify: `lib/features/media_store/data/media_transfer_queue_repository.dart` (`fail`, `defer(reason:)`)
- Modify: `test/helpers/two_device_media_harness.dart`
- Modify: every test passing `preflight:` (`media_store_worker_budget_test.dart`,
  `media_transfers_suspended_provider_test.dart`, `media_store_end_to_end_test.dart`,
  `media_store_worker_preflight_test.dart`, `media_store_worker_wakeup_test.dart`)
- Modify: `test/features/media/two_device/store_scenarios_test.dart` (unskip S8)

**Interfaces:**
- Consumes: `MediaTransferHold`, `recordHold` (Task 3); `holdWhile` (Task 1).
- Produces: `MediaStoreWorker({..., Future<MediaTransferHoldKind?> Function()? preflight, Future<bool> Function()? isOffline, ...})`;
  a null verdict admits. `Future<void> MediaTransferQueueRepository.fail(int id, String error)`;
  `Future<void> defer(int id, DateTime until, {String? reason})`.

- [ ] **Step 1: Migrate the preflight type in tests (mechanical)**

Across the files listed above: `preflight: () async => true` becomes
`preflight: () async => null`; `preflight: () async => false` becomes
`preflight: () async => MediaTransferHoldKind.markerMismatch`; closures that
return a bool variable return `ok ? null : MediaTransferHoldKind.markerMismatch`.
Add `import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';`
where needed. In the harness, `late Future<bool> Function() preflight;`
becomes `late Future<MediaTransferHoldKind?> Function() preflight;` and
the default is `MediaStorePreflight(...).check` (Task 5 adds `check`; until
then `() async => await p.call() ? null : MediaTransferHoldKind.markerMismatch`).

Tests that assert a throwing preflight leaves `isSuspended` false are
about being offline: give their worker `isOffline: () async => true`, and
rename each to say "while offline". Add the online twin:

```dart
  test('a preflight that throws while online suspends with its reason',
      () async {
    final worker = MediaStoreWorker(
      queue: queue,
      pipeline: pipeline,
      preflight: () async =>
          throw const MediaStoreException('marker unreadable'),
      isOffline: () async => false,
    );
    await queue.enqueueUpload(mediaId: 'm1');

    await worker.drain();

    expect(worker.isSuspended, isTrue);
    expect(queue.currentHold?.kind, MediaTransferHoldKind.storeUnreachable);
    expect(queue.currentHold?.message, contains('marker unreadable'));
  });

  test('a preflight that throws while offline holds quietly', () async {
    ... same, isOffline: () async => true ...
    expect(worker.isSuspended, isFalse);
    expect(queue.currentHold?.kind, MediaTransferHoldKind.offline);
  });

  test('a refusal suspends and names its kind', () async {
    ... preflight: () async => MediaTransferHoldKind.detached ...
    expect(worker.isSuspended, isTrue);
    expect(queue.currentHold?.kind, MediaTransferHoldKind.detached);
  });

  test('a preflight that passes clears the hold', () async {
    var verdict = MediaTransferHoldKind.markerMismatch as MediaTransferHoldKind?;
    ... preflight: () async => verdict ...
    await worker.drain();
    verdict = null;
    await worker.drain();
    expect(worker.isSuspended, isFalse);
    expect(queue.currentHold, isNull);
  });

  test('a gate that stops for offline records an offline hold', () async {
    ... gate: (_) async => WorkerGate.stopDraining ...
    expect(queue.currentHold?.kind, MediaTransferHoldKind.offline);
  });

  test('dispose clears the hold it recorded', () async {
    ... refusal drain, then worker.dispose() ...
    expect(queue.currentHold, isNull);
  });
```

In `media_store_worker_budget_test.dart`:

```dart
  test('a budget expiry leaves a reason on the entry', () async {
    ... the existing never-completing pipeline, 1ms budget ...
    await worker.drain();
    expect(
      (await queue.allForTesting()).single.errorMessage,
      contains('budget'),
    );
  });

  test('a delete entry with no processor is failed with a message', () async {
    await queue.enqueueDelete(
      mediaId: 'm1',
      contentHash: 'h',
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    await worker.drain(); // built with no deleteProcessor
    final row = (await queue.allForTesting()).single;
    expect(row.state, 'failed');
    expect(row.errorMessage, isNotNull);
  });
```

Every `...` is filled from the fakes already in the file being edited.
Remove the `skip:` from S8.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/media_store test/features/media/two_device`
Expected: compile failure (`isOffline`, `fail`, verdict type).

- [ ] **Step 3: Implement the repository verbs**

```dart
  /// Fails [id] terminally with [error], no attempt counted: for an entry
  /// this device can never process, where a retry ladder would only burn
  /// time. The Transfers page's Retry is the way back in.
  Future<void> fail(int id, String error) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: const Value('failed'),
        nextAttemptAt: const Value(null),
        errorMessage: Value(error),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
```

`defer` gains `{String? reason}`; when non-null it also writes
`errorMessage: Value(reason)`. Doc: "[reason] is written as the entry's
error when given, so a postponement the user should know about (a budget
expiry) is not silent; a policy deferral passes none."

- [ ] **Step 4: Implement the worker**

Constructor: `Future<MediaTransferHoldKind?> Function()? preflight` and a
new `Future<bool> Function()? isOffline`, stored as `_isOffline`, doc:
"Asked only when the preflight throws, to tell an offline moment (a quiet
hold) from a store that cannot be checked (a suspension). Null reads as
online. A throw from it reads as online too: the reason then shows, which is
the safer mistake." Update the `_preflight` field doc to "Returns null to
admit the drain, or the kind of refusal that suspends it (spec section 13)."

Replace `_preflightPasses`:

```dart
  Future<bool> _preflightPasses() async {
    final preflight = _preflight;
    if (preflight == null) return true;
    try {
      final refusal = await preflight().timeout(_preflightBudget);
      if (refusal == null) {
        _hold(null);
        return true;
      }
      _log.warning('Media store preflight refused ($refusal); drain suspended');
      _hold(MediaTransferHold(refusal, _refusalMessages[refusal]!));
    } on Object catch (e, stackTrace) {
      if (await _offline()) {
        _log.info('Media store preflight could not run while offline');
        _hold(const MediaTransferHold(MediaTransferHoldKind.offline, 'Offline'));
      } else {
        _log.warning(
          'Media store preflight could not run; drain suspended',
          error: e,
          stackTrace: stackTrace,
        );
        _hold(
          MediaTransferHold(
            MediaTransferHoldKind.storeUnreachable,
            'Could not check the media store: $e',
          ),
        );
      }
    }
    return false;
  }

  static const _refusalMessages = {
    MediaTransferHoldKind.offline: 'Offline',
    MediaTransferHoldKind.storeUnreachable: 'Could not check the media store',
    MediaTransferHoldKind.detached:
        'This device is no longer attached to this media store',
    MediaTransferHoldKind.markerMismatch:
        'The media store no longer carries the marker this device attached to',
  };

  Future<bool> _offline() async {
    final isOffline = _isOffline;
    if (isOffline == null) return false;
    try {
      return await isOffline();
    } on Object {
      return false;
    }
  }

  /// Records [hold] on the queue and mirrors its suspension into
  /// [isSuspended].
  void _hold(MediaTransferHold? hold) {
    _queue.recordHold(hold);
    _setSuspended(hold?.suspends ?? false);
  }
```

Rewrite the `_preflightPasses` doc to describe the three outcomes (admit,
refusal suspends with its kind, throw: offline holds quietly, otherwise
suspends as storeUnreachable) and keep the existing paragraphs on #942,
#1270 and logging the error with its stack.

In `drain`: on `WorkerGate.stopDraining`, before `break`, call
`_hold(const MediaTransferHold(MediaTransferHoldKind.offline, 'Offline'));`.
The delete-without-processor branch becomes:

```dart
          if (deleteProcessor == null) {
            // This device can never process it, and a deferral only hid
            // that behind a retry that could not succeed (spec 7.1).
            await _queue.fail(
              entry.id,
              'No delete processor on this device; retry once it has one',
            );
            continue;
          }
```

In `_withinBudget`'s catch, pass
`reason: 'Took longer than ${_entryBudget.inMinutes}m; its budget ran out, '
'retrying later'` (the test matches `budget`).

`dispose()`: before closing the stream, clear the hold if it is still this
worker's: record `null` only when `_suspended || _queue.currentHold != null`
was set by this worker. Track it with a `bool _holding` set in `_hold`
(`_holding = hold != null`), and in `dispose` call
`if (_holding) _queue.recordHold(null);`.

Production wiring (`media_store_providers.dart`): `preflight: preflight.check`
(Task 5) and
`isOffline: () async => await network.current() == NetworkKind.offline`.
Until Task 5, wire `preflight: () async => await preflight.call() ? null : MediaTransferHoldKind.markerMismatch`.

- [ ] **Step 5: Run to verify they pass**

Run: `flutter test test/features/media_store test/features/media/two_device`
Expected: PASS, S8 included.

- [ ] **Step 6: Commit**

```bash
git add lib/features/media_store test/features/media_store test/helpers/two_device_media_harness.dart test/features/media/two_device/store_scenarios_test.dart
git commit -m "feat(media-store): every drain stop records why, and a throw suspends unless offline"
```

---

### Task 5: The preflight names its refusal, and a mismatch asks for a reconnect

**Files:**
- Modify: `lib/features/media_store/data/media_store_preflight.dart`
- Modify: `lib/core/services/media_store/media_store_attach_state.dart`
- Modify: `lib/core/services/accounts/pending_setup_service.dart`
- Modify: `lib/features/settings/presentation/widgets/pending_setup_card.dart`
- Modify: `lib/features/media_store/presentation/widgets/media_transfers_suspended_notice.dart`
- Modify: `lib/features/media_store/presentation/widgets/media_transfer_summary_row.dart`
- Modify: `lib/features/media_store/presentation/providers/media_store_providers.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/features/media_store/media_store_preflight_test.dart` (create if absent),
  `test/core/services/accounts/pending_setup_service_test.dart`,
  `test/features/media_store/media_storage_page_transfer_summary_test.dart`

**Interfaces:**
- Produces: `Future<MediaTransferHoldKind?> MediaStorePreflight.check()`;
  `MediaStoreAttachState.setMarkerMismatch(bool)`, `hasMarkerMismatch()`;
  `SetupItemKind.mediaStoreReconnect`.

- [ ] **Step 1: Write the failing tests**

Preflight (fake `MediaObjectStore` and in-memory prefs, following whatever
the existing media store tests use to seed a marker; grep
`StoreMarkerStore(` under `test/` for the helper):

```dart
  test('a missing attachment is detached', ...
    expect(await preflight.check(), MediaTransferHoldKind.detached));
  test('another attachment is detached', ...);
  test('a marker for another store is a mismatch, and is remembered', () async {
    ... marker storeId 'other' ...
    expect(await preflight.check(), MediaTransferHoldKind.markerMismatch);
    expect(await attach.hasMarkerMismatch(), isTrue);
  });
  test('a missing marker is a mismatch', ...);
  test('a matching marker admits and forgets a mismatch', () async {
    await attach.setMarkerMismatch(true);
    ... matching marker ...
    expect(await preflight.check(), isNull);
    expect(await attach.hasMarkerMismatch(), isFalse);
  });
  test('an unreadable marker throws, remembering nothing', ...);
```

Attach state: `setAttached` and `clear` both forget the mismatch (a
reconnect is the fix).

Pending setup:

```dart
  test('a remembered marker mismatch offers a reconnect', () async {
    ... active descriptor 's1' with displayHint 'bucket @ host', attached 's1',
    await attach.setMarkerMismatch(true);
    final items = await service.compute();
    expect(items.single.kind, SetupItemKind.mediaStoreReconnect);
    expect(items.single.key, 'store_marker_s1');
    expect(items.single.label, 'bucket @ host');
    expect(items.single.route, '/settings/media-storage');
  });
  test('a dismissed reconnect stays dismissed', ...);
```

Widgets (in `media_storage_page_transfer_summary_test.dart`, overriding
`mediaTransferSummaryProvider` and `mediaTransfersSuspendedProvider` as the
file already does):

```dart
  testWidgets('a detached hold says so in the notice', ...
    expect(find.text(l10n.settings_mediaStorage_transfers_suspended_detached),
        findsOneWidget));
  testWidgets('an unreachable hold shows its message', ...
    expect(find.textContaining('marker unreadable'), findsOneWidget));
  testWidgets('an offline hold shows a waiting line, no notice', ...
    expect(find.byKey(const Key('media-transfers-suspended')), findsNothing);
    expect(find.text(l10n.settings_mediaStorage_transfers_waitingConnection),
        findsOneWidget));
```

- [ ] **Step 2: Run to verify they fail** (compile failures).

- [ ] **Step 3: Implement**

Attach state:

```dart
  static const String markerMismatchKey = 'media_store_marker_mismatch';

  /// Records whether the last preflight found the attached store carrying
  /// another store's marker, or none. Persisted so the pending-setup card
  /// can offer a reconnect without a runtime; cleared by any attach change,
  /// since reconnecting is the fix.
  Future<void> setMarkerMismatch(bool mismatch) async {
    final prefs = await _resolved;
    if (mismatch) {
      await prefs.setBool(markerMismatchKey, true);
    } else {
      await prefs.remove(markerMismatchKey);
    }
  }

  Future<bool> hasMarkerMismatch() async =>
      (await _resolved).getBool(markerMismatchKey) ?? false;
```

and `await prefs.remove(markerMismatchKey);` in `setAttached` and `clear`.

Preflight:

```dart
  /// Null when the drain may proceed, else why it may not. Throws when the
  /// marker cannot be read; the worker separates that from a refusal.
  Future<MediaTransferHoldKind?> check() async {
    final currentId = await _attachState.attachedStoreId();
    if (currentId == null || currentId != _attachedStoreId) {
      return MediaTransferHoldKind.detached;
    }
    final marker = await StoreMarkerStore(store: _store).read();
    final mismatch = marker == null || marker.storeId != currentId;
    await _attachState.setMarkerMismatch(mismatch);
    return mismatch ? MediaTransferHoldKind.markerMismatch : null;
  }

  /// Whether the drain may proceed. Kept for callers that need only that.
  Future<bool> call() async => await check() == null;
```

Pending setup: `enum SetupItemKind { mediaStoreAttach, mediaStoreReconnect, accountSignIn }`;
in `compute()`, after the attach block:

```dart
    // Attached to the announced store, but the store no longer carries the
    // marker this device attached to (the preflight remembered it). The
    // queue is suspended until the user reconnects (spec 7.1).
    if (store != null &&
        attachedId == store.id &&
        await _attachState.hasMarkerMismatch()) {
      final key = 'store_marker_${store.id}';
      if (!_isDismissed(key)) {
        items.add(
          PendingSetupItem(
            kind: SetupItemKind.mediaStoreReconnect,
            key: key,
            label: store.displayHint,
            route: '/settings/media-storage',
          ),
        );
      }
    }
```

Update the `label` doc to include the reconnect kind. Card: icon
`Icons.sync_problem_outlined` for `mediaStoreReconnect` (switch expression
on `item.kind`), title
`SetupItemKind.mediaStoreReconnect => l10n.settings_setup_mediaStoreReconnect(item.label)`.

Notice: keep `mediaTransfersSuspendedProvider` as the show/hide switch, and
read `ref.watch(mediaTransferSummaryProvider).value?.hold` for the text:

```dart
    final hold = ref.watch(mediaTransferSummaryProvider).value?.hold;
    final subtitle = switch (hold?.kind) {
      MediaTransferHoldKind.detached =>
        l10n.settings_mediaStorage_transfers_suspended_detached,
      MediaTransferHoldKind.storeUnreachable =>
        '${l10n.settings_mediaStorage_transfers_suspended_unreachable}\n'
            '${hold!.message}',
      _ => l10n.settings_mediaStorage_transfers_suspended_subtitle,
    };
```

(the existing subtitle already describes a marker mismatch). Update the
class doc: the notice names the hold, the raw message is not localized for
the same reason row errors are not.

Summary row: when `summary.hold?.kind == MediaTransferHoldKind.offline` and
`summary.queued > 0`, render under the queued line a
`Text(l10n.settings_mediaStorage_transfers_waitingConnection, key: const Key('media-transfer-offline'), style: theme.textTheme.bodySmall)`
in the same padding as `media-transfer-queued`.

Providers: `preflight: preflight.check`.

ARB keys (`app_en.arb`, alphabetical; the other 10 files beside their
neighbours `settings_mediaStorage_transfers_suspended_subtitle`,
`settings_mediaStorage_transfers_waitingRetry` and
`settings_setup_mediaStoreAttach`), each with a description:

| Key | English |
| --- | --- |
| `settings_mediaStorage_transfers_suspended_detached` | This device is no longer connected to this media store. Connect it again in Media Storage. |
| `settings_mediaStorage_transfers_suspended_unreachable` | The media store could not be checked. Transfers retry automatically. |
| `settings_mediaStorage_transfers_waitingConnection` | Waiting for a connection |
| `settings_setup_mediaStoreReconnect` | Reconnect media storage ({hint}) |

`settings_setup_mediaStoreReconnect` carries a `hint` placeholder of type
`String`, like `settings_setup_mediaStoreAttach`. Translate into ar, de, es,
fr, he, hu, it, nl, pt, zh. Run `flutter gen-l10n`.

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/features/media_store test/core/services/accounts test/features/settings test/features/media/two_device`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(media-store): a marker mismatch offers a reconnect, and the notice names each hold"
```

---

### Task 6: Spec, full verification

**Files:**
- Modify: `docs/superpowers/specs/2026-09-18-media-sync-program-design.md` (7.1)

- [ ] **Step 1: Amend 7.1**

Replace the first bullet with: "A preflight throw while offline holds the
queue quietly with a 'waiting for a connection' reason; any other throw
records a suspension with the error as its reason. The Transfers page and
the Media Storage summary row show the existing suspended notice, naming
the reason; the retry window is armed as today." Replace the fourth bullet
with: "Stranded `transferring` rows are reclaimed at the start of every
drain. Leases on the entries a worker is running keep the reclaim off a
transfer still in flight, which is what made the once-per-process reclaim
necessary." Replace the fifth with "The resume gate builds the runtime for
any outstanding row: due, deferred, or stranded." Replace the last with "A
marker mismatch (another store's marker, or none) raises a pending-setup
card with a one-tap route to reconnect, and the queue's suspended notice
names it. (The earlier 'epoch failure' wording is dropped: the media store
has no epoch.)"

- [ ] **Step 2: Verify**

```bash
dart format .
flutter analyze
flutter test test/architecture
flutter test
```

Expected: no format changes, no analyze issues, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-09-18-media-sync-program-design.md
git commit -m "docs(spec): record slice 10's decisions in 7.1"
```

---

## As executed

Where the code that shipped differs from the tasks above:

- **`MediaStorePreflight.check()` landed in Task 4**, returning the verdict
  only, so the harness and the runtime wired straight to it instead of
  through a bool adapter. Task 5 added the mismatch persistence to it.
- **`MediaStoreAttachState.setMarkerMismatch` writes only on a change.**
  The preflight asks before every transfer; the read is served from memory
  and the write is not.
- **The worker's `_hold` is a no-op once disposed.** Dispose does not stop a
  drain already running, and the hold is shared with the worker that
  replaced it. Covered by "a superseded drain does not record a hold after
  dispose".
- **The worker clears the hold when it runs with no preflight**, so a gate's
  offline hold does not outlive the next drain that runs.
- **The no-processor delete test** is the existing case in
  `media_store_worker_delete_test.dart`, rewritten to the new behaviour,
  rather than a new case in the budget test.
- **`transfers_page_test.dart` overrides `mediaTransferSummaryProvider`**
  with a snapshot: the notice now reads the summary, and the live Drift
  stream deadlocks against `db.close()` in fake async (the test hung for its
  full ten minutes before the override).
- **Leases became exclusive claims (PR review).** A lease consulted only by
  `requeueStale` let two workers select one pending row: a superseded
  worker holding it at the gate while its replacement drained, or a later
  drain taking a budget-expired row that never reached `markTransferring`.
  `holdWhile` is gone. `claimNextPending` selects a due, unclaimed row and
  claims it synchronously once the query returns (re-asking if another
  caller got there first); `nextPending` and `requeueStale` skip claimed
  rows; the worker claims at selection, gives the claim back on every early
  exit (gate stop, deferral, fail) and releases a processed row only when
  its work settles, timeout or not.
- **A stale preflight answer is dropped (PR review).** The attachment is
  read again after the marker read, and a change during it answers
  `detached`; the mismatch flag is written only while still attached to the
  store it describes (`setMarkerMismatch(..., whileAttachedTo:)`, check and
  write with no await between them).
- **Second PR review round.** A transfer that outlives its budget kicks a
  fresh drain when it settles (its own drain armed nothing for a row it saw
  as transferring, so a late failure's backoff had no wakeup).
  `requeueStale` reads the transferring ids first and drops claimed ones
  after the read, instead of snapshotting claims before an async update; a
  live row is always claimed before it is marked transferring, so what is
  left is stranded. The hold board records its owner, and a disposed worker
  clears the hold only if it still owns it.
- **Later PR review rounds.** A claim re-reads its row once taken and keeps
  it only while still pending and due, so a query result that went stale
  (another worker claimed, finished and released the row meanwhile) is not
  processed twice. A settled transfer's claim is released with a
  per-database signal (`releaseSettled`, `claimReleases`), and every idle
  worker over that database drains on it, which arms the retry for a
  backoff left by a transfer that settled late or after its worker was
  replaced; this replaced the budget-only kick. A claim given back without
  work (gate stop, deferral) stays silent. The attach state keeps a
  generation bumped by every attach change, and the preflight answers, and
  writes the mismatch flag, only within the generation it began in, which
  catches a reconnect to the same store. `defer` writes only while the row
  is pending or transferring, and the offline line shows for any
  outstanding work.
- **Drain lifecycle (PR review).** A drain stays running while it schedules
  its wakeup; a transfer that settles in that window asks for a follow-up
  drain instead of starting a second one beside it. A gate that throws is
  held like a failed admission (quietly offline, else with its error) and
  arms the retry window, instead of ending the drain silently. The budget
  deferral is a compare-and-set on the attempt count the claim read.
- **Mutation checks**, each compiling and red on its named test: dropping
  the lease or the drain's reclaim (Task 1); dropping the hold from the
  waiting reason or from the re-emit (Task 3); the offline branch, the
  disposed guard, the gate's offline hold, and S8's suspension kind (Task
  4); the mismatch write, the reconnect item, the detached notice text and
  the offline line (Task 5).
