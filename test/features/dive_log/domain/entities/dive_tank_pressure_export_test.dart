import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';

import '../../../../helpers/tank_pressure_export_fixtures.dart';

void main() {
  group('DiveTankPressureExport.displayedByTank (issue #2492)', () {
    test('keeps only the primary source where two recorded one tank', () {
      // Two file imports of one dive, consolidated: each recorded the same
      // cylinder, a second apart. Interleaving them is the #2440 zigzag.
      final export = DiveTankPressureExport(
        primarySourceId: 'src-b',
        series: [
          testTankSeries(
            's-a',
            tankId: 'tank-1',
            sourceId: 'src-a',
            samples: [(0, 200), (10, 190), (20, 180)],
          ),
          testTankSeries(
            's-b',
            tankId: 'tank-1',
            sourceId: 'src-b',
            samples: [(1, 205), (11, 195), (21, 185)],
          ),
        ],
      );

      expect(export.displayedByTank, {
        'tank-1': const [
          TankPressurePoint(tankId: 'tank-1', timestamp: 1, pressure: 205),
          TankPressurePoint(tankId: 'tank-1', timestamp: 11, pressure: 195),
          TankPressurePoint(tankId: 'tank-1', timestamp: 21, pressure: 185),
        ],
      });
    });

    test('keeps every source of a tank that recorded one after another', () {
      // A combined dive: the second source starts where the first ends.
      final export = DiveTankPressureExport(
        primarySourceId: 'src-a',
        series: [
          testTankSeries(
            's-a',
            tankId: 'tank-1',
            sourceId: 'src-a',
            samples: [(0, 200), (10, 190)],
          ),
          testTankSeries(
            's-b',
            tankId: 'tank-1',
            sourceId: 'src-b',
            samples: [(20, 180), (30, 170)],
          ),
        ],
      );

      expect(
        [for (final p in export.displayedByTank['tank-1']!) p.timestamp],
        [0, 10, 20, 30],
      );
    });

    test('groups by tank and keeps a tank only one source recorded', () {
      final export = DiveTankPressureExport(
        series: [
          testTankSeries('s-1', tankId: 'tank-1', samples: [(0, 200)]),
          testTankSeries(
            's-2',
            tankId: 'tank-2',
            sourceId: 'src-b',
            samples: [(0, 210)],
          ),
        ],
      );

      expect(export.displayedByTank.keys, ['tank-1', 'tank-2']);
    });

    test('is empty for a dive with no series', () {
      expect(const DiveTankPressureExport(series: []).displayedByTank, {});
    });
  });
}
