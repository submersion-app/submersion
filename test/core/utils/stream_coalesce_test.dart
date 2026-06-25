import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/stream_coalesce.dart';

void main() {
  const window = Duration(milliseconds: 200);

  test(
    'a single tick emits immediately (leading), with no spurious trailing',
    () {
      fakeAsync((async) {
        final src = StreamController<void>();
        final times = <int>[];
        final sub = src.stream
            .coalesce(window)
            .listen((_) => times.add(async.elapsed.inMilliseconds));

        src.add(null);
        async.elapse(window * 2);

        expect(times, [0]); // immediate, and no second (trailing) emit
        sub.cancel();
        src.close();
      });
    },
  );

  test('a burst within the window collapses to leading + one trailing', () {
    fakeAsync((async) {
      final src = StreamController<void>();
      final times = <int>[];
      final sub = src.stream
          .coalesce(window)
          .listen((_) => times.add(async.elapsed.inMilliseconds));

      src.add(null); // leading at t=0
      async.elapse(const Duration(milliseconds: 10));
      src.add(null);
      async.elapse(const Duration(milliseconds: 10));
      src.add(null);
      async.elapse(const Duration(milliseconds: 10));
      src.add(null); // last tick at t=30
      async.elapse(window * 2);

      // Leading at 0; trailing 200ms after the last tick (30 + 200 = 230).
      // A burst of four ticks becomes exactly two emits.
      expect(times, [0, 230]);
      sub.cancel();
      src.close();
    });
  });

  test('ticks spaced more than the window apart each emit immediately', () {
    fakeAsync((async) {
      final src = StreamController<void>();
      final times = <int>[];
      final sub = src.stream
          .coalesce(window)
          .listen((_) => times.add(async.elapsed.inMilliseconds));

      src.add(null);
      async.elapse(const Duration(milliseconds: 300)); // > window
      src.add(null);
      async.elapse(const Duration(milliseconds: 300));

      expect(times, [0, 300]); // both leading (immediate), not coalesced
      sub.cancel();
      src.close();
    });
  });

  test('a pending trailing tick is flushed when the source closes', () async {
    // Real async with a long window so ONLY close (not the timer) can flush the
    // pending trailing -- proving close never drops the final tick.
    final src = StreamController<void>();
    final events = <String>[];
    src.stream
        .coalesce(const Duration(seconds: 10))
        .listen((_) => events.add('tick'), onDone: () => events.add('done'));

    src.add(null); // leading
    await Future<void>.delayed(Duration.zero);
    src.add(null); // would-be trailing, still pending (window not elapsed)
    await src.close();
    await Future<void>.delayed(Duration.zero);

    expect(events, [
      'tick',
      'tick',
      'done',
    ]); // leading, trailing-on-close, done
  });
}
