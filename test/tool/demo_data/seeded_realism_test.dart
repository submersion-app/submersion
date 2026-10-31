import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
import '../../../tool/demo_data/src/seeders/dive_kit.dart';
import '../../../tool/demo_data/src/seeders/gear_catalog.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/story/destination_life.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';
import '../../helpers/test_database.dart';
import 'seed_harness.dart';

/// The seeded logbook as a diver reading it would judge it.
void main() {
  late DemoSeedContext ctx;

  setUpAll(() async {
    ctx = await seedContext();
    await seedAll(ctx);
  });

  tearDownAll(tearDownTestDatabase);

  Future<List<Map<String, Object?>>> rows(String sql) async => [
    for (final r in await ctx.db.customSelect(sql).get()) r.data,
  ];

  bool atHome(DateTime when) => !ctx.plan.trips.any(
    (t) =>
        !when.isBefore(DateTime(t.start.year, t.start.month, t.start.day)) &&
        when.isBefore(DateTime(t.end.year, t.end.month, t.end.day + 1)),
  );

  test('the swapped-in cell is fitted for the last rebreather dives', () async {
    final fitted = ctx.timeline.boughtOn('o2-cell-2b')!;
    final after = ctx.plan.dives.where(
      (d) => d.diveMode == 'ccr' && d.start.isAfter(fitted),
    );
    expect(after.length, greaterThanOrEqualTo(4));
  });

  test('nothing in the gear history is dated after the anchor', () async {
    final anchor = ctx.anchor.millisecondsSinceEpoch;
    for (final (table, column) in [
      ('service_records', 'service_date'),
      ('equipment_location_moves', 'moved_at'),
      ('equipment_locations', 'created_at'),
      ('equipment_ownership_events', 'occurred_at'),
      ('equipment_shares', 'created_at'),
      ('equipment_observations', 'observed_at'),
      ('cylinder_fills', 'filled_at'),
      ('service_schedules', 'created_at'),
    ]) {
      final latest = await rows('SELECT MAX($column) AS m FROM $table');
      expect(
        latest.single['m'] as int,
        lessThanOrEqualTo(anchor),
        reason: '$table.$column',
      );
    }
  });

  test('each ownership event is dated by its own item', () async {
    final events = await rows(
      'SELECT equipment_id AS e, occurred_at AS at '
      'FROM equipment_ownership_events',
    );
    final keyOf = {for (final e in ctx.equipment.entries) e.value: e.key};
    expect(
      events.map((e) => keyOf[e['e']]),
      containsAll(['bcd-jacket', 'fins']),
    );
    for (final e in events) {
      final key = keyOf[e['e']]!;
      final expected = key == 'bcd-jacket'
          ? ctx.timeline.leftOn(key)!
          : ctx.timeline.boughtOn(key)!;
      expect(e['at'], expected.millisecondsSinceEpoch, reason: key);
    }
  });

  test('every technical dive was written from a shape of its kinds', () {
    for (final d in ctx.plan.dives) {
      if (d.wantedKinds.contains(ShapeKind.recreational)) continue;
      expect(
        ctx.pickedKinds[d.number],
        containsAll(d.wantedKinds),
        reason: 'dive ${d.number}',
      );
    }
  });

  test('a trimix training dive breathes trimix', () async {
    final tanks = await rows(
      "SELECT t.he_percent AS he FROM dive_tanks t JOIN dives d ON d.id = t.dive_id "
      "JOIN dive_courses c ON c.dive_id = d.id WHERE c.course_id = 'course-trimix' "
      'AND t.tank_order = 0',
    );
    expect(tanks, isNotEmpty);
    for (final t in tanks) {
      expect(t['he'] as double, greaterThanOrEqualTo(35));
    }
  });

  test('a replacement arrives on a later day than its predecessor left', () {
    // The app counts a fitted part's dives by its install day, whole days
    // at a time, so a part swapped in mid-day would take over the morning's
    // dives of the part it replaced.
    DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);
    final replacements = demoGear.where((g) => g.replaces != null);
    expect(replacements, isNotEmpty);
    for (final g in replacements) {
      final arrived = day(ctx.timeline.boughtOn(g.key)!);
      final left = day(ctx.timeline.leftOn(g.replaces!)!);
      expect(arrived.isAfter(left), isTrue, reason: '${g.key}: $arrived');
    }
  });

  test('gear leaves on a home day, unless it was lost on a trip', () {
    for (final g in demoGear.where((g) => g.leaves != null)) {
      if (g.leaves!.status == EquipmentStatus.lost) continue;
      expect(atHome(ctx.timeline.leftOn(g.key)!), isTrue, reason: g.key);
    }
  });

  test('a liveaboard dive names the trip boat', () async {
    final boats = {
      for (final t in ctx.plan.trips)
        if (t.boatName != null) t.id: t.boatName,
    };
    final fields = await rows(
      "SELECT d.trip_id AS trip, f.field_value AS v FROM dive_custom_fields f "
      "JOIN dives d ON d.id = f.dive_id WHERE f.field_key = 'Boat'",
    );
    expect(fields, isNotEmpty);
    for (final f in fields) {
      expect(f['v'], boats[f['trip']]);
    }
  });

  test(
    'shore dives are entered from the shore, boat dives from a boat',
    () async {
      final dives = await rows('SELECT id, entry_method AS e FROM dives');
      final byId = {for (final d in dives) d['id']: d['e']};
      for (final d in ctx.plan.dives) {
        expect(
          byId[ctx.diveId(d.number)],
          d.boat ? 'backRoll' : 'shore',
          reason: 'dive ${d.number}',
        );
      }
    },
  );

  test('the diver logs in US units', () async {
    final settings = await rows(
      'SELECT depth_unit AS d, temperature_unit AS t, pressure_unit AS p, '
      'volume_unit AS v, weight_unit AS w FROM diver_settings '
      "WHERE diver_id = '${DemoSeedContext.diverId}'",
    );
    expect(settings.single, {
      'd': 'feet',
      't': 'fahrenheit',
      'p': 'psi',
      'v': 'cubicFeet',
      'w': 'pounds',
    });
  });

  test('home recreational dives breathe from a steel HP100', () async {
    final tanks = await rows(
      'SELECT t.volume AS v, t.working_pressure AS wp FROM dive_tanks t '
      'JOIN dives d ON d.id = t.dive_id WHERE d.trip_id IS NULL '
      "AND d.dive_mode = 'oc' AND (SELECT COUNT(*) FROM dive_tanks x "
      'WHERE x.dive_id = d.id) = 1',
    );
    expect(tanks, isNotEmpty);
    for (final t in tanks) {
      expect(t['v'] as double, closeTo(12.9, 0.05));
      // 3442 psi.
      expect(t['wp'] as double, closeTo(237.3, 0.1));
    }
  });

  test('spring air on the New Jersey coast is cool, summer air warm', () async {
    // Home diving keeps to the boat season, April to November.
    Future<List<double>> air(String month) async => [
      for (final r in await rows(
        "SELECT air_temp AS a FROM dives WHERE site_id IN "
        "(SELECT id FROM dive_sites WHERE region = 'New Jersey') "
        "AND strftime('%m', dive_date_time / 1000, 'unixepoch') = '$month'",
      ))
        r['a']! as double,
    ];
    final april = await air('04');
    final august = await air('08');
    expect(april, isNotEmpty);
    expect(august, isNotEmpty);
    for (final a in april) {
      expect(a, lessThan(22));
    }
    double mean(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    expect(mean(august) - mean(april), greaterThan(5));
  });

  test('dive centre notes vary', () async {
    final notes = await rows(
      'SELECT DISTINCT note FROM dive_center_gear_notes',
    );
    expect(notes.length, greaterThanOrEqualTo(8));
  });

  test('no nitrox fill before the nitrox card', () async {
    final card = ctx.plan.certs
        .firstWhere((c) => c.level == CertLevel.nitrox)
        .issueDate;
    final early = await rows(
      'SELECT o2_percent AS o FROM cylinder_fills WHERE filled_at < '
      '${card.millisecondsSinceEpoch}',
    );
    for (final f in early) {
      expect(f['o'] as double, 21);
    }
  });

  test('water temperatures change smoothly and fit the water', () async {
    final dives = DiveRepository();
    for (final d in ctx.plan.dives.where((d) => d.number % 7 == 0)) {
      final temps = [
        for (final p in await dives.getDiveProfile(ctx.diveId(d.number)))
          if (p.temperature != null) p.temperature!,
      ];
      expect(temps, isNotEmpty, reason: 'dive ${d.number}');
      for (var i = 1; i < temps.length - 1; i++) {
        expect(
          temps[i - 1] == temps[i + 1] && temps[i] != temps[i - 1],
          isFalse,
          reason: 'dive ${d.number} flickers at sample $i',
        );
      }
      final (lo, hi) = d.destination.waterTempC;
      if (hi - lo < 6) {
        expect(
          temps.reduce(max) - temps.reduce(min),
          lessThanOrEqualTo(2.5),
          reason: 'dive ${d.number} at ${d.destination.key}',
        );
      }
    }
  });

  group('photos', () {
    late List<Map<String, Object?>> photos;
    late Map<String, PlannedDive> diveById;

    setUpAll(() async {
      photos = await rows(
        'SELECT m.dive_id AS dive, m.original_filename AS file, '
        'm.taken_at AS taken, d.dive_date_time AS start, d.runtime AS runtime, '
        'e.depth_meters AS depth, e.temperature_celsius AS temp, '
        'e.elapsed_seconds AS elapsed '
        'FROM media m JOIN dives d ON d.id = m.dive_id '
        'JOIN media_enrichment e ON e.media_id = m.id',
      );
      diveById = {for (final d in ctx.plan.dives) ctx.diveId(d.number): d};
    });

    test('every photo is linked to a dive', () {
      expect(photos, hasLength(testPhotos.length));
    });

    test('every photo is on a camera dive where its subject lives', () {
      final subjects = {for (final p in testPhotos) p.fileName: p.subject};
      for (final photo in photos) {
        final d = diveById[photo['dive']]!;
        final subject = subjects[photo['file']]!;
        expect(
          isPhotoDive(d, ctx.timeline),
          isTrue,
          reason: '${photo['file']} on dive ${d.number}',
        );
        final key = d.destination.key;
        expect(
          [...destinationSpecies[key]!, ...destinationSiteTypes[key]!],
          contains(subject),
          reason: '${photo['file']} at $key',
        );
      }
    });

    test('a dive keeps at most three photos, each at its own moment', () {
      final byDive = <Object?, List<Map<String, Object?>>>{};
      for (final photo in photos) {
        byDive.putIfAbsent(photo['dive'], () => []).add(photo);
      }
      expect(byDive.length, greaterThan(1));
      for (final list in byDive.values) {
        expect(list.length, lessThanOrEqualTo(3));
        expect({for (final p in list) p['taken']}, hasLength(list.length));
        for (final p in list) {
          final into = (p['taken']! as int) - (p['start']! as int);
          expect(into, greaterThan(0), reason: '${p['file']}');
          expect(
            into,
            lessThan((p['runtime']! as int) * 1000),
            reason: '${p['file']}',
          );
        }
      }
    });

    test('a photo records the depth and temperature of its moment', () async {
      final dives = DiveRepository();
      for (final photo in photos) {
        final profile = await dives.getDiveProfile(photo['dive']! as String);
        final at = profile.lastWhere(
          (p) => p.timestamp <= (photo['elapsed']! as int),
        );
        expect(photo['depth'], at.depth, reason: '${photo['file']}');
        expect(photo['temp'], at.temperature, reason: '${photo['file']}');
      }
    });
  });

  test('boat tracks carry their destination time zone', () async {
    final tracks = await rows(
      'SELECT DISTINCT tz_offset_minutes AS z FROM gps_tracks',
    );
    expect(tracks.length, greaterThan(1));
  });

  group('saved what-ifs', () {
    Future<List<DiveScenario>> saved() async {
      final repository = DiveScenarioRepository();
      final ids = await rows('SELECT id FROM dive_scenarios ORDER BY id');
      return [
        for (final row in ids)
          (await repository.getScenario(row['id']! as String))!,
      ];
    }

    test('each one replays or re-plans in the Dive Lab', () async {
      final dives = DiveRepository();
      final scenarios = await saved();
      expect({
        for (final s in scenarios) s.effectiveMode,
      }, containsAll(ScenarioMode.values));

      for (final scenario in scenarios) {
        final dive = (await dives.getDiveById(scenario.diveId))!;
        final profile = await dives.getDiveProfile(scenario.diveId);
        final switches = await dives.getGasSwitchesForDive(scenario.diveId);
        expect(validateInterventions(scenario.interventions), isEmpty);
        expect(
          scenario.branchSeconds,
          inInclusiveRange(0, profile.last.timestamp),
        );

        final outcome = const ScenarioEngine().run(
          ScenarioRequest(
            diveId: scenario.diveId,
            depths: [for (final p in profile) p.depth],
            timestamps: [for (final p in profile) p.timestamp],
            diveMode: dive.diveMode,
            tanks: dive.tanks,
            gasSwitches: [
              for (final s in switches)
                ScenarioGasSwitch(timestamp: s.timestamp, tankId: s.tankId),
            ],
            scenario: scenario,
          ),
        );

        expect(
          outcome.flags.map((f) => f.kind),
          isNot(contains(ScenarioFlagKind.replanNotCompletable)),
          reason: scenario.name,
        );
        expect(outcome.deltas, isNotEmpty, reason: scenario.name);
      }
    });

    test('the nitrox question is asked of a dive breathed on air', () async {
      final scenarios = await saved();
      final nitrox = scenarios.singleWhere(
        (s) => s.interventions.any((i) => i is SwitchGasIntervention),
      );

      final tanks = await rows(
        'SELECT o2_percent AS o2, he_percent AS he FROM dive_tanks '
        "WHERE dive_id = '${nitrox.diveId}'",
      );

      expect(tanks, [
        {'o2': 21.0, 'he': 0.0},
      ]);
    });
  });
}
