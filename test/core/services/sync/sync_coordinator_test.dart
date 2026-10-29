import 'dart:async';

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

  test('a body run inside a turn runs at once instead of waiting for its '
      'own turn', () async {
    final log = <String>[];
    await SyncCoordinator.run(() async {
      log.add('outer');
      await SyncCoordinator.run(() async => log.add('inner'));
      log.add('outer-end');
    }).timeout(const Duration(seconds: 5));
    expect(log, ['outer', 'inner', 'outer-end']);
    expect(SyncCoordinator.busy, isFalse);
  });

  test('a callback that outlives its turn queues like any other run', () async {
    final log = <String>[];
    final fire = Completer<void>();
    late Future<void> late_;
    await SyncCoordinator.run(() async {
      // Scheduled inside the turn, so it runs in the turn's zone, but only
      // after the turn has ended.
      unawaited(
        fire.future.then(
          (_) => late_ = SyncCoordinator.run(() async => log.add('late')),
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
}
