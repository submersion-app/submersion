import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';

void main() {
  group('decimateProfileIndices', () {
    test('no-op when at or under target', () {
      final depths = List<double>.generate(50, (i) => i.toDouble());
      final r = decimateProfileIndices(
        depths: depths,
        bands: List.filled(50, 0),
        decoTypes: List.filled(50, -1),
        targetPoints: 2000,
      );
      expect(r, List<int>.generate(50, (i) => i));
    });

    test('keeps endpoints, ascends, stays in range, reduces count', () {
      const n = 6000;
      final depths = List<double>.generate(n, (i) => 30 + 5 * (i % 7));
      final r = decimateProfileIndices(
        depths: depths,
        bands: List.filled(n, 0),
        decoTypes: List.filled(n, -1),
        targetPoints: 2000,
      );
      expect(r.first, 0);
      expect(r.last, n - 1);
      for (var i = 1; i < r.length; i++) {
        expect(r[i] > r[i - 1], isTrue); // strictly ascending, in-range
      }
      expect(r.length, lessThan(n));
    });

    test('always keeps the global max-depth spike', () {
      const n = 5000;
      final depths = List<double>.filled(n, 10.0);
      depths[3777] = 42.0; // lone deep spike
      final r = decimateProfileIndices(
        depths: depths,
        bands: List.filled(n, 0),
        decoTypes: List.filled(n, -1),
        targetPoints: 500,
      );
      expect(r.contains(3777), isTrue);
    });

    test('keeps ascent-rate band crossings (no fabricated-safe ascent)', () {
      const n = 5000;
      final depths = List<double>.filled(n, 20.0);
      final bands = List<int>.filled(n, 0); // green
      for (var i = 2500; i < 2520; i++) {
        bands[i] = 2; // brief red excursion
      }
      final r = decimateProfileIndices(
        depths: depths,
        bands: bands,
        decoTypes: List.filled(n, -1),
        targetPoints: 400,
      );
      expect(r.contains(2500), isTrue); // entry crossing kept
      expect(r.contains(2520), isTrue); // exit crossing kept
    });

    test('keeps decoType transitions', () {
      const n = 5000;
      final deco = List<int>.filled(n, 0); // NDL
      for (var i = 4000; i < n; i++) {
        deco[i] = 2; // enters deco
      }
      final r = decimateProfileIndices(
        depths: List<double>.filled(n, 15.0),
        bands: List.filled(n, 0),
        decoTypes: deco,
        targetPoints: 400,
      );
      expect(r.contains(4000), isTrue);
    });
  });
}
