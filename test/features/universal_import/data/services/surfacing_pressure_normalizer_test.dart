import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/services/surfacing_pressure_normalizer.dart';

/// Issue #1092: an exporting app that took its end pressure from the last
/// sample it saw inherits the post-surfacing bleed-down, exactly as a dive
/// computer does. Every file format converges on this payload shape, so one
/// pass covers FIT, UDDF, DL7, Subsurface, Ratio and the rest.
void main() {
  ImportPayload payloadWith(Map<String, dynamic> dive) => ImportPayload(
    entities: {
      ImportEntityType.dives: [dive],
    },
  );

  Map<String, dynamic> firstTank(ImportPayload payload) =>
      (payload.entitiesOf(ImportEntityType.dives).single['tanks']
              as List<Map<String, dynamic>>)
          .first;

  /// A rebreather oxygen cylinder still bleeding through its constant mass
  /// flow orifice while the recording runs on at the surface.
  Map<String, dynamic> bleedingOxygenDive() => {
    'tanks': <Map<String, dynamic>>[
      {'order': 0, 'startPressure': 200.0, 'endPressure': 4.0},
    ],
    'profile': <Map<String, dynamic>>[
      {
        'timestamp': 600,
        'depth': 51.0,
        'allTankPressures': [
          {'tankIndex': 0, 'pressure': 120.0},
        ],
      },
      {
        'timestamp': 3970,
        'depth': 1.2,
        'allTankPressures': [
          {'tankIndex': 0, 'pressure': 41.0},
        ],
      },
      {
        'timestamp': 4140,
        'depth': 0.0,
        'allTankPressures': [
          {'tankIndex': 0, 'pressure': 4.0},
        ],
      },
    ],
  };

  test('rewrites an end pressure that came from the surface tail', () {
    final result = trimTankPressuresAtSurfacing(
      payloadWith(bleedingOxygenDive()),
    );

    expect(firstTank(result)['endPressure'], 41.0);
  });

  test('leaves start pressure alone', () {
    final result = trimTankPressuresAtSurfacing(
      payloadWith(bleedingOxygenDive()),
    );

    expect(firstTank(result)['startPressure'], 200.0);
  });

  test('leaves the source payload unmutated', () {
    final original = payloadWith(bleedingOxygenDive());

    trimTankPressuresAtSurfacing(original);

    expect(firstTank(original)['endPressure'], 4.0);
  });

  test('keeps an end pressure the source did not take from the tail', () {
    // The exporting app wrote its own value. Overriding it would replace a
    // number with a provenance we know nothing about.
    final dive = bleedingOxygenDive();
    (dive['tanks'] as List<Map<String, dynamic>>).first['endPressure'] = 86.6;

    final result = trimTankPressuresAtSurfacing(payloadWith(dive));

    expect(firstTank(result)['endPressure'], 86.6);
  });

  test('leaves a dive whose recording ends at the surface untouched', () {
    final dive = bleedingOxygenDive();
    (dive['profile'] as List<Map<String, dynamic>>).removeLast();
    (dive['tanks'] as List<Map<String, dynamic>>).first['endPressure'] = 41.0;

    final result = trimTankPressuresAtSurfacing(payloadWith(dive));

    expect(firstTank(result)['endPressure'], 41.0);
  });

  test('matches a cylinder by its position in the tanks list', () {
    // allTankPressures.tankIndex indexes the tanks list, which is how the
    // entity importer resolves it.
    final dive = {
      'tanks': <Map<String, dynamic>>[
        {'order': 3, 'endPressure': 136.0},
        {'order': 7, 'endPressure': 4.0},
      ],
      'profile': <Map<String, dynamic>>[
        {
          'timestamp': 3970,
          'depth': 1.2,
          'allTankPressures': [
            {'tankIndex': 0, 'pressure': 136.0},
            {'tankIndex': 1, 'pressure': 41.0},
          ],
        },
        {
          'timestamp': 4140,
          'depth': 0.0,
          'allTankPressures': [
            {'tankIndex': 0, 'pressure': 136.0},
            {'tankIndex': 1, 'pressure': 4.0},
          ],
        },
      ],
    };

    final result = trimTankPressuresAtSurfacing(payloadWith(dive));
    final tanks =
        result.entitiesOf(ImportEntityType.dives).single['tanks']
            as List<Map<String, dynamic>>;

    expect(tanks[0]['endPressure'], 136.0);
    expect(tanks[1]['endPressure'], 41.0);
  });

  test('leaves a dive with no profile untouched', () {
    final dive = {
      'tanks': <Map<String, dynamic>>[
        {'order': 0, 'endPressure': 4.0},
      ],
    };

    final result = trimTankPressuresAtSurfacing(payloadWith(dive));

    expect(firstTank(result)['endPressure'], 4.0);
  });

  test('leaves a dive with no tanks untouched', () {
    final dive = {
      'profile': <Map<String, dynamic>>[
        {'timestamp': 0, 'depth': 10.0},
      ],
    };

    final result = trimTankPressuresAtSurfacing(payloadWith(dive));

    expect(
      result.entitiesOf(ImportEntityType.dives).single,
      isNot(contains('tanks')),
    );
  });

  test('carries warnings, metadata and other entity types through', () {
    final payload = ImportPayload(
      entities: {
        ImportEntityType.dives: [bleedingOxygenDive()],
        ImportEntityType.sites: [
          {'name': 'Blue Hole'},
        ],
      },
      warnings: const [
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message: 'something to keep',
          entityType: ImportEntityType.dives,
        ),
      ],
      metadata: const {'sourceApp': 'Garmin'},
    );

    final result = trimTankPressuresAtSurfacing(payload);

    expect(result.warnings, payload.warnings);
    expect(result.metadata, payload.metadata);
    expect(
      result.entitiesOf(ImportEntityType.sites),
      payload.entitiesOf(ImportEntityType.sites),
    );
  });

  test('leaves a dive whose deep samples carry no timestamp untouched', () {
    // A source that stamps only some of its samples cannot place surfacing.
    // Reading the unstamped ones as time zero would rank them before every
    // stamped sample, moving surfacing to the start of the dive and promoting
    // a mid-dive pressure into the end pressure.
    final dive = {
      'tanks': <Map<String, dynamic>>[
        {'order': 0, 'startPressure': 200.0, 'endPressure': 4.0},
      ],
      'profile': <Map<String, dynamic>>[
        {
          'depth': 51.0,
          'allTankPressures': [
            {'tankIndex': 0, 'pressure': 120.0},
          ],
        },
        {
          'depth': 30.0,
          'allTankPressures': [
            {'tankIndex': 0, 'pressure': 100.0},
          ],
        },
        {
          'timestamp': 3970,
          'depth': 0.5,
          'allTankPressures': [
            {'tankIndex': 0, 'pressure': 41.0},
          ],
        },
        {
          'timestamp': 4140,
          'depth': 0.0,
          'allTankPressures': [
            {'tankIndex': 0, 'pressure': 4.0},
          ],
        },
      ],
    };

    final result = trimTankPressuresAtSurfacing(payloadWith(dive));

    expect(firstTank(result)['endPressure'], 4.0);
  });

  test('ignores an unstamped sample when reading the surfacing pressure', () {
    // The unstamped sample sits in the middle of the descent. Dropping it
    // leaves the stamped samples to place surfacing, so the correction still
    // lands on the reading at 1.2 m rather than on the mid-dive value.
    final dive = bleedingOxygenDive();
    (dive['profile'] as List<Map<String, dynamic>>).insert(1, {
      'depth': 30.0,
      'allTankPressures': [
        {'tankIndex': 0, 'pressure': 100.0},
      ],
    });

    final result = trimTankPressuresAtSurfacing(payloadWith(dive));

    expect(firstTank(result)['endPressure'], 41.0);
  });
}
