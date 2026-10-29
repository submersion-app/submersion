import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
import '../../../tool/demo_data/src/seeders/dive_kit.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../helpers/test_database.dart';
import 'seed_harness.dart';

void main() {
  late DemoSeedContext ctx;

  setUpAll(() async {
    ctx = await seedContext();
    await seedAll(ctx);
  });

  tearDownAll(tearDownTestDatabase);

  Future<Set<String>> column(String sql, String name) async => {
    for (final r in await ctx.db.customSelect(sql).get())
      ?r.read<String?>(name),
  };

  test("every trip's packing list is the kit its dives used", () async {
    for (final t in ctx.plan.trips) {
      final packed = await column(
        "SELECT equipment_id AS e FROM trip_equipment WHERE trip_id = '${t.id}'",
        'e',
      );
      final kit = {
        for (final d in ctx.plan.dives.where((d) => d.tripId == t.id))
          for (final k in kitFor(
            d,
            ctx.timeline,
            photo: isPhotoDive(d, ctx.timeline),
          ).gearKeys)
            ctx.equipment[k]!,
      };
      expect(packed, kit, reason: t.id);
    }
  });

  test('every centre a dive used has a gear note', () async {
    final used = await column(
      'SELECT DISTINCT dive_center_id AS c FROM dives',
      'c',
    );
    final noted = await column(
      'SELECT DISTINCT dive_center_id AS c FROM dive_center_gear_notes',
      'c',
    );
    expect(used, isNotEmpty);
    expect(noted, containsAll(used));
  });

  test('centres where the regulator was rented say so', () async {
    final notes = await column(
      "SELECT dive_center_id AS c FROM dive_center_gear_notes WHERE gear_type = 'regulator'",
      'c',
    );
    expect(notes, isNotEmpty);
  });

  test('liveaboard names vary between trips', () async {
    final names = await column(
      'SELECT DISTINCT liveaboard_name AS n FROM trips',
      'n',
    );
    expect(names.length, greaterThanOrEqualTo(3));
  });

  test('every trip records its cylinders', () async {
    final withCylinders = await column(
      'SELECT DISTINCT trip_id AS t FROM trip_cylinders',
      't',
    );
    expect(
      withCylinders,
      containsAll([
        for (final t in ctx.plan.trips)
          if (!t.destination.nearHome) t.id,
      ]),
    );
  });

  test("checklist gear items are from that dive's kit", () async {
    final rows = await ctx.db
        .customSelect(
          'SELECT i.equipment_id AS e, s.dive_id AS d FROM pre_dive_session_items i '
          'JOIN pre_dive_sessions s ON s.id = i.session_id '
          'WHERE i.equipment_id IS NOT NULL',
        )
        .get();
    expect(rows.length, greaterThanOrEqualTo(2));
    for (final r in rows) {
      final onDive = await column(
        "SELECT equipment_id AS e FROM dive_equipment WHERE dive_id = '${r.read<String>('d')}'",
        'e',
      );
      expect(onDive, contains(r.read<String>('e')));
    }
  });
}
