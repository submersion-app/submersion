import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/seeders/diver_seeder.dart';
import '../../../tool/demo_data/src/seeders/places_seeder.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import 'seed_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoSeedContext ctx;

  setUpAll(() async {
    ctx = await seedContext();
    await DiverSeeder().seed(ctx);
    await PlacesSeeder().seed(ctx);
  });

  tearDownAll(tearDownTestDatabase);

  test('the demo diver is the default and has a settings row', () async {
    final row = await ctx.db
        .customSelect(
          "SELECT is_default FROM divers WHERE id = '${DemoSeedContext.diverId}'",
        )
        .getSingle();
    expect(row.read<bool>('is_default'), isTrue);
    expect(await countRows(ctx, 'diver_settings'), 2);
    expect(await countRows(ctx, 'diver_weight_entries'), 6);
    expect(await countRows(ctx, 'documents'), greaterThanOrEqualTo(2));
  });

  test('every story person is a buddy, and a custom role exists', () async {
    expect(await countRows(ctx, 'buddies'), ctx.plan.people.length);
    final roles = await ctx.db
        .customSelect("SELECT name FROM dive_roles WHERE name = 'Videographer'")
        .get();
    expect(roles, hasLength(1));
  });

  test('every site has coordinates from the catalogue and a type', () async {
    final rows = await ctx.db
        .customSelect('SELECT id, latitude, longitude FROM dive_sites')
        .get();
    expect(rows, hasLength(ctx.plan.sites.length));
    for (final r in rows) {
      expect(r.read<double?>('latitude'), isNotNull);
    }
    expect(
      await countRows(ctx, 'site_site_types'),
      greaterThanOrEqualTo(rows.length),
    );
    for (final t in [
      'site_tags',
      'site_features',
      'site_species',
      'site_shares',
      'site_hides',
      'site_types',
    ]) {
      expect(await countRows(ctx, t), greaterThan(0), reason: t);
    }
  });

  test(
    'centres, gear notes, tags and the species catalogue are there',
    () async {
      expect(await countRows(ctx, 'dive_centers'), ctx.plan.centers.length);
      // Cylinders and lead at every centre, the regulator where it was
      // rented too.
      final notes = await countRows(ctx, 'dive_center_gear_notes');
      expect(notes, greaterThanOrEqualTo(2 * ctx.plan.centers.length));
      expect(notes, lessThanOrEqualTo(3 * ctx.plan.centers.length));
      expect(await countRows(ctx, 'tags'), 7);
      expect(await countRows(ctx, 'species'), greaterThan(600));
    },
  );
}
