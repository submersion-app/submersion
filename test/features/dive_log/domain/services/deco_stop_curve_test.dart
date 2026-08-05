import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/deco_stop_curve.dart';

void main() {
  group('quantizeCeilingToStops', () {
    test('rounds a partial ceiling up to the next stop', () {
      final result = quantizeCeilingToStops([4.2], stopIncrement: 3.0);
      expect(result, [6.0]);
    });

    test('leaves an exact multiple unchanged', () {
      final result = quantizeCeilingToStops([6.0], stopIncrement: 3.0);
      expect(result, [6.0]);
    });

    test('keeps zero as zero (no obligation)', () {
      final result = quantizeCeilingToStops([0.0], stopIncrement: 3.0);
      expect(result, [0.0]);
    });

    test('clamps negative values to zero', () {
      final result = quantizeCeilingToStops([-1.5], stopIncrement: 3.0);
      expect(result, [0.0]);
    });

    test('honors a non-3m increment', () {
      final result = quantizeCeilingToStops([4.2], stopIncrement: 2.0);
      expect(result, [6.0]);
    });

    test('tolerates floating point noise just above a multiple', () {
      // 6.0000000001 must not round up to 9m.
      final result = quantizeCeilingToStops([6.0000000001], stopIncrement: 3.0);
      expect(result, [6.0]);
    });

    test('returns empty for an empty curve', () {
      expect(quantizeCeilingToStops([], stopIncrement: 3.0), isEmpty);
    });

    test('falls back to the raw curve when the increment is not positive', () {
      final result = quantizeCeilingToStops([4.2], stopIncrement: 0.0);
      expect(result, [4.2]);
    });

    test('quantizes a whole descent-to-ascent curve', () {
      final result = quantizeCeilingToStops([
        0.0,
        0.0,
        1.1,
        4.9,
        7.2,
        3.0,
        0.0,
      ], stopIncrement: 3.0);
      expect(result, [0.0, 0.0, 3.0, 6.0, 9.0, 3.0, 0.0]);
    });
  });

  group('stepTransitionIndices', () {
    test('returns empty for an empty curve', () {
      expect(stepTransitionIndices([]), isEmpty);
    });

    test('returns only index 0 for a single-element curve', () {
      expect(stepTransitionIndices([3.0]), [0]);
    });

    test('keeps every transition plus the endpoints', () {
      // Value changes at indices 2, 4 and 6.
      final curve = [0.0, 0.0, 3.0, 3.0, 6.0, 6.0, 0.0, 0.0];
      expect(stepTransitionIndices(curve), [0, 2, 4, 6, 7]);
    });

    test('returns first and last index for a constant curve', () {
      expect(stepTransitionIndices([3.0, 3.0, 3.0]), [0, 2]);
    });
  });
}
