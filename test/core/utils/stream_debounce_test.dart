import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/stream_debounce.dart';

void main() {
  group('Stream.debounce', () {
    test('emits only the most recent event of a burst, once', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final emitted = <int>[];
        final sub = source.stream
            .debounce(const Duration(milliseconds: 300))
            .listen(emitted.add);

        source
          ..add(1)
          ..add(2)
          ..add(3);

        // Still inside the quiet window: nothing emitted yet.
        async.elapse(const Duration(milliseconds: 200));
        expect(emitted, isEmpty);

        // Window elapses with no further events: one trailing emission.
        async.elapse(const Duration(milliseconds: 200));
        expect(emitted, [3]);

        sub.cancel();
        source.close();
      });
    });

    test('a continuous burst collapses to a single emission', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final emitted = <int>[];
        final sub = source.stream
            .debounce(const Duration(milliseconds: 300))
            .listen(emitted.add);

        // 20 events, each well within the window of the previous: the timer
        // keeps resetting, so nothing fires until the stream goes quiet.
        for (var i = 0; i < 20; i++) {
          source.add(i);
          async.elapse(const Duration(milliseconds: 50));
        }
        expect(emitted, isEmpty);

        async.elapse(const Duration(milliseconds: 300));
        expect(emitted, [19]);

        sub.cancel();
        source.close();
      });
    });

    test('events spaced beyond the window each emit', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final emitted = <int>[];
        final sub = source.stream
            .debounce(const Duration(milliseconds: 200))
            .listen(emitted.add);

        source.add(1);
        async.elapse(const Duration(milliseconds: 250));
        source.add(2);
        async.elapse(const Duration(milliseconds: 250));

        expect(emitted, [1, 2]);

        sub.cancel();
        source.close();
      });
    });

    test('flushes a pending event when the source closes early', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final emitted = <int>[];
        final sub = source.stream
            .debounce(const Duration(milliseconds: 300))
            .listen(emitted.add);

        source.add(42);
        source.close(); // closes before the debounce window elapses

        async.elapse(const Duration(milliseconds: 1));
        expect(emitted, [
          42,
        ], reason: 'a final event must not be dropped on close');

        sub.cancel();
      });
    });

    test('cancelling the subscription suppresses a pending emit', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final emitted = <int>[];
        final sub = source.stream
            .debounce(const Duration(milliseconds: 300))
            .listen(emitted.add);

        source.add(1);
        sub.cancel();

        async.elapse(const Duration(milliseconds: 500));
        expect(emitted, isEmpty);

        source.close();
      });
    });
  });
}
