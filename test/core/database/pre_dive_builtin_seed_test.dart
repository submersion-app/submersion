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
}
