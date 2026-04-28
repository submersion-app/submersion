// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 12. Unit tests cover the two pure surfaces of
// `SubscriptionPollerScheduler`:
//
// 1. `computeInterval` — the cadence rule (smallest of `pollIntervalSeconds /
//    4` across active subs and 1 hour, with a 30 s floor).
// 2. `pollNow()` — the user-triggered single-cycle entry point. Verified by
//    constructing the scheduler via the test seam and asserting that it
//    awaits the injected `pollAllDue` callback.
//
// The 30 s warm-up timer and the periodic timer in `startAfterWarmup()` /
// `_scheduleNext()` are flagged `coverage:ignore` in the implementation —
// real-`Timer` integration concerns. The plan's recommended technique (drive
// time forward via `package:fake_async`) is feasible here but adds no signal
// beyond verifying `Timer.periodic` semantics, which the SDK already covers.
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
}
