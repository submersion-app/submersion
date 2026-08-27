import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/hlc.dart';

/// Unit tests for the Hybrid Logical Clock value type. Pure, no DB.
void main() {
  group('Hlc', () {
    test('parse(toString()) round-trips all components', () {
      const hlc = Hlc(1700000000000, 7, 'device-abc');
      final parsed = Hlc.parse(hlc.toString());
      expect(parsed.physicalTime, 1700000000000);
      expect(parsed.counter, 7);
      expect(parsed.nodeId, 'device-abc');
    });

    test('parse preserves a nodeId that itself contains the separator', () {
      const hlc = Hlc(1700000000000, 0, 'a:b:c');
      final parsed = Hlc.parse(hlc.toString());
      expect(parsed.nodeId, 'a:b:c');
    });

    test('parse throws FormatException on a malformed string', () {
      expect(() => Hlc.parse('1000:5'), throwsFormatException);
      expect(() => Hlc.parse('garbage'), throwsFormatException);
    });

    test('orders by physical time first', () {
      const older = Hlc(1000, 999, 'z');
      const newer = Hlc(2000, 0, 'a');
      expect(older.compareTo(newer), lessThan(0));
      expect(newer.compareTo(older), greaterThan(0));
    });

    test('breaks ties on counter when physical times are equal', () {
      const lo = Hlc(1000, 1, 'z');
      const hi = Hlc(1000, 2, 'a');
      expect(lo.compareTo(hi), lessThan(0));
    });

    test('breaks ties on nodeId when physical and counter are equal', () {
      const a = Hlc(1000, 1, 'aaa');
      const b = Hlc(1000, 1, 'bbb');
      expect(a.compareTo(b), lessThan(0));
      expect(a.compareTo(const Hlc(1000, 1, 'aaa')), 0);
    });

    group('increment (local event)', () {
      test('advances physical time and resets counter when wall clock moved '
          'forward', () {
        const clock = Hlc(1000, 5, 'node');
        final next = clock.increment(2000);
        expect(next.physicalTime, 2000);
        expect(next.counter, 0);
        expect(next.nodeId, 'node');
      });

      test('keeps physical time and bumps counter when wall clock has not '
          'advanced (skew or same millisecond)', () {
        const clock = Hlc(2000, 5, 'node');
        final next = clock.increment(1900); // wall clock is behind
        expect(next.physicalTime, 2000);
        expect(next.counter, 6);
      });
    });

    group('merge (receive event)', () {
      test('adopts a higher remote physical time and follows its counter '
          '(the clock-skew fix)', () {
        // Local wall clock is behind; a remote HLC carries a higher physical
        // time. After merge our clock must jump forward so our next local
        // write is ordered after the remote event.
        const local = Hlc(1000, 0, 'me');
        const remote = Hlc(5000, 3, 'other');
        final merged = local.merge(remote, 1100); // wall clock still ~1100
        expect(merged.physicalTime, 5000);
        expect(merged.counter, 4); // remote.counter + 1
        expect(merged.nodeId, 'me'); // identity stays ours
      });

      test('uses wall clock when it exceeds both sides', () {
        const local = Hlc(1000, 2, 'me');
        const remote = Hlc(2000, 9, 'other');
        final merged = local.merge(remote, 9000);
        expect(merged.physicalTime, 9000);
        expect(merged.counter, 0);
      });

      test('bumps max counter when all three physical times are equal', () {
        const local = Hlc(3000, 4, 'me');
        const remote = Hlc(3000, 6, 'other');
        final merged = local.merge(remote, 3000);
        expect(merged.physicalTime, 3000);
        expect(merged.counter, 7); // max(4, 6) + 1
      });

      test('keeps local physical time and bumps local counter when local is '
          'the sole max', () {
        // Local physical time is ahead of both the remote event and the wall
        // clock, so the merged clock stays on local time and advances its own
        // counter.
        const local = Hlc(5000, 2, 'me');
        const remote = Hlc(2000, 9, 'other');
        final merged = local.merge(remote, 1000);
        expect(merged.physicalTime, 5000);
        expect(merged.counter, 3); // local.counter + 1
        expect(merged.nodeId, 'me');
      });
    });

    group('equality and hashCode', () {
      test('two HLCs with identical components are equal', () {
        const a = Hlc(1000, 2, 'node');
        const b = Hlc(1000, 2, 'node');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('differs when any single component differs', () {
        const base = Hlc(1000, 2, 'node');
        expect(base == const Hlc(9999, 2, 'node'), isFalse);
        expect(base == const Hlc(1000, 9, 'node'), isFalse);
        expect(base == const Hlc(1000, 2, 'other'), isFalse);
      });

      test('is not equal to a non-Hlc value', () {
        const base = Hlc(1000, 2, 'node');
        expect(base == Object(), isFalse);
      });
    });
  });
}
