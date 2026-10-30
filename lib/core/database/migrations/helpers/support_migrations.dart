part of '../app_database_migrations.dart';

/// Schema probes shared by every other migration file.
extension SupportMigrations on AppDatabase {
  /// Idempotent, and tolerates another isolate adding the column between
  /// the read and the add.
  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String ddl,
  ) async {
    final present = await tableColumnNames(this, table);
    if (present.isEmpty) return; // partial fixture database: table absent
    if (present.contains(column)) return;
    await addColumnIfStillMissing(this, table, column, ddl);
  }

  /// True when [table] exists in this database right now.
  Future<bool> _tableExists(String table) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(table)],
    ).get();
    return rows.isNotEmpty;
  }

  /// The `user_version` this database carries on disk right now.
  Future<int> _storedSchemaVersion() async {
    final row = await customSelect('PRAGMA user_version').getSingle();
    return (row.data.values.first as int?) ?? 0;
  }

  /// True when [table] has a column named [column] right now. Self-guards
  /// when the table is absent (minimal migration-test fixtures), mirroring
  /// [_tableExists].
  Future<bool> _columnExists(String table, String column) async =>
      (await tableColumnNames(this, table)).contains(column);

  /// Idempotent and a no-op when the table or column is absent, so it is
  /// safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _dropColumnIfExists(String table, String column) =>
      _dropColumnsIfExist(table, [column]);

  /// [_dropColumnIfExists] for several columns of one table, reading the
  /// table's columns once.
  Future<void> _dropColumnsIfExist(String table, List<String> columns) async {
    final present = await tableColumnNames(this, table);
    for (final column in columns.where(present.contains)) {
      await dropColumnIfStillPresent(this, table, column);
    }
  }

  /// A stable id for a backfilled section row, derived from its parent and
  /// title rather than randomly generated (issue #3360), so a rerun after
  /// an interrupted migration -- or an independent run on another device --
  /// converges on the same row instead of creating a duplicate. Same
  /// SHA-1-digest convention as [conditionInputFingerprint]'s `_digest`:
  /// a stable identity, not a cryptographic guarantee.
  String _deterministicSectionId(String parentId, String title) {
    final digest = sha1
        .convert(utf8.encode('$parentId|${title.toLowerCase()}'))
        .toString()
        .substring(0, 12);
    return 'section-$digest';
  }

  /// Backfills a free-text grouping column into a referenced section row,
  /// one section per distinct value (case-folded, first-seen casing kept),
  /// scoped per parent so two trips/templates/sessions never merge into the
  /// same section. Shared by every table group of issue #3360's checklist
  /// sections. Idempotent: already-pointed items are left alone (the
  /// `section_id IS NULL` guard), and re-inserting a section the digest
  /// already produced is a no-op (`ON CONFLICT DO NOTHING`).
  ///
  /// Items are read ordered by [sortColumn] so "first-seen casing" matches
  /// what the runtime grouping the UI replaces showed divers before this
  /// migration (the same display order the item list already uses).
  ///
  /// [extraCondition], when given, is ANDed onto the read's WHERE clause --
  /// used by pre-dive templates to exclude built-in rows, which get their
  /// section_id assigned separately with stable, human-readable ids
  /// (kAssignBuiltInPreDiveSectionIdsSql) rather than this helper's
  /// content-hash ids, so re-seeding never produces a second, orphaned
  /// section row alongside the one items actually point at.
  Future<void> _backfillTextGroupedSections({
    required String itemsTable,
    required String sectionsTable,
    required String parentColumn,
    required String textColumn,
    required String sortColumn,
    String? extraCondition,
  }) async {
    // A freshly created database (_onCreate) builds the current schema
    // directly, with section_id and no category/section column at all --
    // this function still runs from the beforeOpen backstop on every open,
    // so it must recognize "already migrated, nothing to backfill" rather
    // than querying a column that was never there.
    if (!await _columnExists(itemsTable, textColumn)) return;
    final rows = await customSelect(
      'SELECT id, $parentColumn AS parent_id, $textColumn AS text_value '
      'FROM $itemsTable '
      "WHERE $textColumn IS NOT NULL AND $textColumn != '' "
      '${extraCondition == null ? '' : 'AND $extraCondition '}'
      'ORDER BY $parentColumn, $sortColumn',
    ).get();
    if (rows.isEmpty) return;

    // parentId -> lowercased title -> first-seen original casing, in
    // first-seen order (a LinkedHashMap via Dart's default Map, matching
    // _buildGroupedItems' own insertion-order grouping).
    final sectionsByParent = <String, Map<String, String>>{};
    for (final r in rows) {
      final parentId = r.read<String>('parent_id');
      final text = r.read<String>('text_value');
      final bucket = sectionsByParent.putIfAbsent(parentId, () => {});
      bucket.putIfAbsent(text.toLowerCase(), () => text);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in sectionsByParent.entries) {
      final parentId = entry.key;
      var sortOrder = 0;
      for (final title in entry.value.values) {
        final id = _deterministicSectionId(parentId, title);
        await customStatement(
          'INSERT INTO $sectionsTable '
          '(id, $parentColumn, title, sort_order, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(id) DO NOTHING',
          [id, parentId, title, sortOrder, now, now],
        );
        sortOrder++;
      }
    }

    for (final r in rows) {
      final parentId = r.read<String>('parent_id');
      final text = r.read<String>('text_value');
      final id = r.read<String>('id');
      final sectionId = _deterministicSectionId(parentId, text);
      // Clearing hlc (rather than leaving an already-synced item's old
      // value untouched) marks the row unstamped, the same state the new
      // section rows above are already in. SyncRepository.backfillMissingHlc
      // -- run at the start of every sync -- scans for exactly this
      // (hlc IS NULL) and re-stamps it, so the section link this migration
      // just gave the item does not stay invisible forever to a peer that
      // already passed its old hlc in an earlier sync (same mechanism
      // issue #1144's late hlcTargets registrations and the v182/v208
      // backfill entries rely on; see sync_repository.dart's
      // _hlcBackfillTargets, which this feature's tables must be added to).
      await customStatement(
        'UPDATE $itemsTable SET section_id = ?, hlc = NULL '
        'WHERE id = ? AND section_id IS NULL',
        [sectionId, id],
      );
    }
  }
}
