import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
import '../../../tool/demo_data/src/seeders/gear_catalog.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../../tool/demo_data/src/shape/dive_shape.dart';
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

  test('winter air at the lakes is cold', () async {
    final winter = await rows(
      "SELECT air_temp AS a FROM dives WHERE site_id IN "
      "(SELECT id FROM dive_sites WHERE region = 'Bayern') "
      "AND strftime('%m', dive_date_time / 1000, 'unixepoch') IN ('01', '02')",
    );
    expect(winter, isNotEmpty);
    for (final w in winter) {
      expect(w['a'] as double, lessThan(14));
    }
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

  test('boat tracks carry their destination time zone', () async {
    final tracks = await rows(
      'SELECT DISTINCT tz_offset_minutes AS z FROM gps_tracks',
    );
    expect(tracks.length, greaterThan(1));
  });
}
