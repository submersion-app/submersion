import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';

void main() {
  setUp(() {
    PerfTimer.reset();
  });

  group('PerfTimer', () {
    test('measure captures duration for async operations', () async {
      final result = await PerfTimer.measure('testOp', () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 42;
      });

      expect(result, equals(42));
      final duration = PerfTimer.lastResult('testOp');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, greaterThanOrEqualTo(40));
    });

    test('measureSync captures duration for sync operations', () {
      final result = PerfTimer.measureSync('syncOp', () {
        var sum = 0;
        for (var i = 0; i < 1000000; i++) {
          sum += i;
        }
        return sum;
      });

      expect(result, greaterThan(0));
      expect(PerfTimer.lastResult('syncOp'), isNotNull);
      expect(PerfTimer.lastResult('syncOp')!.inMicroseconds, greaterThan(0));
    });

    test('reset clears all results', () async {
      await PerfTimer.measure('op1', () async => 1);
      PerfTimer.reset();
      expect(PerfTimer.lastResult('op1'), isNull);
    });

    test('lastResult returns null for unknown operations', () {
      expect(PerfTimer.lastResult('nonexistent'), isNull);
    });

    test('allResults returns all captured timings', () async {
      await PerfTimer.measure('a', () async => 1);
      await PerfTimer.measure('b', () async => 2);
      final all = PerfTimer.allResults;
      expect(all.keys, containsAll(['a', 'b']));
    });
  });
}
