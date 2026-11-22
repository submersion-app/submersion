import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

void main() {
  tearDown(SyncCoordinator.reset);

  test('bodies run one at a time in order', () async {
    final log = <String>[];
    final first = SyncCoordinator.run(() async {
      log.add('a-start');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      log.add('a-end');
    });
    final second = SyncCoordinator.run(() async {
      log.add('b');
    });
    expect(SyncCoordinator.busy, isTrue);
    await Future.wait([first, second]);
    expect(log, ['a-start', 'a-end', 'b']);
    expect(SyncCoordinator.busy, isFalse);
  });

  test('a throwing body releases the gate', () async {
    await expectLater(
      SyncCoordinator.run(() async => throw StateError('x')),
      throwsStateError,
    );
    expect(await SyncCoordinator.run(() async => 1), 1);
    expect(SyncCoordinator.busy, isFalse);
  });

  test('the result of the body comes back', () async {
    expect(await SyncCoordinator.run(() async => 'ok'), 'ok');
  });

  test('quietGuard turns false for good once a sync starts', () async {
    final guard = SyncCoordinator.quietGuard();
    expect(guard(), isTrue);
    await SyncCoordinator.run(() async {});
    expect(guard(), isFalse, reason: 'a sync ran since the guard was taken');
  });

  test('quietGuard is false from the start while a sync is running', () async {
    final hold = Completer<void>();
    final running = SyncCoordinator.run(() => hold.future);
    expect(SyncCoordinator.quietGuard()(), isFalse);
    hold.complete();
    await running;
  });

  test('join from inside a turn runs at once instead of waiting for its '
      'own turn', () async {
    final log = <String>[];
    await SyncCoordinator.run(() async {
      log.add('outer');
      await SyncCoordinator.join(() async => log.add('inner'));
      log.add('outer-end');
    }).timeout(const Duration(seconds: 5));
    expect(log, ['outer', 'inner', 'outer-end']);
    expect(SyncCoordinator.busy, isFalse);
  });

  test('joinAcrossTabs takes a turn: a sync asked for during it waits for '
      'it', () async {
    final log = <String>[];
    late Future<void> sync;
    await SyncCoordinator.joinAcrossTabs(() async {
      sync = SyncCoordinator.run(() async => log.add('sync'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      log.add('step');
    });
    await sync;
    expect(log, ['step', 'sync']);
  });

  test('join outside a turn queues like run', () async {
    final log = <String>[];
    final hold = Completer<void>();
    final holder = SyncCoordinator.run(() async {
      await hold.future;
      log.add('holder');
    });
    final joined = SyncCoordinator.join(() async => log.add('joined'));
    await pumpEventQueue();
    expect(log, isEmpty);
    hold.complete();
    await Future.wait([holder, joined]);
    expect(log, ['holder', 'joined']);
  });

  test('a run a body schedules but does not await waits for that body, '
      'even while it is still running', () async {
    final log = <String>[];
    late Future<void> scheduled;
    await SyncCoordinator.run(() async {
      Timer.run(
        () => scheduled = SyncCoordinator.run(() async => log.add('timer')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      log.add('body-end');
    });
    await scheduled;
    expect(log, ['body-end', 'timer']);
  });

  test('a join that outlives its turn queues like any other run', () async {
    final log = <String>[];
    final fire = Completer<void>();
    late Future<void> late_;
    await SyncCoordinator.run(() async {
      // Scheduled inside the turn, so it runs in the turn's zone, but only
      // after the turn has ended.
      unawaited(
        fire.future.then(
          (_) => late_ = SyncCoordinator.join(() async => log.add('late')),
        ),
      );
    });
    final hold = Completer<void>();
    final holder = SyncCoordinator.run(() async {
      log.add('holder');
      await hold.future;
      log.add('holder-end');
    });
    fire.complete();
    await pumpEventQueue();
    expect(log, ['holder'], reason: 'the late run must wait for the holder');
    hold.complete();
    await holder;
    await late_;
    expect(log, ['holder', 'holder-end', 'late']);
  });

  // A test's tearDown resets the coordinator while a turn the test started
  // may still be running. When that turn ends, it must not count against the
  // turns of the next test, which share the isolate (issue #4900).
  group('a turn still running at reset', () {
    test('ending after a new turn starts leaves the new one busy', () async {
      final stale = Completer<void>();
      final leftover = SyncCoordinator.run(() => stale.future);
      SyncCoordinator.reset();

      final hold = Completer<void>();
      final running = SyncCoordinator.run(() => hold.future);
      stale.complete();
      await leftover;

      expect(SyncCoordinator.busy, isTrue);
      hold.complete();
      await running;
      expect(SyncCoordinator.busy, isFalse);
    });

    test('ending before a new turn starts leaves the new one busy', () async {
      final stale = Completer<void>();
      final leftover = SyncCoordinator.run(() => stale.future);
      SyncCoordinator.reset();
      stale.complete();
      await leftover;
      expect(SyncCoordinator.busy, isFalse);

      final hold = Completer<void>();
      final running = SyncCoordinator.run(() => hold.future);
      expect(SyncCoordinator.busy, isTrue);
      hold.complete();
      await running;
      expect(SyncCoordinator.busy, isFalse);
    });

    test(
      'a turn queued behind it does not count against the next either',
      () async {
        final stale = Completer<void>();
        final leftover = SyncCoordinator.run(() => stale.future);
        final queued = SyncCoordinator.run(() async {});
        SyncCoordinator.reset();

        final hold = Completer<void>();
        final running = SyncCoordinator.run(() => hold.future);
        stale.complete();
        await Future.wait([leftover, queued]);

        expect(SyncCoordinator.busy, isTrue);
        hold.complete();
        await running;
        expect(SyncCoordinator.busy, isFalse);
      },
    );

    test('a quietGuard taken before it stays false after it', () async {
      final guard = SyncCoordinator.quietGuard();
      await SyncCoordinator.run(() async {});
      SyncCoordinator.reset();
      // The next test starts as many syncs as had started when the guard
      // was taken, none of them still running.
      expect(guard(), isFalse, reason: 'a reset is not a quiet period');
    });
  });

  test('an idle queue does not wait on the zone of its last turn', () async {
    fakeAsync((async) {
      unawaited(SyncCoordinator.run(() async {}));
      async.flushMicrotasks();
    });

    // That zone has stopped running: a turn chained to it would never start.
    var ran = false;
    await SyncCoordinator.run(
      () async => ran = true,
    ).timeout(const Duration(seconds: 1));

    expect(ran, isTrue);
  });
}
