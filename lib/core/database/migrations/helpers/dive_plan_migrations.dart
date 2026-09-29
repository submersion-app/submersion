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
}
