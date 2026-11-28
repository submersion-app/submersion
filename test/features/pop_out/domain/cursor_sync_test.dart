import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/pop_out/domain/cursor_sync.dart';

void main() {
  group('CursorEchoGate', () {
    test('echo gate drops the value just received', () {
      final gate = CursorEchoGate();
      gate.noteReceived('a', 120);
      expect(gate.shouldSend('a', 120), isFalse);
      // The local cursor then moves on: that is the diver's own scrub.
      expect(gate.shouldSend('a', 121), isTrue);
    });

    test('a received clear is not echoed either', () {
      final gate = CursorEchoGate();
      gate.noteReceived('a', null);
      expect(gate.shouldSend('a', null), isFalse);
    });

    test('a received value for one dive does not gate another', () {
      final gate = CursorEchoGate();
      gate.noteReceived('a', 120);
      expect(gate.shouldSend('b', 120), isTrue);
    });

    test('the same local value is not sent twice', () {
      final gate = CursorEchoGate();
      expect(gate.shouldSend('a', 5), isTrue);
      expect(gate.shouldSend('a', 5), isFalse);
      expect(gate.shouldSend('a', 6), isTrue);
    });

    test('after an echo is dropped, the value can be sent again later', () {
      final gate = CursorEchoGate();
      gate.noteReceived('a', 10);
      expect(gate.shouldSend('a', 10), isFalse);
      expect(gate.shouldSend('a', 11), isTrue);
      expect(gate.shouldSend('a', 10), isTrue);
    });
  });

  // The main window's fullscreen view and the detail chart under it both
  // apply a received position, one exactly and one snapped to a sample.
  group('CursorEchoGate with two landings', () {
    test('both landings of one received position are dropped', () {
      final gate = CursorEchoGate();
      gate.noteReceived('a', 125);
      gate.alsoExpect('a', 120);
      expect(gate.shouldSend('a', 120), isFalse);
      expect(gate.shouldSend('a', 125), isFalse);
    });

    test("a newer received position forgets the last one's landings", () {
      final gate = CursorEchoGate();
      gate.noteReceived('a', 125);
      gate.alsoExpect('a', 120);
      gate.noteReceived('a', 200);
      expect(gate.shouldSend('a', 120), isTrue);
    });

    test('a move of the diver\'s own forgets landings still expected', () {
      final gate = CursorEchoGate();
      gate.noteReceived('a', 125);
      gate.alsoExpect('a', 120);
      expect(gate.shouldSend('a', 130), isTrue);
      expect(gate.shouldSend('a', 120), isTrue);
    });
  });

  group('CursorCoalescer', () {
    test('coalescer sends only the latest value per interval', () {
      fakeAsync((async) {
        final sent = <(String, int?)>[];
        final coalescer = CursorCoalescer((id, s) => sent.add((id, s)));
        coalescer
          ..push('a', 1)
          ..push('a', 2)
          ..push('a', 3);
        expect(sent, isEmpty);
        async.elapse(const Duration(milliseconds: 16));
        expect(sent, [('a', 3)]);
        coalescer.push('a', null);
        async.elapse(const Duration(milliseconds: 16));
        expect(sent, [('a', 3), ('a', null)]);
        coalescer.dispose();
      });
    });

    test('dispose drops a pending value', () {
      fakeAsync((async) {
        final sent = <(String, int?)>[];
        final coalescer = CursorCoalescer((id, s) => sent.add((id, s)));
        coalescer.push('a', 1);
        coalescer.dispose();
        async.elapse(const Duration(milliseconds: 50));
        expect(sent, isEmpty);
      });
    });
  });
}
