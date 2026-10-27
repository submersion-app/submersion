import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/seeders/diver_seeder.dart';
import '../../../tool/demo_data/src/seeders/gear_catalog.dart';
import '../../../tool/demo_data/src/seeders/gear_seeder.dart';
import '../../../tool/demo_data/src/seeders/places_seeder.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../../tool/demo_data/src/seeders/trip_seeder.dart';
import 'seed_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoSeedContext ctx;

  setUpAll(() async {
    ctx = await seedContext();
    await DiverSeeder().seed(ctx);
    await PlacesSeeder().seed(ctx);
    await GearSeeder().seed(ctx);
    await TripSeeder().seed(ctx);
  });

  tearDownAll(tearDownTestDatabase);

  test('every piece of kit is there, with sets, components and tags', () async {
    expect(await countRows(ctx, 'equipment'), demoGear.length);
    for (final t in [
      'equipment_components',
      'equipment_sets',
      'equipment_set_items',
      'equipment_set_geofences',
      'equipment_tags',
      'equipment_attributes',
    ]) {
      expect(await countRows(ctx, t), greaterThan(0), reason: t);
    }
  });

  test('storage, service, sharing and a transfer are recorded', () async {
    for (final t in [
      'equipment_locations',
      'equipment_location_moves',
      'equipment_observations',
      'equipment_shares',
      'equipment_ownership_events',
      'service_records',
      'service_schedules',
    ]) {
      expect(await countRows(ctx, t), greaterThan(0), reason: t);
    }
  });

  test('computers, transmitters, presets and cylinders are set up', () async {
    expect(await countRows(ctx, 'dive_computers'), 2);
    expect(await countRows(ctx, 'transmitters'), 2);
    for (final t in [
      'dive_computer_connections',
      'tank_presets',
      'weight_presets',
      'weight_preset_entries',
      'cylinder_configs',
      'cylinder_config_items',
      'cylinder_fills',
    ]) {
      expect(await countRows(ctx, t), greaterThan(0), reason: t);
    }
  });

  test(
    'every planned trip plus the upcoming one, with their details',
    () async {
      expect(await countRows(ctx, 'trips'), ctx.plan.trips.length + 1);
      for (final t in [
        'trip_itinerary_days',
        'trip_day_weather',
        'liveaboard_detail_records',
        'trip_cylinders',
        'trip_cylinder_events',
        'trip_equipment',
        'trip_checklist_sections',
        'trip_checklist_items',
        'trip_shares',
        'trip_hides',
      ]) {
        expect(await countRows(ctx, t), greaterThan(0), reason: t);
      }
    },
  );
}
