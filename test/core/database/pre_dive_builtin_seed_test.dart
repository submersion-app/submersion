import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<Map<String, Object?>>> rows(String sql) async {
    final db = DatabaseService.instance.database;
    final r = await db.customSelect(sql).get();
    return r.map((row) => row.data).toList();
  }

  test('fresh database seeds the four built-in templates with items', () async {
    // Force beforeOpen to run.
    await rows('SELECT 1');
    final templates = await rows(
      'SELECT id, name, strict_order, is_built_in FROM '
      'pre_dive_checklist_templates WHERE is_built_in = 1 ORDER BY id',
    );
    expect(templates.map((t) => t['id']).toList(), [
      'builtin-predive-bwraf',
      'builtin-predive-ccr-build',
      'builtin-predive-gear-packing',
      'builtin-predive-gue-edge',
    ]);
    final ccr = templates.firstWhere(
      (t) => t['id'] == 'builtin-predive-ccr-build',
    );
    expect(ccr['strict_order'], 1);

    final itemCounts = await rows(
      'SELECT template_id, COUNT(*) AS n FROM '
      'pre_dive_checklist_template_items GROUP BY template_id',
    );
    expect(itemCounts, hasLength(4));
    for (final row in itemCounts) {
      expect((row['n'] as int) >= 4, isTrue, reason: '${row['template_id']}');
    }
    // CCR build has value items with thresholds.
    final valueItems = await rows(
      "SELECT id FROM pre_dive_checklist_template_items "
      "WHERE template_id = 'builtin-predive-ccr-build' "
      "AND item_type = 'value' AND value_min IS NOT NULL",
    );
    expect(valueItems, isNotEmpty);
    // Gear packing has the equipmentSet placeholder.
    final placeholder = await rows(
      "SELECT id FROM pre_dive_checklist_template_items "
      "WHERE template_id = 'builtin-predive-gear-packing' "
      "AND item_type = 'equipmentSet'",
    );
    expect(placeholder, hasLength(1));
  });

  test(
    're-seed restores a deleted built-in (INSERT OR IGNORE idempotence)',
    () async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "DELETE FROM pre_dive_checklist_template_items "
        "WHERE template_id = 'builtin-predive-bwraf'",
      );
      await db.customStatement(
        "DELETE FROM pre_dive_checklist_templates "
        "WHERE id = 'builtin-predive-bwraf'",
      );
      // Simulate next open's beforeOpen re-seed.
      await db.customStatement(kSeedBuiltInPreDiveTemplatesSql);
      await db.customStatement(kSeedBuiltInPreDiveTemplateItemsSql);
      final restored = await rows(
        "SELECT id FROM pre_dive_checklist_templates "
        "WHERE id = 'builtin-predive-bwraf'",
      );
      expect(restored, hasLength(1));
      // Running twice must not duplicate.
      await db.customStatement(kSeedBuiltInPreDiveTemplatesSql);
      final all = await rows(
        'SELECT COUNT(*) AS n FROM pre_dive_checklist_templates '
        'WHERE is_built_in = 1',
      );
      expect(all.first['n'], 4);
    },
  );

  test('GUE EDGE seeds the canonical seven-point sequence in order', () async {
    await rows('SELECT 1');
    final items = await rows(
      'SELECT id, title, sort_order FROM pre_dive_checklist_template_items '
      "WHERE template_id = 'builtin-predive-gue-edge' ORDER BY sort_order",
    );
    expect(items.map((i) => i['id']).toList(), [
      for (var i = 0; i < 7; i++) 'builtin-predive-gue-edge-$i',
    ]);
    // G-U-E E-D-G-E: the mnemonic is the sequence, so the first word of each
    // title is the assertion.
    expect(
      items
          .map((i) => (i['title']! as String).split(':').first.toLowerCase())
          .toList(),
      [
        'goal',
        'unified team',
        'equipment',
        'exposure',
        'decompression',
        'gas',
        'environment',
      ],
    );
    expect(items.map((i) => i['sort_order']).toList(), [0, 1, 2, 3, 4, 5, 6]);
  });

  test('re-seed retires the legacy four-item GUE EDGE list', () async {
    final db = DatabaseService.instance.database;
    // Recreate a pre-repair database: the canonical rows gone, the legacy
    // ids present.
    await db.customStatement(
      "DELETE FROM pre_dive_checklist_template_items "
      "WHERE template_id = 'builtin-predive-gue-edge'",
    );
    for (var i = 0; i < 4; i++) {
      await db.customStatement(
        'INSERT INTO pre_dive_checklist_template_items '
        '(id, template_id, title, sort_order, item_type, is_required, '
        'created_at, updated_at) VALUES '
        "('builtin-predive-gue-$i', 'builtin-predive-gue-edge', "
        "'Legacy $i', $i, 'check', 1, 0, 0)",
      );
    }
    // Simulate the next open's beforeOpen re-seed.
    await db.customStatement(kRetireLegacyGueEdgeItemsSql);
    await db.customStatement(kSeedBuiltInPreDiveTemplateItemsSql);

    final items = await rows(
      'SELECT id FROM pre_dive_checklist_template_items '
      "WHERE template_id = 'builtin-predive-gue-edge' ORDER BY sort_order",
    );
    expect(items, hasLength(7));
    expect(
      items.map((i) => i['id']).where((id) => id == 'builtin-predive-gue-0'),
      isEmpty,
    );

    // Running the pair again is a no-op, not a duplication.
    await db.customStatement(kRetireLegacyGueEdgeItemsSql);
    await db.customStatement(kSeedBuiltInPreDiveTemplateItemsSql);
    final again = await rows(
      'SELECT COUNT(*) AS n FROM pre_dive_checklist_template_items '
      "WHERE template_id = 'builtin-predive-gue-edge'",
    );
    expect(again.first['n'], 7);
  });

  test('the CCR template seeds three linked cell linearity rows', () async {
    await rows('SELECT 1');
    final linearity = await rows(
      'SELECT id, section, sort_order, source_item_id, value_min, '
      'value_unit, value_label, is_required FROM '
      'pre_dive_checklist_template_items '
      "WHERE template_id = 'builtin-predive-ccr-build' "
      "AND item_type = 'cellLinearity' ORDER BY sort_order",
    );

    expect(linearity, hasLength(3));
    expect(linearity.map((r) => r['id']).toList(), [
      'builtin-predive-ccr-cell1-linearity',
      'builtin-predive-ccr-cell2-linearity',
      'builtin-predive-ccr-cell3-linearity',
    ]);
    expect(linearity.map((r) => r['source_item_id']).toList(), [
      'builtin-predive-ccr-4',
      'builtin-predive-ccr-5',
      'builtin-predive-ccr-6',
    ]);
    expect(linearity.map((r) => r['sort_order']).toList(), [7, 8, 9]);
    expect(linearity.map((r) => r['value_label']).toList(), [
      'Cell 1',
      'Cell 2',
      'Cell 3',
    ]);
    for (final row in linearity) {
      expect(row['section'], 'Cells');
      expect(row['value_min'], 95);
      expect(row['value_unit'], 'mV');
      expect(row['is_required'], 1);
    }
  });

  test('every linearity row sources an air row that sorts before it', () async {
    await rows('SELECT 1');
    // The CCR template is strict-order, so a linearity row that sorted above
    // its air row would be unreachable until the diver answered an item that
    // comes after it.
    final orphans = await rows(
      'SELECT l.id FROM pre_dive_checklist_template_items l '
      'LEFT JOIN pre_dive_checklist_template_items src '
      'ON src.id = l.source_item_id '
      "WHERE l.item_type = 'cellLinearity' "
      'AND (src.id IS NULL OR src.sort_order >= l.sort_order)',
    );
    expect(orphans, isEmpty);
  });

  test('the CCR tail items are renumbered below the new rows', () async {
    await rows('SELECT 1');
    final tail = await rows(
      'SELECT id, sort_order FROM pre_dive_checklist_template_items '
      "WHERE id IN ('builtin-predive-ccr-7', 'builtin-predive-ccr-8', "
      "'builtin-predive-ccr-9') ORDER BY sort_order",
    );
    expect(tail.map((r) => r['sort_order']).toList(), [10, 11, 12]);
  });

  test('the renumbering repairs a database seeded before the fix', () async {
    // INSERT OR IGNORE can add the new rows but can never renumber ones an
    // already-seeded database holds, so the companion UPDATE is what moves
    // the pre-existing tail out of their way.
    final db = DatabaseService.instance.database;
    await rows('SELECT 1');
    await db.customStatement(
      'UPDATE pre_dive_checklist_template_items SET sort_order = 7 '
      "WHERE id = 'builtin-predive-ccr-7'",
    );
    await db.customStatement(kRenumberCcrTailItemsSql);

    final tail = await rows(
      'SELECT sort_order FROM pre_dive_checklist_template_items '
      "WHERE id = 'builtin-predive-ccr-7'",
    );
    expect(tail.single['sort_order'], 10);
  });

  test('re-running the renumbering is a no-op', () async {
    final db = DatabaseService.instance.database;
    await rows('SELECT 1');
    await db.customStatement(kRenumberCcrTailItemsSql);
    await db.customStatement(kRenumberCcrTailItemsSql);
    final tail = await rows(
      'SELECT id, sort_order FROM pre_dive_checklist_template_items '
      "WHERE id IN ('builtin-predive-ccr-7', 'builtin-predive-ccr-8', "
      "'builtin-predive-ccr-9') ORDER BY sort_order",
    );
    expect(tail.map((r) => r['sort_order']).toList(), [10, 11, 12]);
  });

  test('the air rows keep the ids the linearity rows point at', () async {
    await rows('SELECT 1');
    // Hard constraint: renumbering or retiring these ids would silently
    // unlink every pair in a database that has already seeded them.
    final air = await rows(
      'SELECT id, sort_order FROM pre_dive_checklist_template_items '
      "WHERE id IN ('builtin-predive-ccr-4', 'builtin-predive-ccr-5', "
      "'builtin-predive-ccr-6') ORDER BY sort_order",
    );
    expect(air.map((r) => r['sort_order']).toList(), [4, 5, 6]);
  });
}
