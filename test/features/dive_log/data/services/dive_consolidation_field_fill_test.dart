import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_field_fill.dart';

import '../../../../helpers/test_database.dart';

Dive row(String id) => Dive(
  id: id,
  diveDateTime: 0,
  diveType: 'recreational',
  notes: '',
  isFavorite: false,
  excludedFromStats: false,
  excludedFromGasStats: false,
  diveMode: 'oc',
  cnsStart: 0,
  isPlanned: false,
  createdAt: 0,
  updatedAt: 0,
);

/// The value [fill] writes to [column], or null when it leaves it alone.
Object? filled(Map<String, Expression> fill, String column) =>
    (fill[column] as Variable?)?.value;

/// The fill for a target with no profile of its own, unless [hasProfile].
Map<String, Expression> fillOf(
  Dive target,
  List<Dive> secondaries, {
  bool hasProfile = false,
}) => consolidationFieldFill(target, secondaries, targetHasProfile: hasProfile);

void main() {
  group('consolidationFieldFill (#2932)', () {
    test('an empty target adopts conditions, logistics and measurements '
        'from a secondary', () {
      final target = row('t');
      final secondary = row('s').copyWith(
        name: const Value('Blue Hole'),
        waterTemp: const Value(24.5),
        airTemp: const Value(30),
        maxDepth: const Value(31.2),
        currentStrength: const Value('moderate'),
        entryMethod: const Value('boat'),
        diveCenterId: const Value('center-1'),
        tripId: const Value('trip-1'),
        courseId: const Value('course-1'),
        rating: const Value(4),
        boatName: const Value('Sea Lion'),
        weightAmount: const Value(6),
      );

      final fill = fillOf(target, [secondary]);

      expect(filled(fill, 'name'), 'Blue Hole');
      expect(filled(fill, 'water_temp'), 24.5);
      expect(filled(fill, 'air_temp'), 30);
      expect(filled(fill, 'max_depth'), 31.2);
      expect(filled(fill, 'current_strength'), 'moderate');
      expect(filled(fill, 'entry_method'), 'boat');
      expect(filled(fill, 'dive_center_id'), 'center-1');
      expect(filled(fill, 'trip_id'), 'trip-1');
      expect(filled(fill, 'course_id'), 'course-1');
      expect(filled(fill, 'rating'), 4);
      expect(filled(fill, 'boat_name'), 'Sea Lion');
      expect(filled(fill, 'weight_amount'), 6);
    });

    test('a target with a profile keeps the measurements it derives from '
        'it', () {
      final secondary = row('s').copyWith(
        maxDepth: const Value(31.2),
        avgDepth: const Value(14),
        bottomTime: const Value(1800),
        waterTemp: const Value(24.5),
        airTemp: const Value(30),
      );

      final fill = fillOf(row('t'), [secondary], hasProfile: true);

      expect(fill.containsKey('max_depth'), isFalse);
      expect(fill.containsKey('avg_depth'), isFalse);
      expect(fill.containsKey('bottom_time'), isFalse);
      expect(fill.containsKey('water_temp'), isFalse);
      expect(filled(fill, 'air_temp'), 30);
    });

    test('a value the target already holds is never overwritten', () {
      final target = row(
        't',
      ).copyWith(waterTemp: const Value(20), siteId: const Value('site-t'));
      final secondary = row(
        's',
      ).copyWith(waterTemp: const Value(24.5), siteId: const Value('site-s'));

      final fill = fillOf(target, [secondary]);

      expect(fill.containsKey('water_temp'), isFalse);
      expect(fill.containsKey('site_id'), isFalse);
    });

    test('the first secondary holding a value wins', () {
      final fill = fillOf(row('t'), [
        row('s1'),
        row('s2').copyWith(waterTemp: const Value(22)),
        row('s3').copyWith(waterTemp: const Value(26)),
      ]);

      expect(filled(fill, 'water_temp'), 22);
    });

    test('nothing to fill yields an empty map', () {
      expect(fillOf(row('t'), [row('s')]), isEmpty);
    });

    test('identity, timeline, computer and provenance columns are never '
        'copied', () {
      final secondary = row('s').copyWith(
        diverId: const Value('diver-s'),
        entryTime: const Value(1000),
        exitTime: const Value(2000),
        computerId: const Value('comp-s'),
        diveComputerModel: const Value('Perdix'),
        diveComputerSerial: const Value('SER-S'),
        diveComputerFirmware: const Value('92'),
        importSource: const Value('uddf'),
        importId: const Value('imp-1'),
        importVersion: const Value(1),
        outingId: const Value('outing-s'),
        hlc: const Value('hlc-s'),
        siteSuggestionDismissedAt: const Value(5),
      );

      expect(fillOf(row('t'), [secondary]), isEmpty);
    });

    test('O2 exposure is not borrowed from another computer, since the '
        'target keeps its own CNS start', () {
      final secondary = row(
        's',
      ).copyWith(cnsEnd: const Value(12), otu: const Value(30));

      expect(fillOf(row('t'), [secondary]), isEmpty);
    });

    test('a secondary\'s dive number is not adopted', () {
      final secondary = row('s').copyWith(diveNumber: const Value(512));

      expect(fillOf(row('t'), [secondary]), isEmpty);
    });

    test('deco settings are not borrowed from another computer', () {
      final secondary = row('s').copyWith(
        gradientFactorLow: const Value(30),
        gradientFactorHigh: const Value(70),
        decoAlgorithm: const Value('buhlmann'),
        decoConservatism: const Value(2),
        computerTissueJson: const Value('{}'),
      );

      expect(fillOf(row('t'), [secondary]), isEmpty);
    });

    test('GPS fills as a pair, and a half fix does not count', () {
      final fill = fillOf(row('t'), [
        row('s1').copyWith(entryLatitude: const Value(1)),
        row('s2').copyWith(
          entryLatitude: const Value(2),
          entryLongitude: const Value(3),
        ),
      ]);

      expect(filled(fill, 'entry_latitude'), 2);
      expect(filled(fill, 'entry_longitude'), 3);
    });

    group('blocks come whole from one secondary', () {
      test('weather', () {
        final target = row('t');
        final fill = fillOf(target, [
          row('s1').copyWith(windSpeed: const Value(4)),
          row('s2').copyWith(
            windSpeed: const Value(9),
            humidity: const Value(80),
            weatherSource: const Value('openMeteo'),
          ),
        ]);

        expect(filled(fill, 'wind_speed'), 4);
        expect(filled(fill, 'humidity'), isNull);
        expect(filled(fill, 'weather_source'), isNull);
      });

      test('a target with any weather keeps its block', () {
        final fill = fillOf(
          row('t').copyWith(cloudCover: const Value('clear')),
          [row('s').copyWith(windSpeed: const Value(9))],
        );

        expect(fill.containsKey('wind_speed'), isFalse);
      });

      test('rebreather settings', () {
        final fill = fillOf(row('t'), [
          row('s').copyWith(
            setpointLow: const Value(0.7),
            setpointHigh: const Value(1.3),
            diluentO2: const Value(21),
            diluentHe: const Value(35),
            scrubberType: const Value('Sofnolime 797'),
          ),
        ]);

        expect(filled(fill, 'setpoint_low'), 0.7);
        expect(filled(fill, 'setpoint_high'), 1.3);
        expect(filled(fill, 'diluent_o2'), 21);
        expect(filled(fill, 'diluent_he'), 35);
        expect(filled(fill, 'scrubber_type'), 'Sofnolime 797');
      });

      test('a target with any rebreather setting keeps its block', () {
        final fill = fillOf(row('t').copyWith(setpointHigh: const Value(1.2)), [
          row(
            's',
          ).copyWith(setpointLow: const Value(0.7), diluentO2: const Value(21)),
        ]);

        expect(fill.containsKey('setpoint_low'), isFalse);
        expect(fill.containsKey('diluent_o2'), isFalse);
      });

      test('weighting feedback', () {
        final fill = fillOf(row('t'), [
          row('s').copyWith(
            weightingFeedback: const Value('overweighted'),
            weightingFeedbackKg: const Value(2),
          ),
        ]);

        expect(filled(fill, 'weighting_feedback'), 'overweighted');
        expect(filled(fill, 'weighting_feedback_kg'), 2);
      });
    });

    group('visibility (#3226)', () {
      test('a range is copied whole', () {
        final fill = fillOf(row('t'), [
          row('s').copyWith(
            visibilityMinMeters: const Value(10),
            visibilityMaxMeters: const Value(20),
          ),
        ]);

        expect(filled(fill, 'visibility_min_meters'), 10);
        expect(filled(fill, 'visibility_max_meters'), 20);
        expect(filled(fill, 'visibility_meters'), isNull);
      });

      test('a target holding only the legacy bucket keeps it', () {
        final fill = fillOf(
          row('t').copyWith(visibility: const Value('good')),
          [row('s').copyWith(visibilityMeters: const Value(15))],
        );

        expect(fill.containsKey('visibility_meters'), isFalse);
      });

      test('the legacy bucket is never written', () {
        final fill = fillOf(row('t'), [
          row('s').copyWith(visibility: const Value('good')),
        ]);

        expect(fill.containsKey('visibility'), isFalse);
      });
    });

    group('notes', () {
      test('blank target notes adopt a secondary\'s', () {
        final fill = fillOf(row('t').copyWith(notes: '  '), [
          row('s1').copyWith(notes: ' '),
          row('s2').copyWith(notes: 'Turtle at the wall'),
        ]);

        expect(filled(fill, 'notes'), 'Turtle at the wall');
      });

      test('target notes are kept', () {
        final fill = fillOf(row('t').copyWith(notes: 'Mine'), [
          row('s').copyWith(notes: 'Theirs'),
        ]);

        expect(fill.containsKey('notes'), isFalse);
      });
    });

    group('statistics exclusions', () {
      test('an exclusion on any secondary survives', () {
        final fill = fillOf(row('t'), [
          row(
            's',
          ).copyWith(excludedFromStats: true, excludedFromGasStats: true),
        ]);

        expect(filled(fill, 'excluded_from_stats'), isTrue);
        expect(filled(fill, 'excluded_from_gas_stats'), isTrue);
      });

      test('a secondary never clears the target\'s exclusion', () {
        final fill = fillOf(row('t').copyWith(excludedFromStats: true), [
          row('s'),
        ]);

        expect(fill.containsKey('excluded_from_stats'), isFalse);
      });

      test('the favorite flag is left alone', () {
        final fill = fillOf(row('t'), [row('s').copyWith(isFavorite: true)]);

        expect(fill.containsKey('is_favorite'), isFalse);
      });
    });
  });

  // A column added to the dives table must be classified here before it
  // ships: either filled by consolidation or listed with the reason it is
  // not. Otherwise a new dive field is silently dropped when its dive is
  // folded into another.
  group('every dives column is classified', () {
    late AppDatabase db;

    setUp(() async => db = await setUpTestDatabase());
    tearDown(tearDownTestDatabase);

    test('filled and unfilled columns partition the table', () {
      final all = {for (final c in db.dives.$columns) c.name};
      final unfilled = consolidationUnfilledColumns.keys.toSet();

      expect(
        consolidationFilledColumns.intersection(unfilled),
        isEmpty,
        reason: 'a column cannot be both filled and unfilled',
      );
      expect(
        consolidationFilledColumns.union(unfilled),
        all,
        reason:
            'every dives column must be either filled by consolidation or '
            'listed in consolidationUnfilledColumns with a reason',
      );
    });

    test('every unfilled column says why', () {
      for (final entry in consolidationUnfilledColumns.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });
  });
}
