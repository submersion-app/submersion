import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
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

  test('keeps the payload source divers', () {
    // A multi-diver import (#1893) must still offer its Divers step after
    // this normalizer rebuilt the payload.
    const divers = [SourceDiver(key: 'd1', name: 'Anna')];
    final result = replaceGlitchedTankPressures(
      ImportPayload(
        entities: {
          ImportEntityType.dives: [dive()],
        },
        sourceDivers: divers,
      ),
    );
    expect(result.sourceDivers, divers);
  });

  test('a dive without a profile comes through untouched', () {
    final source = {
      'tanks': <Map<String, dynamic>>[
        {'order': 0, 'startPressure': 210.0, 'endPressure': 80.0},
      ],
    };
    final result = replaceGlitchedTankPressures(payloadWith(source));
    expect(
      identical(result.entitiesOf(ImportEntityType.dives).single, source),
      isTrue,
    );
  });

  // Issue #2687: a near-zero header pressure that matches no reading of the
  // series is no less a dropout than one that does.
  group('near-zero endpoints', () {
    test('an end the series contradicts takes its last clean reading', () {
      // 2.5 bar is more than the match tolerance away from both the 3.9 bar
      // lead-in and the 0.8 bar dropout, so no glitch rule claims it.
      final result = replaceGlitchedTankPressures(
        payloadWith(dive(start: 200, end: 2.5)),
      );
      expect(firstTank(result)['startPressure'], 200);
      expect(firstTank(result)['endPressure'], closeTo(80.0, 1e-9));
    });

    test('both rules apply to one tank', () {
      // The start matches the 3.9 bar lead-in (#2441); the end matches no
      // reading (#2687).
      final result = replaceGlitchedTankPressures(
        payloadWith(dive(start: 3.9, end: 2.5)),
      );
      expect(firstTank(result)['startPressure'], closeTo(199.5, 1e-9));
      expect(firstTank(result)['endPressure'], closeTo(80.0, 1e-9));
    });

    test('an end with no series is cleared when the start is real', () {
      final result = replaceGlitchedTankPressures(
        payloadWith({
          'tanks': <Map<String, dynamic>>[
            {'order': 0, 'startPressure': 200.0, 'endPressure': 0.46},
          ],
        }),
      );
      expect(firstTank(result)['startPressure'], 200.0);
      expect(firstTank(result).containsKey('endPressure'), isTrue);
      expect(firstTank(result)['endPressure'], isNull);
    });

    test('a start with no series is cleared when the end is real', () {
      final result = replaceGlitchedTankPressures(
        payloadWith({
          'tanks': <Map<String, dynamic>>[
            {'order': 0, 'startPressure': 0.4, 'endPressure': 60.0},
          ],
        }),
      );
      expect(firstTank(result)['startPressure'], isNull);
      expect(firstTank(result)['endPressure'], 60.0);
    });

    test('a tank without its own series is judged without one', () {
      // Tank 1 has no readings, though tank 0 does.
      final source = dive(start: 200, end: 80.5);
      source['tanks'] = <Map<String, dynamic>>[
        ...(source['tanks'] as List<Map<String, dynamic>>),
        {'order': 1, 'startPressure': 190.0, 'endPressure': 0.34},
      ];
      final result = replaceGlitchedTankPressures(payloadWith(source));
      final tanks =
          result.entitiesOf(ImportEntityType.dives).single['tanks'] as List;
      expect(tanks[0]['endPressure'], 80.5);
      expect(tanks[1]['startPressure'], 190.0);
      expect(tanks[1]['endPressure'], isNull);
    });

    test('a tank near zero at both ends is left alone', () {
      final source = {
        'tanks': <Map<String, dynamic>>[
          {'order': 0, 'startPressure': 0.3, 'endPressure': 0.2},
        ],
      };
      final result = replaceGlitchedTankPressures(payloadWith(source));
      expect(
        identical(result.entitiesOf(ImportEntityType.dives).single, source),
        isTrue,
      );
    });
  });
}
