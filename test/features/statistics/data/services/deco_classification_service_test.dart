import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/data/services/deco_classification_service.dart';

void main() {
  group('decoInputsHash', () {
    test('is stable for identical inputs', () {
      final a = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      expect(a, b);
    });

    test('changes when a gradient factor changes', () {
      final a = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 80,
        diveUpdatedAt: 1000,
      );
      expect(a, isNot(b));
    });

    test('changes when the dive is edited', () {
      final a = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 2000,
      );
      expect(a, isNot(b));
    });

    test('changes when the analysis engine is bumped', () {
      final a = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 4,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      expect(a, isNot(b));
    });

    test('does not collide when adjacent fields shift a digit', () {
      // A naive concatenation without separators would make (gf 5, 085) and
      // (gf 50, 85) hash identically.
      final a = decoInputsHash(
        engineVersion: 1,
        gfLow: 5,
        gfHigh: 985,
        diveUpdatedAt: 1,
      );
      final b = decoInputsHash(
        engineVersion: 1,
        gfLow: 59,
        gfHigh: 85,
        diveUpdatedAt: 1,
      );
      expect(a, isNot(b));
    });
  });
}
