@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/cross_tab_lock.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// Two bodies under the same lock name never overlap, however they are
/// started: the second enters only after the first has left.
void main() {
  test('two bodies under one lock run one after the other', () async {
    final events = <String>[];
    Future<String> body(String tag) =>
        withCrossTabLock('submersion-test', () async {
          events.add('enter $tag');
          await Future<void>.delayed(const Duration(milliseconds: 150));
          events.add('exit $tag');
          return tag;
        });
    final results = await Future.wait([body('a'), body('b')]);
    expect(results, ['a', 'b']);
    expect(events, ['enter a', 'exit a', 'enter b', 'exit b']);
  });

  test('a step joined across tabs waits for a sync another tab holds the '
      'lock for', () async {
    final release = Completer<void>();
    final held = withCrossTabLock(kSyncCrossTabLock, () => release.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    var ran = false;
    final step = SyncCoordinator.joinAcrossTabs(() async => ran = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(ran, isFalse, reason: 'the other sync still runs');

    release.complete();
    await held;
    await step;
    expect(ran, isTrue);
  });

  test('the body\'s value and error come back through the lock', () async {
    expect(await withCrossTabLock('submersion-test', () async => 7), 7);
    expect(
      () => withCrossTabLock('submersion-test', () async {
        throw StateError('x');
      }),
      throwsStateError,
    );
  });

  test(
    'the if-available form skips while another body holds the lock',
    () async {
      final release = Completer<void>();
      var ran = false;
      final holder = withCrossTabLock(
        'submersion-test-avail',
        () => release.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        await withCrossTabLockIfAvailable('submersion-test-avail', () async {
          ran = true;
        }),
        isFalse,
      );
      expect(ran, isFalse);
      release.complete();
      await holder;
      expect(
        await withCrossTabLockIfAvailable('submersion-test-avail', () async {
          ran = true;
        }),
        isTrue,
      );
      expect(ran, isTrue);
    },
  );
}
