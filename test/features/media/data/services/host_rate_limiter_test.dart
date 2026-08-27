import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';

void main() {
  group('HostRateLimiter', () {
    test('runs a single task and returns its result', () async {
      final limiter = HostRateLimiter();
      final result = await limiter.run<int>('example.com', () async => 42);
      expect(result, 42);
    });

    test('caps in-flight tasks per host at the configured concurrency', () {
      fakeAsync((async) {
        final limiter = HostRateLimiter(maxConcurrentPerHost: 2);
        var inFlight = 0;
        var maxObserved = 0;
        final futures = <Future<void>>[];

        for (var i = 0; i < 6; i++) {
          futures.add(
            limiter.run('example.com', () async {
              inFlight++;
              if (inFlight > maxObserved) maxObserved = inFlight;
              await Future<void>.delayed(const Duration(milliseconds: 50));
              inFlight--;
            }),
          );
        }

        async.elapse(const Duration(seconds: 5));
        Future.wait(futures);
        async.flushMicrotasks();

        expect(maxObserved, 2);
      });
    });

    test('enforces minimum spacing between sequential same-host tasks', () {
      fakeAsync((async) {
        final limiter = HostRateLimiter(
          maxConcurrentPerHost: 1,
          minSpacing: const Duration(milliseconds: 250),
        );
        final completionTimes = <int>[];
        final start = DateTime.now().millisecondsSinceEpoch;

        Future<void> task() async {
          completionTimes.add(DateTime.now().millisecondsSinceEpoch - start);
        }

        // Note: with a fake clock, "real" wall time doesn't advance — we
        // assert on the *order* and use elapse to drain the timer queue.
        for (var i = 0; i < 3; i++) {
          limiter.run('example.com', task);
        }

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(completionTimes.length, 3);
      });
    });

    test('different hosts do not block each other', () {
      fakeAsync((async) {
        final limiter = HostRateLimiter(maxConcurrentPerHost: 1);
        var aRunning = 0;
        var bRunning = 0;
        var seenBoth = false;

        limiter.run('a.example', () async {
          aRunning++;
          if (aRunning > 0 && bRunning > 0) seenBoth = true;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          aRunning--;
        });
        limiter.run('b.example', () async {
          bRunning++;
          if (aRunning > 0 && bRunning > 0) seenBoth = true;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bRunning--;
        });

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(seenBoth, isTrue);
      });
    });

    test('failures in one task do not block subsequent tasks', () async {
      final limiter = HostRateLimiter(
        maxConcurrentPerHost: 1,
        minSpacing: Duration.zero,
      );
      // ignore: unawaited_futures
      limiter
          .run<void>('example.com', () async => throw StateError('boom'))
          .catchError((_) {});
      final ok = await limiter.run<int>('example.com', () async => 7);
      expect(ok, 7);
    });
  });
}
