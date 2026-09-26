import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/tank_pressure_glitch_normalizer.dart';

/// Issue #2441: an exporting app that took a cylinder's start or end
/// pressure from the first or last reading of its series inherits a
/// transmitter dropout sitting there.
void main() {
  ImportPayload payloadWith(Map<String, dynamic> dive) => ImportPayload(
    entities: {
      ImportEntityType.dives: [dive],
    },
  );

  Map<String, dynamic> firstTank(ImportPayload payload) =>
      (payload.entitiesOf(ImportEntityType.dives).single['tanks'] as List).first
          as Map<String, dynamic>;

  Map<String, dynamic> point(int t, double pressure) => {
    'timestamp': t,
    'depth': 20.0,
    'allTankPressures': [
      {'tankIndex': 0, 'pressure': pressure},
    ],
  };

  /// 3.9 bar before the valve was open, then 200 draining to ~80 bar, with a
  /// dropout at t=1200.
  Map<String, dynamic> dive({double start = 3.9, double end = 80.5}) => {
    'tanks': <Map<String, dynamic>>[
      {'order': 0, 'startPressure': start, 'endPressure': end},
    ],
    'profile': <Map<String, dynamic>>[
      point(0, 3.9),
      for (var t = 10; t <= 2400; t += 10)
        point(t, t == 1200 ? 0.8 : 200 - t * 0.05),
    ],
  };

  test('replaces a start pressure taken from a lead-in reading', () {
    final result = replaceGlitchedTankPressures(payloadWith(dive()));
    expect(firstTank(result)['startPressure'], closeTo(199.5, 1e-9));
    expect(firstTank(result)['endPressure'], 80.5);
  });

  test('replaces an end pressure taken from a dropout', () {
    final result = replaceGlitchedTankPressures(
      payloadWith(dive(start: 200, end: 0.8)),
    );
    expect(firstTank(result)['startPressure'], 200);
    expect(firstTank(result)['endPressure'], closeTo(80.0, 1e-9));
  });

  test('leaves header pressures that match no glitch alone', () {
    final source = dive(start: 210, end: 75);
    final result = replaceGlitchedTankPressures(payloadWith(source));
    expect(identical(firstTank(result), source['tanks'][0]), isTrue);
  });

  test('leaves the source payload unmutated', () {
    final source = dive();
    replaceGlitchedTankPressures(payloadWith(source));
    expect((source['tanks'] as List).first['startPressure'], 3.9);
  });

  test('a dive without a profile comes through untouched', () {
    final source = {
      'tanks': <Map<String, dynamic>>[
        {'order': 0, 'startPressure': 3.9, 'endPressure': 80.0},
      ],
    };
    final result = replaceGlitchedTankPressures(payloadWith(source));
    expect(
      identical(result.entitiesOf(ImportEntityType.dives).single, source),
      isTrue,
    );
  });
}
