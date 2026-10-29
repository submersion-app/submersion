import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
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

  Future<List<({String location, String kind, int at})>> moves(
    String key,
  ) async => [
    for (final r
        in await ctx.db
            .customSelect(
              'SELECT l.name AS name, l.kind AS kind, m.moved_at AS at '
              'FROM equipment_location_moves m '
              'JOIN equipment_locations l ON l.id = m.location_id '
              "WHERE m.equipment_id = '${ctx.equipment[key]}' "
              'ORDER BY m.moved_at, m.created_at',
            )
            .get())
      (
        location: r.read<String>('name'),
        kind: r.read<String>('kind'),
        at: r.read<int>('at'),
      ),
  ];

  test('the loaned regulator is at a person location', () async {
    final m = await moves('reg-warm');
    expect(m, isNotEmpty);
    expect(m.last.kind, 'person');
    final loanedOn = ctx.timeline.leftOn('reg-warm')!;
    expect(m.last.at, greaterThanOrEqualTo(loanedOn.millisecondsSinceEpoch));
  });

  test(
    "every item's moves are in date order and end where its status says",
    () async {
      final rows = await ctx.db
          .customSelect(
            'SELECT DISTINCT equipment_id AS e FROM equipment_location_moves',
          )
          .get();
      expect(rows.length, greaterThanOrEqualTo(10));
      final keyOf = {for (final e in ctx.equipment.entries) e.value: e.key};
      for (final r in rows) {
        final key = keyOf[r.read<String>('e')]!;
        final m = await moves(key);
        for (var i = 1; i < m.length; i++) {
          expect(m[i].at, greaterThanOrEqualTo(m[i - 1].at), reason: key);
        }
        final expected = switch (key) {
          'reg-cold' => 'serviceShop',
          'reg-warm' => 'person',
          _ => 'storage',
        };
        expect(m.last.kind, expected, reason: key);
      }
    },
  );

  test(
    'the lost mask was last on a trip dive and its replacement bought after',
    () async {
      final last = await ctx.db
          .customSelect(
            'SELECT d.trip_id AS trip, d.dive_date_time AS at FROM dive_equipment de '
            'JOIN dives d ON d.id = de.dive_id '
            "WHERE de.equipment_id = '${ctx.equipment['mask']}' "
            'ORDER BY d.dive_date_time DESC LIMIT 1',
          )
          .getSingle();
      expect(last.read<String?>('trip'), isNotNull);
      final replacement = await ctx.db
          .customSelect(
            "SELECT purchase_date AS p FROM equipment WHERE id = '${ctx.equipment['mask-2']}'",
          )
          .getSingle();
      expect(replacement.read<int>('p'), greaterThan(last.read<int>('at')));
    },
  );

  test('routine checks note the regulator as fine', () async {
    final ok = await ctx.db
        .customSelect(
          "SELECT COUNT(*) AS n FROM equipment_observations WHERE status = 'ok'",
        )
        .getSingle();
    expect(ok.read<int>('n'), greaterThanOrEqualTo(20));
  });
}
