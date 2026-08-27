import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/resolvers/media_fetch_gate.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// The store read path's concurrency cap and request coalescing (#1175).
void main() {
  MediaSourceData result(String path) => FileData(
    file: File(path),
    servedFrom: ServedFrom.storeNetwork,
    servedTier: ServedTier.thumbnail,
  );

  test('caps in-flight fetches at maxConcurrent', () async {
    final gate = MediaFetchGate(maxConcurrent: 2);
    final blockers = <Completer<MediaSourceData?>>[];
    var maxObserved = 0;

    final futures = [
      for (var i = 0; i < 6; i++)
        gate.run('key-$i', () {
          maxObserved = maxObserved > gate.runningCount
              ? maxObserved
              : gate.runningCount;
          final blocker = Completer<MediaSourceData?>();
          blockers.add(blocker);
          return blocker.future;
        }),
    ];

    await Future<void>.delayed(Duration.zero);
    expect(blockers, hasLength(2), reason: 'only two may be running');
    expect(gate.waitingCount, 4);
    expect(maxObserved, lessThanOrEqualTo(2));

    // Draining one admits exactly one waiter.
    blockers[0].complete(result('a'));
    await Future<void>.delayed(Duration.zero);
    expect(blockers, hasLength(3));

    // Drain by index: completing one admits a waiter, which appends to
    // `blockers` mid-loop.
    for (var i = 1; i < blockers.length; i++) {
      if (!blockers[i].isCompleted) blockers[i].complete(result('x'));
      await Future<void>.delayed(Duration.zero);
    }
    await Future.wait(futures);
    expect(gate.runningCount, 0);
  });

  test('duplicate keys share one fetch', () async {
    final gate = MediaFetchGate(maxConcurrent: 4);
    var calls = 0;
    final blocker = Completer<MediaSourceData?>();

    Future<MediaSourceData?> ask() => gate.run('same-hash#thumb', () {
      calls++;
      return blocker.future;
    });

    final first = ask();
    final second = ask();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1, reason: 'the second caller must join the first fetch');

    blocker.complete(result('shared'));
    expect((await first as FileData).file.path, 'shared');
    expect((await second as FileData).file.path, 'shared');
  });

  test('a key is refetchable once its fetch finishes', () async {
    final gate = MediaFetchGate(maxConcurrent: 4);
    var calls = 0;

    Future<MediaSourceData?> ask() => gate.run('k', () async {
      calls++;
      return result('f');
    });

    await ask();
    await ask();
    expect(calls, 2, reason: 'coalescing is for in-flight requests only');
  });

  test('a failed fetch releases its slot and clears the key', () async {
    final gate = MediaFetchGate(maxConcurrent: 1);

    await expectLater(
      gate.run('k', () async => throw const FileSystemException('boom')),
      throwsA(isA<FileSystemException>()),
    );

    expect(gate.runningCount, 0);
    // A leaked in-flight entry would hand this caller the FAILED future
    // forever, so the tile could never recover.
    expect(await gate.run('k', () async => result('later')), isNotNull);
  });

  test('waiters are served in arrival order', () async {
    final gate = MediaFetchGate(maxConcurrent: 1);
    final started = <String>[];
    final blockers = <String, Completer<MediaSourceData?>>{};

    Future<MediaSourceData?> ask(String key) => gate.run(key, () {
      started.add(key);
      return (blockers[key] = Completer<MediaSourceData?>()).future;
    });

    final futures = [ask('a'), ask('b'), ask('c')];
    await Future<void>.delayed(Duration.zero);
    expect(started, ['a']);

    blockers['a']!.complete(result('a'));
    await Future<void>.delayed(Duration.zero);
    expect(started, ['a', 'b'], reason: 'FIFO: b queued before c');

    blockers['b']!.complete(result('b'));
    await Future<void>.delayed(Duration.zero);
    blockers['c']!.complete(result('c'));
    await Future.wait(futures);
  });

  /// Time budgets: a cap with no deadline turns one unreachable item into a
  /// stalled gallery, because a permit held by a fetch against a dead share is
  /// a permit no live tile can have.
  group('budgets', () {
    test('a fetch that overruns the slot budget hands the slot on', () {
      fakeAsync((async) {
        final gate = MediaFetchGate(
          maxConcurrent: 1,
          slotBudget: const Duration(seconds: 5),
          totalBudget: const Duration(seconds: 30),
        );
        final stuck = Completer<MediaSourceData?>();
        var secondStarted = false;

        gate.run('stuck', () => stuck.future);
        async.flushMicrotasks();
        gate.run('live', () async {
          secondStarted = true;
          return result('live');
        });
        async.flushMicrotasks();
        expect(
          secondStarted,
          isFalse,
          reason: 'the only slot is held by the stuck fetch',
        );

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(
          secondStarted,
          isTrue,
          reason: 'the slot budget expired and handed the slot on',
        );
        expect(gate.detachedCount, 1);

        stuck.complete(null);
        async.flushMicrotasks();
        expect(gate.detachedCount, 0);
      });
    });

    test('a fetch that finishes inside the slot budget never detaches', () {
      fakeAsync((async) {
        final gate = MediaFetchGate(
          maxConcurrent: 1,
          slotBudget: const Duration(seconds: 5),
        );
        gate.run('quick', () async => result('quick'));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(gate.detachedCount, 0);
        expect(gate.runningCount, 0);

        // The slot timer must be cancelled, not merely ignored: a stale
        // firing would release a slot this fetch no longer holds and let
        // maxConcurrent drift upward for the life of the process.
        async.elapse(const Duration(seconds: 30));
        expect(gate.runningCount, 0);
      });
    });

    test('the caller gives up at the total budget with stillFetching', () {
      fakeAsync((async) {
        final gate = MediaFetchGate(
          maxConcurrent: 1,
          slotBudget: const Duration(seconds: 5),
          totalBudget: const Duration(seconds: 30),
        );
        final never = Completer<MediaSourceData?>();
        MediaSourceData? seen;
        gate.run('never', () => never.future).then((v) => seen = v);

        async.elapse(const Duration(seconds: 29));
        async.flushMicrotasks();
        expect(seen, isNull);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(seen, isA<UnavailableData>());
        expect((seen! as UnavailableData).kind, UnavailableKind.stillFetching);

        // Giving up is not cancelling: the fetch is still live, and its late
        // completion must not throw into a listener that has gone away.
        never.complete(null);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
      });
    });

    test('detaching is capped so outstanding work cannot grow unbounded', () {
      fakeAsync((async) {
        final gate = MediaFetchGate(
          maxConcurrent: 1,
          maxDetached: 2,
          slotBudget: const Duration(seconds: 5),
          totalBudget: const Duration(minutes: 5),
        );
        final held = <Completer<MediaSourceData?>>[];

        for (var i = 0; i < 4; i++) {
          final blocker = Completer<MediaSourceData?>();
          held.add(blocker);
          gate.run('k$i', () => blocker.future);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
        }

        expect(
          gate.detachedCount,
          2,
          reason: 'at the cap a fetch keeps its slot instead of detaching',
        );
        expect(gate.runningCount, 1);

        for (final blocker in held) {
          blocker.complete(null);
        }
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 6));
      });
    });

    test('a retry after the total budget joins the fetch still in flight', () {
      fakeAsync((async) {
        final gate = MediaFetchGate(
          maxConcurrent: 4,
          slotBudget: const Duration(seconds: 5),
          totalBudget: const Duration(seconds: 30),
        );
        final slow = Completer<MediaSourceData?>();
        var starts = 0;
        Future<MediaSourceData?> fetch() {
          starts++;
          return slow.future;
        }

        gate.run('k', fetch);
        async.elapse(const Duration(seconds: 31));
        async.flushMicrotasks();

        MediaSourceData? retried;
        gate.run('k', fetch).then((v) => retried = v);
        async.flushMicrotasks();
        expect(
          starts,
          1,
          reason: 'a second download of bytes already on the way is waste',
        );

        slow.complete(result('arrived'));
        async.flushMicrotasks();
        expect((retried! as FileData).file.path, 'arrived');
      });
    });
  });
}
