import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/seeders/dive_seeder.dart';
import '../../../tool/demo_data/src/seeders/diver_seeder.dart';
import '../../../tool/demo_data/src/seeders/gear_cylinder_seeder.dart';
import '../../../tool/demo_data/src/seeders/gear_seeder.dart';
import '../../../tool/demo_data/src/seeders/places_seeder.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../../tool/demo_data/src/seeders/training_seeder.dart';
import '../../../tool/demo_data/src/seeders/trip_seeder.dart';
import 'seed_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoSeedContext ctx;

  setUpAll(() async {
    ctx = await seedContext();
    for (final s in [
      DiverSeeder(),
      PlacesSeeder(),
      TrainingSeeder(),
      GearSeeder(),
      GearCylinderSeeder(),
      TripSeeder(),
      DiveSeeder(),
      TrainingLinksSeeder(),
    ]) {
      await s.seed(ctx);
    }
  });

  tearDownAll(tearDownTestDatabase);

  test('each dive is stored at its planned wall-clock time', () async {
    // The app keeps dive times as wall-clock time in UTC (what the dive
    // computer showed), whatever zone the logbook was built in.
    for (final d in ctx.plan.dives.take(30)) {
      final row = await ctx.db
          .customSelect(
            'SELECT dive_date_time AS t FROM dives WHERE id = ?',
            variables: [Variable.withString(ctx.diveId(d.number))],
          )
          .getSingle();
      final stored = DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('t'),
        isUtc: true,
      );
      expect(
        (stored.year, stored.month, stored.day, stored.hour, stored.minute),
        (
          d.start.year,
          d.start.month,
          d.start.day,
          d.start.hour,
          d.start.minute,
        ),
        reason: 'dive ${d.number}',
      );
    }
  });

  test('every planned dive is written with a profile and a tank', () async {
    expect(await countRows(ctx, 'dives'), ctx.plan.dives.length);
    final missing = await ctx.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM dives d WHERE NOT EXISTS '
          '(SELECT 1 FROM dive_profile_series p WHERE p.dive_id = d.id) '
          'OR NOT EXISTS (SELECT 1 FROM dive_tanks t WHERE t.dive_id = d.id)',
        )
        .getSingle();
    expect(missing.read<int>('n'), 0);
    final noPressure = await ctx.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM dives d WHERE NOT EXISTS '
          '(SELECT 1 FROM tank_pressure_series p WHERE p.dive_id = d.id)',
        )
        .getSingle();
    expect(noPressure.read<int>('n'), 0);
  });

  test('every dive has a bottom time, as an import would derive', () async {
    final missing = await ctx.db
        .customSelect(
          'SELECT COUNT(*) AS n FROM dives WHERE bottom_time IS NULL',
        )
        .getSingle();
    expect(missing.read<int>('n'), 0);
  });

  test('CCR dives are in rebreather mode', () async {
    final ccr = await ctx.db
        .customSelect("SELECT COUNT(*) AS n FROM dives WHERE dive_mode = 'ccr'")
        .getSingle();
    expect(
      ccr.read<int>('n'),
      ctx.plan.dives.where((d) => d.diveMode == 'ccr').length,
    );
  });

  test('every dive child table is filled', () async {
    for (final t in [
      'dive_buddies',
      'dive_buddy_roles',
      'sightings',
      'dive_profile_events',
      'gas_switches',
      'dive_data_sources',
      'tide_records',
      'dive_tags',
      'dive_dive_types',
      'dive_courses',
      'dive_diver_roles',
      'dive_custom_fields',
      'dive_equipment',
      'dive_weights',
      'course_requirement_dives',
    ]) {
      expect(await countRows(ctx, t), greaterThan(0), reason: t);
    }
  });
}
