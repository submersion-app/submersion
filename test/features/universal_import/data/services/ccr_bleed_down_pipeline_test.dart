import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/surfacing_pressure_normalizer.dart';
import 'package:submersion/features/universal_import/data/services/tank_pressure_glitch_normalizer.dart';

/// Issue #1092 through the import normalizers, in the order the import
/// applies them: a CCR oxygen cylinder bleeds down to 4 bar through its
/// mass-flow orifice after surfacing, and the source took that last reading
/// as the end pressure. The drain is real, so the near-zero rule of issue
/// #2687 must not take it for a dropout.
void main() {
  Map<String, dynamic> point(int t, double depth, double bar) => {
    'timestamp': t,
    'depth': depth,
    'allTankPressures': [
      {'tankIndex': 0, 'pressure': bar},
    ],
  };

  final payload = ImportPayload(
    entities: {
      ImportEntityType.dives: [
        {
          'tanks': <Map<String, dynamic>>[
            {'order': 0, 'startPressure': 200.0, 'endPressure': 4.0},
          ],
          'profile': <Map<String, dynamic>>[
            point(0, 0.0, 200),
            point(600, 40.0, 120),
            point(3970, 1.2, 41),
            point(4000, 0.0, 30),
            point(4090, 0.0, 4),
          ],
        },
      ],
    },
  );

  double? endPressure(ImportPayload result) =>
      ((result.entitiesOf(ImportEntityType.dives).single['tanks'] as List)
                  .single
              as Map<String, dynamic>)['endPressure']
          as double?;

  test('the series agrees with the end, so the glitch rule keeps it', () {
    // What a diver with the surfacing preference off gets.
    expect(endPressure(replaceGlitchedTankPressures(payload)), 4.0);
  });

  test('the surfacing rule still records the pressure at surfacing', () {
    final result = trimTankPressuresAtSurfacing(
      replaceGlitchedTankPressures(payload),
    );
    expect(endPressure(result), 41.0);
  });
}
