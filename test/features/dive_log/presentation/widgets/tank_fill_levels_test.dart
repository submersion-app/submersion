import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_fill_levels.dart';

void main() {
  group('TankFillLevels.resolve', () {
    void expectLevels(TankFillLevels levels, {double? end, double? start}) {
      expect(levels.hasFill, isTrue);
      expect(levels.end, closeTo(end!, 1e-9));
      expect(levels.start, closeTo(start!, 1e-9));
    }

    test('measures start and end against the rated pressure', () {
      expectLevels(
        TankFillLevels.resolve(start: 200, end: 60, rated: 232),
        end: 60 / 232,
        start: 200 / 232,
      );
    });

    test('without a rated pressure the start is full', () {
      expectLevels(
        TankFillLevels.resolve(start: 200, end: 60),
        end: 60 / 200,
        start: 1.0,
      );
    });

    test('an overfill draws the tank full to the top', () {
      expectLevels(
        TankFillLevels.resolve(start: 220, end: 100, rated: 207),
        end: 100 / 207,
        start: 1.0,
      );
    });

    test('a tank carried but not breathed has no used zone', () {
      expectLevels(
        TankFillLevels.resolve(start: 200, end: 200, rated: 232),
        end: 200 / 232,
        start: 200 / 232,
      );
    });

    test('an end above the start draws an empty outline', () {
      expect(
        TankFillLevels.resolve(start: 100, end: 150, rated: 232).hasFill,
        isFalse,
      );
    });

    test('a missing end fills solid to the start', () {
      expectLevels(
        TankFillLevels.resolve(start: 200, rated: 232),
        end: 200 / 232,
        start: 200 / 232,
      );
    });

    test('a missing start with a rated pressure fills solid to the end', () {
      expectLevels(
        TankFillLevels.resolve(end: 60, rated: 232),
        end: 60 / 232,
        start: 60 / 232,
      );
    });

    test('an end with nothing to measure it against draws an outline', () {
      final levels = TankFillLevels.resolve(end: 60);
      expect(levels.hasFill, isFalse);
      expect(levels.end, isNull);
      expect(levels.start, isNull);
    });

    test('a negative reading counts as missing', () {
      // A sensor or entry error: never a level, never part of a used zone.
      expectLevels(
        TankFillLevels.resolve(start: 100, end: -10, rated: 232),
        end: 100 / 232,
        start: 100 / 232,
      );
      expect(
        TankFillLevels.resolve(start: -5, end: -10, rated: 232).hasFill,
        isFalse,
      );
      expect(TankFillLevels.resolve(start: -5, end: 60).hasFill, isFalse);
    });

    test('no pressures draws an outline', () {
      expect(TankFillLevels.resolve().hasFill, isFalse);
    });

    test('a zero or negative full pressure draws an outline', () {
      expect(TankFillLevels.resolve(start: 0, end: 0).hasFill, isFalse);
      expect(
        TankFillLevels.resolve(start: 100, end: 50, rated: 0).hasFill,
        isTrue,
        reason: 'a zero rated pressure is ignored in favour of the start',
      );
    });
  });

  group('spreadLabels', () {
    test('labels with room stay centred on their levels', () {
      expect(
        spreadLabels(centres: [10, 50, 90], heights: [12, 12, 12], extent: 100),
        [4, 44, 84],
      );
    });

    test('crowded labels are pushed apart by at least the gap', () {
      final tops = spreadLabels(
        centres: [20, 22, 24],
        heights: [12, 12, 12],
        extent: 100,
      );
      expect(tops[1], greaterThanOrEqualTo(tops[0] + 14));
      expect(tops[2], greaterThanOrEqualTo(tops[1] + 14));
    });

    test('labels crowded at the bottom stay within the extent', () {
      final tops = spreadLabels(
        centres: [96, 98, 99],
        heights: [12, 12, 12],
        extent: 100,
      );
      expect(tops.first, greaterThanOrEqualTo(0));
      expect(tops.last + 12, lessThanOrEqualTo(100));
      expect(tops[1], greaterThanOrEqualTo(tops[0] + 14));
      expect(tops[2], greaterThanOrEqualTo(tops[1] + 14));
    });

    test('labels crowded at the top stay within the extent', () {
      final tops = spreadLabels(
        centres: [0, 1, 2],
        heights: [12, 12, 12],
        extent: 100,
      );
      expect(tops.first, 0);
      expect(tops[2], greaterThanOrEqualTo(tops[1] + 14));
    });
  });

  group('tankFigureHeight', () {
    test('scales with volume between its bounds', () {
      expect(tankFigureHeight(5), 64);
      expect(tankFigureHeight(18), 104);
      expect(tankFigureHeight(11.5), closeTo(84, 1e-9));
    });

    test('clamps a pony and a set of doubles', () {
      expect(tankFigureHeight(2), 64);
      expect(tankFigureHeight(30), 104);
    });

    test('an unknown volume is drawn as a typical single tank', () {
      expect(tankFigureHeight(null), tankFigureHeight(11.1));
      expect(tankFigureHeight(0), tankFigureHeight(11.1));
    });
  });
}
