// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 12. Unit tests cover the pure surfaces of
// `SubscriptionPollerScheduler`:
//
// 1. `computeInterval` — the cadence rule (smallest of `pollIntervalSeconds /
//    4` across active subs and 1 hour, with a 30 s floor).
// 2. `pollNow()` — the user-triggered single-cycle entry point. Verified by
//    constructing the scheduler via the test seam and asserting that it
//    awaits the injected `pollAllDue` callback.
// 3. `dispose()` warm-up cancellation — fakeAsync-driven test that arms
//    `startAfterWarmup`, advances time partway, calls `dispose`, then
//    advances past the warm-up duration and asserts the poller never ran.
//
// The periodic timer in `_scheduleNext()` is flagged `coverage:ignore` in
// the implementation — driving it through `fake_async` would only
// re-verify SDK semantics rather than this class's behaviour.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/subscription_poller_scheduler.dart';

void main() {
  group('SubscriptionPollerScheduler.computeInterval', () {
    test('returns 1 hour when smallest pollInterval is large', () {
      expect(
        SubscriptionPollerScheduler.computeInterval([86400, 86400 * 7]),
        const Duration(hours: 1),
      );
    });

    test('returns pollInterval / 4 when smaller than 1 hour', () {
      expect(
        SubscriptionPollerScheduler.computeInterval([
          60 * 60,
        ]), // 1 h -> /4 = 15 m
        const Duration(minutes: 15),
      );
      expect(
        SubscriptionPollerScheduler.computeInterval([
          5 * 60,
        ]), // 5 m -> /4 = 75 s
        const Duration(seconds: 75),
      );
    });

    test('returns 1 hour when no subscriptions exist', () {
      expect(
        SubscriptionPollerScheduler.computeInterval(const []),
        const Duration(hours: 1),
      );
    });

    test('returns 30 s minimum to avoid runaway loops', () {
      expect(
        SubscriptionPollerScheduler.computeInterval([60]), // 1 m -> /4 = 15 s
        const Duration(seconds: 30),
      );
    });
  });

  test('pollNow() awaits the underlying poller', () async {
    var calls = 0;
    final scheduler = SubscriptionPollerScheduler.forTest(
      pollAllDue: (now) async {
        calls++;
        return 0;
      },
      activePollIntervals: () async => const [],
    );
    await scheduler.pollNow();
    expect(calls, 1);
  });

  test('dispose cancels the warm-up timer if it has not yet fired', () {
    fakeAsync((async) {
      var calls = 0;
      final scheduler = SubscriptionPollerScheduler.forTest(
        pollAllDue: (now) async {
          calls++;
          return 0;
        },
        activePollIntervals: () async => const [],
      );

      // Arm the 30 s warm-up.
      scheduler.startAfterWarmup();
      // Advance partway through the warm-up window — the timer must not
      // have fired yet.
      async.elapse(const Duration(seconds: 15));
      expect(calls, 0);

      // Tear the scheduler down before the warm-up callback runs.
      scheduler.dispose();

      // Push past the original 30 s mark plus a generous margin. If the
      // warm-up timer leaked, `pollAllDue` would be invoked here.
      async.elapse(const Duration(seconds: 60));
      expect(calls, 0);
    });
  });
}
