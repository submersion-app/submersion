import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';

void main() {
  group('VisibilityRange.fromColumns', () {
    test('no ends is no range', () {
      expect(VisibilityRange.fromColumns(null, null), isNull);
    });

    test('either end alone is an open range', () {
      expect(
        VisibilityRange.fromColumns(null, 2),
        const VisibilityRange(maxM: 2),
      );
      expect(
        VisibilityRange.fromColumns(12, null),
        const VisibilityRange(minM: 12),
      );
    });
  });

  group('VisibilityRange.tryParse (imported values)', () {
    test('accepts a closed range and open ends', () {
      expect(
        VisibilityRange.tryParse(6, 12),
        const VisibilityRange(minM: 6, maxM: 12),
      );
      expect(VisibilityRange.tryParse(null, 2), const VisibilityRange(maxM: 2));
      expect(
        VisibilityRange.tryParse(12, null),
        const VisibilityRange(minM: 12),
      );
    });

    test('rejects a negative end, an empty or inverted range, and no ends', () {
      expect(VisibilityRange.tryParse(-1, 5), isNull);
      expect(VisibilityRange.tryParse(null, 0), isNull);
      expect(VisibilityRange.tryParse(6, 6), isNull);
      expect(VisibilityRange.tryParse(12, 6), isNull);
      expect(VisibilityRange.tryParse(null, null), isNull);
      expect(VisibilityRange.tryParse(double.nan, 5), isNull);
    });
  });

  test('sorts poorest to clearest: open low first, open high last', () {
    final sorted = [
      const VisibilityRange(minM: 12),
      const VisibilityRange(minM: 6, maxM: 12),
      const VisibilityRange(maxM: 2),
      const VisibilityRange(minM: 6, maxM: 8),
    ]..sort();
    expect(sorted, [
      const VisibilityRange(maxM: 2),
      const VisibilityRange(minM: 6, maxM: 8),
      const VisibilityRange(minM: 6, maxM: 12),
      const VisibilityRange(minM: 12),
    ]);
  });
}
