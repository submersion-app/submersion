part of '../app_database_migrations.dart';

/// Pre-dive checklist templates and sessions.
extension PreDiveMigrations on AppDatabase {
  /// v127: pre-dive checklist tables. Migrator.createTable is IF NOT EXISTS,
  /// so this is safe to call from both onUpgrade and the beforeOpen backstop
  /// (parallel-branch version-collision self-heal).
  Future<void> _assertPreDiveChecklistSchema() async {
    final m = Migrator(this);
    await m.createTable(preDiveChecklistTemplates);
    await m.createTable(preDiveChecklistTemplateItems);
    await m.createTable(preDiveSessions);
    await m.createTable(preDiveSessionItems);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_template_items_template_id '
      'ON pre_dive_checklist_template_items(template_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_sessions_dive_id '
      'ON pre_dive_sessions(dive_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_session_items_session_id '
      'ON pre_dive_session_items(session_id)',
    );
  }

  /// Seeds the built-in pre-dive templates and their items, but only when the
  /// FK parent `divers` table exists. pre_dive_checklist_templates.diver_id
  /// references divers, so with foreign_keys=ON the seed cannot even prepare
  /// when that table is absent. Minimal migration-test fixtures upgrade an old
  /// schema without the full table set and legitimately lack it -- skipping
  /// the seed there is correct (the tables are still created). Real databases
  /// always have divers, so they always seed. Mirrors the guarded dive_types
  /// re-seed in beforeOpen.
  Future<void> _seedBuiltInPreDiveTemplates() async {
    final diversTable = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='divers'",
    ).get();
    if (diversTable.isEmpty) return;
    await customStatement(kSeedBuiltInPreDiveTemplatesSql);
    await customStatement(kRetireLegacyGueEdgeItemsSql);
    await customStatement(kSeedBuiltInPreDiveTemplateItemsSql);
    await customStatement(kRenumberCcrTailItemsSql);
  }

  /// Idempotent DDL for the v181 pre_dive_checklist_template_items
  /// equipment_id column (issue #814): the remembered single-equipment link
  /// for an 'equipment'-typed template item, chosen at session start (not in
  /// the template editor) and persisted so later sessions pre-fill the same
  /// device. Self-guards on the table existing. Same dual-call contract
  /// (onUpgrade + beforeOpen backstop) as the other column-assert helpers.
  ///
  /// No SQL-level REFERENCES clause: template items are (re-)seeded
  /// independently of the equipment table (isolated schema fixtures, builtin
  /// template reseeding on every app start), so referential integrity is
  /// enforced at the application layer instead of via SQLite FK.
  Future<void> _assertTemplateItemEquipmentIdColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('pre_dive_checklist_template_items')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('equipment_id')) return;
    await customStatement(
      'ALTER TABLE pre_dive_checklist_template_items ADD COLUMN equipment_id '
      'TEXT',
    );
  }

  /// Idempotent DDL for the v201 pre_dive_checklist_template_items
  /// .source_item_id column (issue #986): the cell linearity link. Self-
  /// guards on the table existing. Same dual-call contract (onUpgrade plus
  /// beforeOpen backstop) as the other column-assert helpers.
  Future<void> _assertTemplateItemSourceIdColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('pre_dive_checklist_template_items')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('source_item_id')) return;
    await customStatement(
      'ALTER TABLE pre_dive_checklist_template_items ADD COLUMN '
      'source_item_id TEXT',
    );
  }

  /// Idempotent DDL for the v201 pre_dive_session_items linearity columns
  /// (issue #986). Each column is guarded independently, so an upgrade
  /// interrupted between the two still picks the second up on the next open.
  Future<void> _assertSessionItemSourceColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('pre_dive_session_items')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('source_item_id')) {
      await customStatement(
        'ALTER TABLE pre_dive_session_items ADD COLUMN source_item_id TEXT',
      );
    }
    if (!names.contains('source_value_number')) {
      await customStatement(
        'ALTER TABLE pre_dive_session_items ADD COLUMN source_value_number '
        'REAL',
      );
    }
  }

  Future<void> _assertSessionItemOverdueServicesColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('pre_dive_session_items')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('overdue_services')) return;
    await customStatement(
      'ALTER TABLE pre_dive_session_items ADD COLUMN overdue_services TEXT',
    );
  }
}
