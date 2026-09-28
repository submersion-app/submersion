part of '../app_database_migrations.dart';

/// Service records, kinds and schedules.
extension ServiceMigrations on AppDatabase {
  /// v202: the exposure_intervals map on both service ledger tables. Split
  /// out because the v122 seed (which runs in older rungs' blocks and in
  /// the backstop) names the column and must be able to assert it first.
  Future<void> _assertExposureIntervalColumns() async {
    await _addColumnIfMissing(
      'service_kinds',
      'exposure_intervals',
      "TEXT NOT NULL DEFAULT '{}'",
    );
    await _addColumnIfMissing(
      'service_schedules',
      'exposure_intervals',
      "TEXT NOT NULL DEFAULT '{}'",
    );
  }

  /// v202 one-time backfill. Keyed on built-in ids and gated on
  /// is_built_in, so a custom kind is never touched. Runs from the v202
  /// onUpgrade block ONLY (fresh installs get the same values from the seed).
  Future<void> _backfillBuiltInExposureDefaults() async {
    final cols = await customSelect("PRAGMA table_info('service_kinds')").get();
    if (cols.isEmpty) return;
    await customStatement(kBackfillBuiltInExposureDefaultsSql);
  }

  /// v239 one-time backfill (issue #2275). Keyed on built-in ids and gated
  /// on is_built_in, so a custom kind is never touched. Runs from the v239
  /// onUpgrade block ONLY, as the v202 backfill does (fresh installs get the
  /// same lists from the seed).
  Future<void> _backfillRegulatorPartServiceKinds() async {
    if (!await _tableExists('service_kinds')) return;
    await customStatement(kBackfillRegulatorPartServiceKindsSql);
  }

  /// v122: service ledger -- service_kinds + service_schedules tables,
  /// service_records.service_kind_id, scheduled_notifications.schedule_id,
  /// diver_settings.trip_service_lead_days, built-in kind seed, and the
  /// legacy single-clock backfill. Idempotent; called from onUpgrade AND
  /// the beforeOpen backstop (parallel-branch collision self-heal).
  Future<void> _assertServiceLedgerSchema() async {
    await Migrator(this).createTable(serviceKinds);
    await Migrator(this).createTable(serviceSchedules);

    final srCols = await customSelect(
      "PRAGMA table_info('service_records')",
    ).get();
    if (srCols.isNotEmpty &&
        !srCols.any((c) => c.read<String>('name') == 'service_kind_id')) {
      await customStatement(
        'ALTER TABLE service_records ADD COLUMN service_kind_id TEXT',
      );
    }

    final snCols = await customSelect(
      "PRAGMA table_info('scheduled_notifications')",
    ).get();
    if (snCols.isNotEmpty &&
        !snCols.any((c) => c.read<String>('name') == 'schedule_id')) {
      await customStatement(
        'ALTER TABLE scheduled_notifications ADD COLUMN schedule_id TEXT',
      );
    }

    final dsCols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (dsCols.isNotEmpty &&
        !dsCols.any(
          (c) => c.read<String>('name') == 'trip_service_lead_days',
        )) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN trip_service_lead_days '
        'INTEGER NOT NULL DEFAULT 14',
      );
    }

    // Indexes: onCreate's createAll() never builds raw-SQL indexes, so they
    // must be asserted here to exist on fresh installs too. The
    // service_records index is guarded on the table existing so this helper
    // stays self-guarding for partial fixture databases (old-migration
    // tests) where service_records is absent.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_service_schedules_equipment '
      'ON service_schedules(equipment_id)',
    );
    if (srCols.isNotEmpty) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_service_records_kind '
        'ON service_records(equipment_id, service_kind_id)',
      );
    }

    // v202: the seed names exposure_intervals, so the column must exist
    // before it runs, including on the v122 rung of an old database.
    await _assertExposureIntervalColumns();

    // Seed built-ins only when the divers FK parent exists (self-guard for
    // partial fixture databases; real databases always have divers).
    final diversTable = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='divers'",
    ).get();
    if (diversTable.isNotEmpty) {
      await customStatement(kSeedBuiltInServiceKindsSql);
    }
  }

  /// v122 one-time data copy: items with a legacy single-clock interval get
  /// one "General service" schedule. Invoked from the v122 onUpgrade block
  /// only, NEVER the beforeOpen backstop -- re-running on every open would
  /// resurrect a schedule the user deleted (mirrors the v109 buddy-cert
  /// rule). The deterministic id ('legacy-svc-' || equipment id) plus
  /// INSERT OR IGNORE makes independent per-device migrations converge to
  /// one row under sync instead of duplicating.
  Future<void> _backfillLegacyServiceSchedules() async {
    // Self-guard for partial fixture databases: skip unless the equipment
    // table exists WITH the legacy columns the copy reads.
    final eqCols = await customSelect("PRAGMA table_info('equipment')").get();
    final names = eqCols.map((c) => c.read<String>('name')).toSet();
    if (!names.containsAll({'service_interval_days', 'last_service_date'})) {
      return;
    }
    await customStatement('''
      INSERT OR IGNORE INTO service_schedules
        (id, equipment_id, service_kind_id, interval_days, anchor_date,
         enabled, created_at, updated_at)
      SELECT 'legacy-svc-' || e.id, e.id, 'general-service',
             e.service_interval_days, e.last_service_date, 1,
             n.now_ms, n.now_ms
      FROM equipment e
      CROSS JOIN (
        SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms
      ) n
      WHERE e.service_interval_days IS NOT NULL
    ''');
  }

  /// v131 one-time reconciliation: items whose legacy interval was set via the
  /// edit form AFTER the v122 backfill ran have an interval column but no
  /// clock. Create the same deterministic `legacy-svc-<id>` "General service"
  /// clock for them so removing the legacy edit field does not drop their due
  /// signal. Guarded by the deletion log so a clock the user deleted is never
  /// resurrected. onUpgrade only, never beforeOpen (re-running would resurrect
  /// a user-deleted clock; mirrors [_backfillLegacyServiceSchedules]).
  Future<void> _reconcileLegacyServiceSchedules() async {
    // Self-guard for partial fixture databases (old-migration tests): skip
    // unless every table the copy reads exists. Real databases always have
    // deletion_log; a minimal fixture that omits it must not crash the copy.
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ).get();
    final tableNames = tables.map((t) => t.read<String>('name')).toSet();
    if (!tableNames.containsAll({
      'equipment',
      'service_schedules',
      'deletion_log',
    })) {
      return;
    }
    final eqCols = await customSelect("PRAGMA table_info('equipment')").get();
    final names = eqCols.map((c) => c.read<String>('name')).toSet();
    if (!names.containsAll({'service_interval_days', 'last_service_date'})) {
      return;
    }
    await customStatement('''
      INSERT OR IGNORE INTO service_schedules
        (id, equipment_id, service_kind_id, interval_days, anchor_date,
         enabled, created_at, updated_at)
      SELECT 'legacy-svc-' || e.id, e.id, 'general-service',
             e.service_interval_days, e.last_service_date, 1,
             n.now_ms, n.now_ms
      FROM equipment e
      CROSS JOIN (
        SELECT CAST(strftime('%s','now') AS INTEGER) * 1000 AS now_ms
      ) n
      WHERE e.service_interval_days IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM service_schedules s WHERE s.id = 'legacy-svc-' || e.id
        )
        AND NOT EXISTS (
          SELECT 1 FROM deletion_log d
          WHERE d.entity_type = 'serviceSchedules'
            AND d.record_id = 'legacy-svc-' || e.id
        )
    ''');
  }

  /// Test-only hook exercising the v131 reconciliation directly.
  Future<void> reconcileLegacyServiceSchedulesForTest() =>
      _reconcileLegacyServiceSchedules();

  /// Idempotent DDL for v213's `service_schedules.anchor_set_at`: when the
  /// diver set the clock's baseline date. Null (every existing row) keeps
  /// the pre-v213 rule, under which any record of the kind outranks the
  /// baseline; see `clockAnchorFromServices`. Called from the v213
  /// onUpgrade block and the beforeOpen backstop. Self-guarding for partial
  /// fixture databases.
  Future<void> _assertServiceScheduleAnchorSetAtColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('service_schedules')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('anchor_set_at')) {
      await customStatement(
        'ALTER TABLE service_schedules ADD COLUMN anchor_set_at INTEGER',
      );
    }
  }

  /// Default service price columns on service_kinds and service_schedules
  /// (issue #829). PRAGMA-guarded so a healthy database no-ops. The
  /// cols.isEmpty guard matters: minimal migration fixtures build databases
  /// without these tables and would otherwise crash the whole migration.
  /// v160: service_kinds.default_category, plus the built-in seeding.
  ///
  /// Self-guards on the table existing, because minimal migration fixtures
  /// ride the ladder from versions that predate service_kinds. The seeding is
  /// an UPDATE rather than an upsert so it cannot resurrect a built-in the
  /// diver deleted (the v109 rule), and it only fills a NULL so it never
  /// overwrites a category the diver chose.
  Future<void> _assertServiceCategoryColumn() async {
    final cols = await customSelect("PRAGMA table_info('service_kinds')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('default_category')) {
      await customStatement(
        'ALTER TABLE service_kinds ADD COLUMN default_category TEXT',
      );
    }
    for (final entry in kBuiltInServiceKindCategories.entries) {
      await customStatement(
        'UPDATE service_kinds SET default_category = ? '
        'WHERE id = ? AND default_category IS NULL',
        [entry.value, entry.key],
      );
    }
  }

  /// v160: service_records.service_type becomes service_category.
  ///
  /// Separate from [_assertServiceCategoryColumn] so a database missing one
  /// table still gets the other. ALTER TABLE RENAME COLUMN needs SQLite 3.25
  /// (2018), which every supported platform ships.
  Future<void> _assertServiceCategoryRename() async {
    final cols = await customSelect(
      "PRAGMA table_info('service_records')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('service_type') && !names.contains('service_category')) {
      await customStatement(
        'ALTER TABLE service_records '
        'RENAME COLUMN service_type TO service_category',
      );
    }
  }

  Future<void> _assertServiceCostColumns() async {
    for (final table in const ['service_kinds', 'service_schedules']) {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('default_cost')) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN default_cost REAL',
        );
      }
      if (!names.contains('default_currency')) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN default_currency TEXT',
        );
      }
    }
  }
}
