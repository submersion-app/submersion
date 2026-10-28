import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  Future<int> count(String sql) async =>
      (await ctx.db
              .customSelect('SELECT COUNT(*) AS n FROM ($sql)')
              .getSingle())
          .read<int>('n');

  String id(String key) => ctx.equipment[key]!;

  test('assembly parts ride on dives under their assembly', () async {
    final hoses = await count(
      "SELECT 1 FROM dive_equipment de JOIN equipment e ON e.id = de.equipment_id "
      "WHERE e.type = 'hose'",
    );
    final underRegulator = await count(
      "SELECT 1 FROM dive_equipment de JOIN equipment e ON e.id = de.equipment_id "
      "JOIN equipment p ON p.id = de.via_equipment_id "
      "WHERE e.type = 'hose' AND p.type = 'regulator'",
    );
    expect(hoses, greaterThan(100));
    expect(underRegulator, hoses);
  });

  test(
    'cells are installed children with slot and date, never components',
    () async {
      for (final cell in [
        'o2-cell-1',
        'o2-cell-2',
        'o2-cell-3',
        'o2-cell-2b',
      ]) {
        final row = await ctx.db
            .customSelect(
              'SELECT parent_equipment_id AS p FROM equipment WHERE id = ?',
              variables: [Variable.withString(id(cell))],
            )
            .getSingle();
        expect(row.read<String?>('p'), id('rebreather'), reason: cell);
        expect(
          await count(
            "SELECT 1 FROM equipment_attributes WHERE equipment_id = '${id(cell)}' "
            "AND attr_key = 'cell_slot' AND value_num IS NOT NULL",
          ),
          1,
          reason: cell,
        );
        // The install date is the item's own created date, which the demo
        // date shift moves with the dives; an installed_date attribute would
        // not move, and the condition program would read the wrong dives.
        expect(
          await count(
            "SELECT 1 FROM equipment_attributes WHERE equipment_id = '${id(cell)}' "
            "AND attr_key = 'installed_date'",
          ),
          0,
          reason: cell,
        );
        final created = await ctx.db
            .customSelect(
              'SELECT created_at AS c FROM equipment WHERE id = ?',
              variables: [Variable.withString(id(cell))],
            )
            .getSingle();
        expect(
          created.read<int>('c'),
          ctx.timeline.boughtOn(cell)!.millisecondsSinceEpoch,
          reason: cell,
        );
      }
      expect(
        await count(
          "SELECT 1 FROM equipment_components WHERE component_equipment_id IN "
          "(SELECT id FROM equipment WHERE type IN ('o2Cell', 'battery'))",
        ),
        0,
      );
    },
  );

  test('every usage path counts somewhere', () async {
    expect(await count('SELECT 1 FROM dive_equipment'), greaterThan(1000));
    expect(
      await count('SELECT 1 FROM dive_tanks WHERE equipment_id IS NOT NULL'),
      greaterThan(50),
    );
    expect(
      await count(
        'SELECT 1 FROM dive_tanks WHERE regulator_equipment_id IS NOT NULL',
      ),
      greaterThan(100),
    );
    expect(
      await count(
        'SELECT 1 FROM dive_tanks dt JOIN transmitters t '
        'ON t.transmitter_serial = dt.transmitter_serial',
      ),
      greaterThan(20),
    );
    expect(
      await count(
        "SELECT 1 FROM dive_equipment WHERE equipment_id = '${id('rebreather')}'",
      ),
      greaterThan(10),
    );
  });

  test('every transmitter item is configured and linked', () async {
    for (final key in ['transmitter-cold', 'transmitter-right']) {
      expect(
        await count(
          "SELECT 1 FROM transmitters WHERE transmitter_equipment_id = '${id(key)}' "
          "AND transmitter_serial IS NOT NULL AND transmitter_serial != ''",
        ),
        1,
        reason: key,
      );
    }
  });

  test('trip dives name their dive centre', () async {
    expect(
      await count(
        'SELECT DISTINCT dive_center_id FROM dives WHERE trip_id IS NOT NULL '
        'AND dive_center_id IS NOT NULL',
      ),
      greaterThanOrEqualTo(30),
    );
    expect(
      await count(
        'SELECT 1 FROM dives WHERE dive_center_id IS NOT NULL AND '
        'dive_center_id NOT IN (SELECT id FROM dive_centers)',
      ),
      0,
    );
  });

  test('no item rides on a dive from before it was bought', () async {
    expect(
      await count(
        'SELECT 1 FROM dive_equipment de JOIN equipment e ON e.id = de.equipment_id '
        'JOIN dives d ON d.id = de.dive_id '
        'WHERE e.purchase_date IS NOT NULL AND d.dive_date_time < e.purchase_date',
      ),
      0,
    );
  });

  test(
    'the sets have a default, an auto-applied one and one shown as a figure',
    () async {
      expect(
        await count('SELECT 1 FROM equipment_sets'),
        greaterThanOrEqualTo(6),
      );
      expect(
        await count('SELECT 1 FROM equipment_sets WHERE is_default = 1'),
        1,
      );
      expect(
        await count(
          'SELECT 1 FROM equipment_sets WHERE auto_apply_on_computer_import = 1',
        ),
        greaterThanOrEqualTo(1),
      );
      expect(
        await count('SELECT 1 FROM equipment_sets WHERE show_figure = 1'),
        greaterThanOrEqualTo(1),
      );
    },
  );
}
