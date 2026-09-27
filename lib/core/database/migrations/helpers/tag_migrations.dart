part of '../app_database_migrations.dart';

/// Tags and dive types.
extension TagMigrations on AppDatabase {
  /// Idempotent DDL for the v173 dive_types.short_name column: an optional
  /// abbreviation a diver can set on a custom dive type (built-ins use the
  /// fixed translated abbreviation in builtInDiveTypeShortName instead).
  /// Called from the v173 onUpgrade step and the beforeOpen backstop,
  /// matching the _assertTripReturnFlightColumn pattern so a schema-version
  /// collision cannot strand a database without it. Self-guarding when the
  /// table is absent (minimal migration-test fixtures).
  Future<void> _assertDiveTypeShortNameColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_types')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('short_name')) return;
    await customStatement('ALTER TABLE dive_types ADD COLUMN short_name TEXT');
  }

  /// Idempotent DDL for the tag scope flags: dives and sites (v217, issue
  /// #1765), equipment (v219, issue #1942). Existing tags are dive tags; none
  /// applies to sites or equipment until the diver says so.
  Future<void> _assertTagScopeColumns() async {
    final cols = await customSelect("PRAGMA table_info('tags')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('applies_to_dives')) {
      await customStatement(
        'ALTER TABLE tags ADD COLUMN applies_to_dives '
        'INTEGER NOT NULL DEFAULT 1 CHECK (applies_to_dives IN (0, 1))',
      );
    }
    if (!names.contains('applies_to_sites')) {
      await customStatement(
        'ALTER TABLE tags ADD COLUMN applies_to_sites '
        'INTEGER NOT NULL DEFAULT 0 CHECK (applies_to_sites IN (0, 1))',
      );
    }
    if (!names.contains('applies_to_equipment')) {
      await customStatement(
        'ALTER TABLE tags ADD COLUMN applies_to_equipment '
        'INTEGER NOT NULL DEFAULT 0 CHECK (applies_to_equipment IN (0, 1))',
      );
    }
  }

  /// Idempotent DDL for the v174 dive_types.show_in_detail_header and
  /// dive_types.show_in_list_view columns: per-type toggles for which
  /// badge rows a diver's types appear in (issue #1269 follow-up). Both
  /// default to shown (1) so existing dives keep their current badges.
  /// Called from the v174 onUpgrade step and the beforeOpen backstop,
  /// matching the _assertDiveTypeShortNameColumn pattern so a schema-version
  /// collision cannot strand a database without them. Self-guarding when the
  /// table is absent (minimal migration-test fixtures).
  Future<void> _assertDiveTypeVisibilityColumns() async {
    final cols = await customSelect("PRAGMA table_info('dive_types')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('show_in_detail_header')) {
      await customStatement(
        'ALTER TABLE dive_types ADD COLUMN show_in_detail_header '
        'INTEGER NOT NULL DEFAULT 1 CHECK (show_in_detail_header IN (0, 1))',
      );
    }
    if (!names.contains('show_in_list_view')) {
      await customStatement(
        'ALTER TABLE dive_types ADD COLUMN show_in_list_view '
        'INTEGER NOT NULL DEFAULT 1 CHECK (show_in_list_view IN (0, 1))',
      );
    }
  }
}
