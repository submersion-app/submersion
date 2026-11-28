import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_deviation_scale.dart';

void main() {
  group('SacDeviationScale', () {
    test('gives each side the room its largest swing needs', () {
      final scale = SacDeviationScale.of([10, 20, 5, 5], average: 10);

      // 10 above and 5 below: two thirds of the plot above the average.
      expect(scale.baseline, closeTo(2 / 3, 1e-9));
      expect(scale.bars[0], 0);
      expect(scale.bars[1], closeTo(2 / 3, 1e-9));
      expect(scale.bars[2], closeTo(-1 / 3, 1e-9));
      expect(scale.bars[3], closeTo(-1 / 3, 1e-9));
    });

    test('draws both directions on one scale', () {
      final scale = SacDeviationScale.of([12, 7], average: 10);

      // +2 and -3 keep their ratio, so a bar reads true against another.
      expect(scale.bars[0] / scale.bars[1], closeTo(2 / -3, 1e-9));
    });

    test('keeps room below for a dive that never dipped much', () {
      final scale = SacDeviationScale.of([30, 9.9, 10], average: 10);

      expect(scale.baseline, SacDeviationScale.maxBaseline);
      expect(scale.bars[0], closeTo(scale.baseline, 1e-9));
      expect(scale.bars[1], greaterThan(-(1 - scale.baseline)));
    });

    test('keeps room above for a dive that never rose much', () {
      final scale = SacDeviationScale.of([10.1, 2, 10], average: 10);

      expect(scale.baseline, SacDeviationScale.minBaseline);
      expect(scale.bars[1], closeTo(-(1 - scale.baseline), 1e-9));
    });

    test('no bar runs past the plot', () {
      final scale = SacDeviationScale.of([30, 9.9, 10], average: 10);

      for (final bar in scale.bars) {
        expect(bar, lessThanOrEqualTo(scale.baseline + 1e-9));
        expect(bar, greaterThanOrEqualTo(-(1 - scale.baseline) - 1e-9));
      }
    });

    test('a dive at one steady rate lays every bar on the average', () {
      final scale = SacDeviationScale.of([10, 10, 10], average: 10);

      expect(scale.baseline, 0.5);
      expect(scale.bars, [0, 0, 0]);
      expect(scale.highest, isNull);
      expect(scale.lowest, isNull);
    });

    test('a value that is not a number draws nothing', () {
      final scale = SacDeviationScale.of([double.nan, 12], average: 10);

      expect(scale.bars.first, 0);
      expect(scale.bars.last, greaterThan(0));
    });

    test('finds the stretches furthest above and below', () {
      final scale = SacDeviationScale.of([10, 20, 5, 5], average: 10);

      expect(scale.highest, 1);
      expect(scale.lowest, 2); // The first of a tie.
    });

    test('names no lowest where nothing dipped', () {
      final scale = SacDeviationScale.of([10, 20], average: 10);

      expect(scale.highest, 1);
      expect(scale.lowest, isNull);
    });
  });
}
