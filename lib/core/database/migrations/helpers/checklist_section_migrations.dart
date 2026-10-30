part of '../app_database_migrations.dart';

/// Checklist sections (issue #3360): a dedicated section table per
/// checklist/template/session table, replacing the free-text
/// `category`/`section` column items used to carry. Each
/// `_assertAndBackfill...Sections` function is fully idempotent (guarded
/// table/column creation, a `section_id IS NULL` guard on the backfill
/// UPDATE, deterministic section ids so a rerun never duplicates, and a
/// column-exists guard on the final DROP COLUMN), so it is called from both
/// its onUpgrade rung and the beforeOpen backstop.
extension ChecklistSectionMigrations on AppDatabase {
  /// v297: trip_checklist_sections + trip_checklist_items.section_id,
  /// backfilled from category, which is then dropped.
  Future<void> _assertAndBackfillTripChecklistSections() async {
    if (!await _tableExists('trips')) return;
    await Migrator(this).createTable(tripChecklistSections);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_trip_checklist_sections_trip_id '
      'ON trip_checklist_sections(trip_id)',
    );
    if (!await _tableExists('trip_checklist_items')) return;
    await _addColumnIfMissing(
      'trip_checklist_items',
      'section_id',
      'TEXT REFERENCES trip_checklist_sections(id) ON DELETE SET NULL',
    );
    await _backfillTextGroupedSections(
      itemsTable: 'trip_checklist_items',
      sectionsTable: 'trip_checklist_sections',
      parentColumn: 'trip_id',
      textColumn: 'category',
      sortColumn: 'sort_order',
    );
    await _dropColumnIfExists('trip_checklist_items', 'category');
  }

  /// v298: checklist_template_sections + checklist_template_items.section_id,
  /// backfilled from category, which is then dropped.
  Future<void> _assertAndBackfillChecklistTemplateSections() async {
    if (!await _tableExists('checklist_templates')) return;
    await Migrator(this).createTable(checklistTemplateSections);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_checklist_template_sections_template_id '
      'ON checklist_template_sections(template_id)',
    );
    if (!await _tableExists('checklist_template_items')) return;
    await _addColumnIfMissing(
      'checklist_template_items',
      'section_id',
      'TEXT REFERENCES checklist_template_sections(id) ON DELETE SET NULL',
    );
    await _backfillTextGroupedSections(
      itemsTable: 'checklist_template_items',
      sectionsTable: 'checklist_template_sections',
      parentColumn: 'template_id',
      textColumn: 'category',
      sortColumn: 'sort_order',
    );
    await _dropColumnIfExists('checklist_template_items', 'category');
  }

  /// v299: pre_dive_checklist_template_sections +
  /// pre_dive_checklist_template_items.section_id, backfilled from
  /// section, which is then dropped. Built-in templates get stable section
  /// ids via kSeedBuiltInPreDiveTemplateSectionsSql /
  /// kAssignBuiltInPreDiveSectionIdsSql, re-asserted in
  /// _seedBuiltInPreDiveTemplates (called from before_open.dart on every
  /// open; not duplicated here), rather than the generic hash-id backfill
  /// below, which is scoped to exclude built-ins for exactly that reason.
  Future<void> _assertAndBackfillPreDiveTemplateSections() async {
    if (!await _tableExists('pre_dive_checklist_templates')) return;
    await Migrator(this).createTable(preDiveChecklistTemplateSections);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_template_sections_template_id '
      'ON pre_dive_checklist_template_sections(template_id)',
    );
    if (!await _tableExists('pre_dive_checklist_template_items')) return;
    await _addColumnIfMissing(
      'pre_dive_checklist_template_items',
      'section_id',
      'TEXT REFERENCES pre_dive_checklist_template_sections(id) '
          'ON DELETE SET NULL',
    );
    await _backfillTextGroupedSections(
      itemsTable: 'pre_dive_checklist_template_items',
      sectionsTable: 'pre_dive_checklist_template_sections',
      parentColumn: 'template_id',
      textColumn: 'section',
      sortColumn: 'sort_order',
      extraCondition:
          'template_id NOT IN '
          '(SELECT id FROM pre_dive_checklist_templates WHERE is_built_in = 1)',
    );
    await _dropColumnIfExists('pre_dive_checklist_template_items', 'section');
  }

  /// v300: pre_dive_session_sections + pre_dive_session_items.section_id,
  /// backfilled from section, which is then dropped. No built-in exclusion
  /// needed here (unlike v299): sessions are always diver-owned instances,
  /// never re-seeded, regardless of which template they came from.
  Future<void> _assertAndBackfillPreDiveSessionSections() async {
    if (!await _tableExists('pre_dive_sessions')) return;
    await Migrator(this).createTable(preDiveSessionSections);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pre_dive_session_sections_session_id '
      'ON pre_dive_session_sections(session_id)',
    );
    if (!await _tableExists('pre_dive_session_items')) return;
    await _addColumnIfMissing('pre_dive_session_items', 'section_id', 'TEXT');
    await _backfillTextGroupedSections(
      itemsTable: 'pre_dive_session_items',
      sectionsTable: 'pre_dive_session_sections',
      parentColumn: 'session_id',
      textColumn: 'section',
      sortColumn: 'sort_order',
    );
    await _dropColumnIfExists('pre_dive_session_items', 'section');
  }
}
