part of '../app_database_migrations.dart';

/// Saved dive plans.
extension DivePlanMigrations on AppDatabase {
  /// v120: planner Subsurface-parity columns - plan start time, per-segment
  /// setpoint + dive-mode override, and per-tank deco-switch depth. Idempotent
  /// (each ALTER is PRAGMA-guarded) so it is safe from both onUpgrade and the
  /// beforeOpen backstop (shared sandbox DB heals across parallel branches).
  Future<void> _assertPlannerParitySchema() async {
    Future<void> add(String table, String column, String type) async {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) return;
      final has = cols.any((c) => c.read<String>('name') == column);
      if (!has) {
        await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
      }
    }

    await add('dive_plans', 'start_date_time', 'INTEGER');
    await add('dive_plan_segments', 'setpoint_bar', 'REAL');
    await add('dive_plan_segments', 'dive_mode_override', 'TEXT');
    await add('dive_plan_tanks', 'deco_switch_depth', 'REAL');
  }

  /// Idempotent DDL for the v156 dive_plan_tanks travel-gas flag. Same
  /// dual-call contract (onUpgrade + beforeOpen backstop) as the other
  /// column-assert helpers.
  Future<void> _assertTravelGasColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_plan_tanks')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('is_travel_gas')) {
      await customStatement(
        'ALTER TABLE dive_plan_tanks ADD COLUMN is_travel_gas '
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// The v191 dive_plans per-band ascent rate columns: the ascent slows in
  /// stages between intermediate stops, between shallow stops, and over the
  /// final stretch to the surface. PRAGMA-guarded so a healthy database
  /// no-ops and a partial schema does not throw. Called from the v191
  /// onUpgrade step and the beforeOpen backstop, matching the other additive
  /// column helpers.
  Future<void> _assertPlanAscentRateColumns() async {
    final cols = await customSelect("PRAGMA table_info('dive_plans')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    const defaults = {
      'intermediate_ascent_rate': '6.0',
      'shallow_ascent_rate': '3.0',
      'final_ascent_rate': '1.0',
    };
    for (final entry in defaults.entries) {
      if (names.contains(entry.key)) continue;
      await customStatement(
        'ALTER TABLE dive_plans ADD COLUMN ${entry.key} '
        'REAL NOT NULL DEFAULT ${entry.value}',
      );
    }
  }

  /// v305: drops NOT NULL from the dive_plans columns that follow the
  /// diver's Settings when unset (issue #3552), so a plan can store an
  /// explicit "unset" state instead of always carrying a concrete value.
  /// Also covers v308's reserve_pressure/gf_low/gf_high, so an upgrade
  /// across both rungs rebuilds the table once; the v308 helper calls this
  /// again, which then no-ops. Called from the v305 onUpgrade step and the
  /// beforeOpen backstop. Renumbered from 303 as #3482 shipped 302-303
  /// first.
  Future<void> _assertDivePlanSetupFieldsNullable() =>
      _dropNotNullByRebuild('dive_plans', const {
        'descent_rate': 'REAL',
        'ascent_rate': 'REAL',
        'intermediate_ascent_rate': 'REAL',
        'shallow_ascent_rate': 'REAL',
        'final_ascent_rate': 'REAL',
        'last_stop_depth': 'REAL',
        'gas_switch_stop_seconds': 'INTEGER',
        'sac_bottom': 'REAL',
        'sac_factor': 'REAL',
        'problem_solving_minutes': 'INTEGER',
        'best_mix_end_meters': 'REAL',
        'deviation_depth_delta': 'REAL',
        'deviation_time_minutes': 'INTEGER',
        'reserve_pressure': 'REAL',
        'gf_low': 'INTEGER',
        'gf_high': 'INTEGER',
      });

  /// Drops NOT NULL, and the DEFAULT that came with it, from [columns]
  /// (name to declared type) of [table]. SQLite has no `ALTER COLUMN`, so
  /// this rebuilds the table, the same technique as
  /// [DiveMigrations._assertDiveTankEquipmentSetNull]: only the targeted
  /// columns' clauses are rewritten in the table's actual stored SQL, so
  /// every other column - including one this code has never heard of -
  /// survives untouched, and `INSERT INTO ... SELECT *` carries every row's
  /// data across unchanged.
  ///
  /// A column clause matches with its name quoted (Drift's CREATE TABLE and
  /// addColumn) or bare (this ladder's own `ALTER TABLE ... ADD COLUMN
  /// name`, e.g. the v191 ascent rates and v215 gas options), since a
  /// long-upgraded database carries both shapes. The DEFAULT is dropped too
  /// so a migrated table matches a fresh one, where an omitted column is
  /// NULL ("follow Settings") rather than the old hardcoded value.
  ///
  /// Idempotent (a column is skipped once its clause no longer has NOT
  /// NULL) and wrapped in one transaction, so a failure at any step leaves
  /// the original table exactly as it was. Foreign keys are off for the
  /// swap, same reason as the dive_tanks rebuild: child tables reference
  /// this one, and the DROP would otherwise cascade into them.
  Future<void> _dropNotNullByRebuild(
    String table,
    Map<String, String> columns,
  ) async {
    final stored = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(table)],
    ).get();
    if (stored.isEmpty) return; // minimal fixture database: table absent
    final createSql = stored.first.read<String>('sql');

    var rebuiltSql = createSql;
    var changed = false;
    for (final entry in columns.entries) {
      final clause = RegExp(
        '(?:"${entry.key}"|\\b${entry.key}\\b)\\s+${entry.value}'
        '\\s+NOT\\s+NULL'
        "(?:\\s+DEFAULT\\s+(?:\\([^)]*\\)|'[^']*'|[^\\s,)]+))?",
        caseSensitive: false,
      );
      if (!clause.hasMatch(rebuiltSql)) continue; // already nullable
      rebuiltSql = rebuiltSql.replaceFirst(
        clause,
        '"${entry.key}" ${entry.value}',
      );
      changed = true;
    }
    if (!changed) return; // every column already migrated

    final header = RegExp(
      '^CREATE\\s+TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?"?$table"?(?=[\\s(])',
      caseSensitive: false,
    );
    if (!header.hasMatch(rebuiltSql)) {
      developer.log(
        '$table follow-Settings columns: stored definition not in a '
        'recognised shape, nullability left unchanged',
        name: 'AppDatabase',
      );
      return;
    }
    final scratch = '${table}_nullable_rebuild';
    rebuiltSql = rebuiltSql.replaceFirst(header, 'CREATE TABLE $scratch');
    final dependents = await customSelect(
      "SELECT sql FROM sqlite_master WHERE tbl_name = ? "
      "AND type IN ('index', 'trigger') AND sql IS NOT NULL",
      variables: [Variable<String>(table)],
    ).get();

    Future<bool> enforced() async =>
        (await customSelect(
          'PRAGMA foreign_keys',
        ).getSingle()).read<int>('foreign_keys') ==
        1;
    final wasEnforced = await enforced();
    if (wasEnforced) {
      await customStatement('PRAGMA foreign_keys = OFF');
      // A no-op inside a transaction. Refuse rather than cascade.
      if (await enforced()) {
        developer.log(
          '$table follow-Settings columns: foreign keys could not be '
          'switched off, rebuild deferred to a later open',
          name: 'AppDatabase',
        );
        return;
      }
    }
    try {
      await transaction(() async {
        await customStatement('DROP TABLE IF EXISTS $scratch');
        await customStatement(rebuiltSql);
        await customStatement('INSERT INTO $scratch SELECT * FROM $table');
        await customStatement('DROP TABLE $table');
        await customStatement('ALTER TABLE $scratch RENAME TO $table');
        for (final row in dependents) {
          await customStatement(row.read<String>('sql'));
        }
      });
    } finally {
      if (wasEnforced) await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  /// Idempotent DDL for dive_plans.salinity_ppt (v197). Nullable: existing
  /// plans keep EN13319 / water-type density until the diver picks Custom.
  Future<void> _assertPlanSalinityPptColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_plans')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('salinity_ppt')) return;
    await customStatement(
      'ALTER TABLE dive_plans ADD COLUMN salinity_ppt REAL',
    );
  }

  /// v214: dive_plans.stop_minimums_json (replan-this-dive minimum stop
  /// durations). Additive, nullable column, no backfill: an existing plan
  /// reads back with no minimums set, exactly its prior behavior.
  Future<void> _assertPlanStopMinimumsColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_plans')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('stop_minimums_json')) return;
    await customStatement(
      'ALTER TABLE dive_plans ADD COLUMN stop_minimums_json TEXT',
    );
  }

  /// v215: dive_plans gas-options columns (Subsurface parity: SAC factor,
  /// problem solving time, bottom/deco ppO2 overrides, best-mix END, O2
  /// narcotic override). Additive; the two non-nullable columns backfill
  /// existing rows with the same defaults [DivePlan] already assumes when a
  /// column is missing, so a plan's minimum-gas figure and END limit are
  /// unchanged by the migration itself.
  Future<void> _assertPlanGasOptionColumns() async {
    final cols = await customSelect("PRAGMA table_info('dive_plans')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('sac_factor')) {
      await customStatement(
        'ALTER TABLE dive_plans ADD COLUMN sac_factor REAL NOT NULL '
        'DEFAULT 2.0',
      );
    }
    if (!names.contains('problem_solving_minutes')) {
      await customStatement(
        'ALTER TABLE dive_plans ADD COLUMN problem_solving_minutes INTEGER '
        'NOT NULL DEFAULT 2',
      );
    }
    if (!names.contains('pp_o2_bottom')) {
      await customStatement(
        'ALTER TABLE dive_plans ADD COLUMN pp_o2_bottom REAL',
      );
    }
    if (!names.contains('pp_o2_deco')) {
      await customStatement(
        'ALTER TABLE dive_plans ADD COLUMN pp_o2_deco REAL',
      );
    }
    if (!names.contains('best_mix_end_meters')) {
      await customStatement(
        'ALTER TABLE dive_plans ADD COLUMN best_mix_end_meters REAL NOT '
        'NULL DEFAULT 30.0',
      );
    }
    if (!names.contains('o2_narcotic')) {
      await customStatement(
        'ALTER TABLE dive_plans ADD COLUMN o2_narcotic BOOLEAN',
      );
    }
  }

  /// Idempotent DDL for the v290 dive_plan_segments rate-split flag (issue
  /// #3264). Additive, defaulting off: an existing segment keeps reading as
  /// the single linear leg it always has.
  Future<void> _assertSegmentSplitAtRateColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_plan_segments')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('split_at_configured_rate')) {
      await customStatement(
        'ALTER TABLE dive_plan_segments ADD COLUMN '
        'split_at_configured_rate INTEGER NOT NULL DEFAULT 0 '
        'CHECK (split_at_configured_rate IN (0, 1))',
      );
    }
  }

  /// Idempotent creation of the v244 DPV mission tables (issue #2086).
  /// Called from the v244 rung and the beforeOpen backstop.
  ///
  /// Not guarded on dive_plans: SQLite accepts a REFERENCES clause to a
  /// table that does not exist yet, so the create does not depend on where
  /// it runs relative to the v100 backstop that re-creates dive_plans.
  Future<void> _assertDivePlanMissionSchema() async {
    final migrator = Migrator(this);
    await migrator.createTable(divePlanMissions);
    await migrator.createTable(divePlanMissionLegs);
    await migrator.createTable(divePlanMissionMembers);
  }

  /// v306: drops NOT NULL from dive_plan_missions.battery_reserve_fraction
  /// and .walk_speed_mps, so a mission can store "unset, follow the diver's
  /// Settings" (issue #3552) - the DPV Team counterpart of the v305
  /// dive_plans rebuild. A separate rung because this is a different table,
  /// created later (v244) than dive_plans' initial schema.
  Future<void> _assertDivePlanMissionFieldsNullable() => _dropNotNullByRebuild(
    'dive_plan_missions',
    const {'battery_reserve_fraction': 'REAL', 'walk_speed_mps': 'REAL'},
  );
}
