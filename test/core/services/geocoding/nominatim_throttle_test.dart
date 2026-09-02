import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/geocoding/nominatim_throttle.dart';

void main() {
  test('the first request goes through immediately', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle();
      var released = false;
      throttle.wait().then((_) => released = true);
      async.flushMicrotasks();
      expect(released, isTrue);
    });
  });

  test('a second request waits until a second has passed', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle();
      final releasedAt = <Duration>[];
      final start = clock.now();
      throttle.wait().then(
        (_) => releasedAt.add(clock.now().difference(start)),
      );
      throttle.wait().then(
        (_) => releasedAt.add(clock.now().difference(start)),
      );
      async.flushMicrotasks();
      expect(releasedAt, [Duration.zero]);

      async.elapse(const Duration(milliseconds: 999));
      expect(releasedAt, hasLength(1));

      async.elapse(const Duration(milliseconds: 1));
      expect(releasedAt, [Duration.zero, const Duration(seconds: 1)]);
    });
  });

  test('requests spaced wider than the gap are not delayed', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle();
      throttle.wait();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));

      var released = false;
      throttle.wait().then((_) => released = true);
      async.flushMicrotasks();
      expect(released, isTrue);
    });
  });

  test('three queued requests are released one second apart', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle();
      final start = clock.now();
      final releasedAt = <Duration>[];
      for (var i = 0; i < 3; i++) {
        throttle.wait().then(
          (_) => releasedAt.add(clock.now().difference(start)),
        );
      }
      async.elapse(const Duration(seconds: 2));
      expect(releasedAt, [
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });
  });

  test('a zero gap never delays', () {
    fakeAsync((async) {
      final throttle = NominatimThrottle(minimumGap: Duration.zero);
      var count = 0;
      for (var i = 0; i < 5; i++) {
        throttle.wait().then((_) => count++);
      }
      async.flushMicrotasks();
      expect(count, 5);
    });
  });
}
