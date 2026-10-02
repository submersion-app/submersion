part of '../app_database_migrations.dart';

/// Dive sites, their classification and dive centers.
extension SiteMigrations on AppDatabase {
  /// v218: diver_settings.site_detail_sections and site_detail_layout (issue
  /// #1884). Idempotent, so it is safe to call from both onUpgrade and the
  /// beforeOpen backstop, and a no-op when the table does not exist yet.
  Future<void> _assertSiteDetailColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('site_detail_sections')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN site_detail_sections TEXT',
      );
    }
    if (!names.contains('site_detail_layout')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN site_detail_layout TEXT',
      );
    }
  }

  /// Site-level entry/exit method columns on dive_sites (issue #1104).
  /// PRAGMA-guarded so a healthy database no-ops and a partial schema does
  /// not throw.
  Future<void> _assertSiteEntryExitMethodColumns() async {
    final cols = await customSelect("PRAGMA table_info('dive_sites')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('entry_method')) {
      await customStatement(
        'ALTER TABLE dive_sites ADD COLUMN entry_method TEXT',
      );
    }
    if (!names.contains('exit_method')) {
      await customStatement(
        'ALTER TABLE dive_sites ADD COLUMN exit_method TEXT',
      );
    }
  }

  /// Idempotent creation of the v217 site classification schema: the three
  /// tables, the built-in seed, and the junction unique indexes. Called from
  /// the v217 rung and the beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks the parent
  /// tables: with foreign keys on (as they are in beforeOpen), SQLite refuses
  /// the seed insert into `site_types` when `divers` does not exist, even for
  /// a NULL diver id.
  Future<void> _assertSiteClassificationSchema() async {
    for (final parent in const ['divers', 'dive_sites', 'tags']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await Migrator(this).createTable(siteTypes);
    await Migrator(this).createTable(siteSiteTypes);
    await Migrator(this).createTable(siteTags);
    await customStatement(kSeedBuiltInSiteTypesSql);
    await assertSiteClassificationUniqueness(this);
  }

  /// Idempotent creation of the v221 `dive_center_gear_notes` table (issue
  /// #2075). Called from the v221 rung and the beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks either parent
  /// table, so a fixture written for an older rung does not gain a table
  /// whose foreign keys point nowhere.
  Future<void> _assertDiveCenterGearNotesSchema() async {
    for (final parent in const ['dive_centers', 'dives']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await Migrator(this).createTable(diveCenterGearNotes);
  }

  /// The site_hides table (v250, issue #2594). Called from the v250 rung
  /// and the beforeOpen backstop. Skipped on a partial migration-test
  /// fixture that lacks a parent table.
  Future<void> _assertSiteHidesSchema() async {
    for (final parent in const ['dive_sites', 'divers']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(siteHides);
  }
}
