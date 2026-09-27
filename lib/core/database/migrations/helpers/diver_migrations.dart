part of '../app_database_migrations.dart';

/// Diver profiles and diver settings.
extension DiverMigrations on AppDatabase {
  /// v206: the condition engine's master and per-rule toggles on
  /// diver_settings, and the transmitter registry's link to the transmitter
  /// gear item an entry is (condition phase 3b). Idempotent; called from the
  /// v206 onUpgrade block and the beforeOpen backstop, which is also how a
  /// device already past 206 gets the registry link.
  Future<void> _assertConditionEngineSettingsColumns() async {
    await _addColumnIfMissing(
      'diver_settings',
      'condition_engine_enabled',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'condition_disabled_rules',
      'TEXT',
    );
    // A partial-schema fixture may lack the equipment table, and with
    // foreign keys on SQLite then refuses every later insert into a table
    // whose FK parent is missing; those get a plain column (as v202 does).
    await _addColumnIfMissing(
      'transmitters',
      'transmitter_equipment_id',
      await _tableExists('equipment')
          ? 'TEXT REFERENCES equipment(id) ON DELETE SET NULL'
          : 'TEXT',
    );
  }

  /// v113: diver_settings.cns_calculation_method column. Self-guarding when
  /// the diver_settings table is absent (partial-schema migration tests), so
  /// it is safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertCnsCalculationMethodColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final hasColumn = cols.any(
      (c) => c.read<String>('name') == 'cns_calculation_method',
    );
    if (cols.isNotEmpty && !hasColumn) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN cns_calculation_method "
        "TEXT NOT NULL DEFAULT 'shearwater'",
      );
    }
  }

  /// v125: diver_settings.no_fly_preset column. Idempotent so it is safe to
  /// call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertNoFlySettingsColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('no_fly_preset')) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN no_fly_preset TEXT "
        "NOT NULL DEFAULT 'standard'",
      );
    }
  }

  /// v185: diver_settings.dive_detail_layout, the dive detail page's layout
  /// choice (detailed/list; a stored "compact" from before that layout was
  /// dropped reads back as detailed). Idempotent so it is safe to call from
  /// both onUpgrade and the beforeOpen backstop.
  Future<void> _assertDiveDetailLayoutColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('dive_detail_layout')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN dive_detail_layout TEXT',
      );
    }
  }

  /// v222: diver_settings.seascape_vertical_exaggeration_overrides (issue
  /// #2141 follow-up). Additive column, default null, so a diver with no
  /// per-site overrides keeps today's fully-automatic behavior. Idempotent,
  /// so it is safe to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertSeascapeVerticalExaggerationOverridesColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('seascape_vertical_exaggeration_overrides')) {
      await customStatement(
        'ALTER TABLE diver_settings '
        'ADD COLUMN seascape_vertical_exaggeration_overrides TEXT',
      );
    }
  }

  /// v227: diver_settings.hidden_tank_preset_ids (issue #2305). Additive
  /// column, default null, so every built-in preset stays visible until the
  /// diver hides one. Idempotent, so it is safe to call from both onUpgrade
  /// and the beforeOpen backstop.
  Future<void> _assertHiddenTankPresetIdsColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('hidden_tank_preset_ids')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN hidden_tank_preset_ids TEXT',
      );
    }
  }

  /// v133: diver_settings deco stop band columns. PRAGMA-guarded and
  /// idempotent so it is safe to call from both onUpgrade and the beforeOpen
  /// backstop. The guard on cols.isNotEmpty keeps partial-schema migration
  /// tests, which open databases without this table, from crashing on DDL.
  Future<void> _assertDecoStopSettingsColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (cols.isNotEmpty && !names.contains('show_deco_stops_on_profile')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN show_deco_stops_on_profile '
        'INTEGER NOT NULL DEFAULT 1 '
        'CHECK (show_deco_stops_on_profile IN (0, 1))',
      );
    }
    if (cols.isNotEmpty && !names.contains('default_deco_stop_source')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_deco_stop_source '
        'INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  /// v135: color accent toggle columns on diver_settings. Idempotent; safe
  /// to call from both onUpgrade and the beforeOpen backstop.
  Future<void> _assertAccentColorSettingsColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    for (final column in const [
      'accent_nav_icons',
      'accent_section_headers',
      'accent_list_icons',
    ]) {
      if (!names.contains(column)) {
        await customStatement(
          'ALTER TABLE diver_settings ADD COLUMN $column '
          'INTEGER NOT NULL DEFAULT 0 CHECK ($column IN (0, 1))',
        );
      }
    }
  }

  /// Idempotent DDL for the v141 diver_settings.default_currency column.
  /// Called from the v141 onUpgrade step and the beforeOpen backstop, and
  /// self-guarding when the table is absent (minimal migration-test fixtures).
  Future<void> _assertDefaultCurrencyColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('default_currency')) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN default_currency TEXT NOT NULL DEFAULT 'USD'",
      );
    }
  }

  /// Idempotent DDL for the v144 diver_settings visibility calibration
  /// columns. Same dual-call contract as [_assertVisibilityMetersColumn].
  Future<void> _assertVisibilityScaleColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('visibility_scale_preset')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN visibility_scale_preset '
        "TEXT NOT NULL DEFAULT 'tropical'",
      );
    }
    if (!names.contains('visibility_scale_excellent_m')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN visibility_scale_excellent_m '
        'REAL',
      );
    }
    if (!names.contains('visibility_scale_good_m')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN visibility_scale_good_m REAL',
      );
    }
    if (!names.contains('visibility_scale_moderate_m')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN visibility_scale_moderate_m '
        'REAL',
      );
    }
  }

  /// Idempotent DDL for the v150 diver_settings coordinate format column.
  /// Same dual-call contract as [_assertVisibilityScaleColumns].
  Future<void> _assertCoordinateFormatColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('coordinate_format')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN coordinate_format '
        "TEXT NOT NULL DEFAULT 'decimalDegrees'",
      );
    }
  }

  /// Idempotent DDL for the v151 diver_settings seascape appearance blob.
  /// Same dual-call contract as [_assertVisibilityScaleColumns]. Nullable
  /// with no default: null marks a pre-v151 row (see the table comment).
  Future<void> _assertSeascapeAppearanceColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('seascape_appearance')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN seascape_appearance TEXT',
      );
    }
  }

  /// Raw O2 cell output columns on dive_profiles (issue #810). PRAGMA-guarded
  /// so a healthy database no-ops and a partial schema does not throw.
  /// Add `diver_settings.gas_model` if it is missing (v155, issue #828).
  Future<void> _assertGasModelColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('gas_model')) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN gas_model TEXT NOT NULL "
        "DEFAULT 'real'",
      );
    }
  }

  /// v161: default_show_o2_cell_mv on diver_settings (issue #1235). The
  /// per-cell O2 mV toggle previously had no persisted default; this lets a
  /// diver make it visible by default on the profile chart.
  Future<void> _assertO2CellMvDefaultColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('default_show_o2_cell_mv')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_o2_cell_mv '
        'INTEGER NOT NULL DEFAULT 0 '
        'CHECK (default_show_o2_cell_mv IN (0, 1))',
      );
    }
  }

  /// v177: the GTR (gas time remaining) settings on diver_settings: default
  /// visibility, computer-vs-calculated source, and the reserve pressure
  /// (bar) the calculated value counts down to.
  Future<void> _assertGtrSettingsColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('default_show_gtr')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_show_gtr '
        'INTEGER NOT NULL DEFAULT 0 '
        'CHECK (default_show_gtr IN (0, 1))',
      );
    }
    if (!names.contains('default_gtr_source')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN default_gtr_source '
        'INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (!names.contains('gtr_reserve_pressure')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN gtr_reserve_pressure '
        'REAL NOT NULL DEFAULT 50.0',
      );
    }
  }

  /// v163: default_show_estimated_tank_pressure on diver_settings (issue
  /// #731). Synthesized "(est.)" pressure lines previously had no off switch.
  /// Defaults to 1 so existing databases keep drawing them.
  Future<void> _assertEstimatedTankPressureDefaultColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('default_show_estimated_tank_pressure')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN '
        'default_show_estimated_tank_pressure '
        'INTEGER NOT NULL DEFAULT 1 '
        'CHECK (default_show_estimated_tank_pressure IN (0, 1))',
      );
    }
  }

  /// v165: trim_tank_pressure_at_surfacing on diver_settings (issue #1092).
  /// Dive computers keep recording after the diver surfaces, so the last
  /// pressure in the profile is not the pressure at the end of the dive. On
  /// by default, because the reading it prefers can only ever be the higher,
  /// earlier one.
  Future<void> _assertSurfacingPressureColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('trim_tank_pressure_at_surfacing')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN trim_tank_pressure_at_surfacing '
        'INTEGER NOT NULL DEFAULT 1 '
        'CHECK (trim_tank_pressure_at_surfacing IN (0, 1))',
      );
    }
  }

  /// v166: place_name_language on diver_settings (issue #1187). Defaults to
  /// 'en', the language every pre-v166 row was geocoded in (issue #214).
  Future<void> _assertPlaceNameLanguageColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('place_name_language')) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN place_name_language TEXT "
        "NOT NULL DEFAULT 'en'",
      );
    }
  }

  /// v170: diver_settings.sac_unit becomes gas_consumption_display and its
  /// values move from a unit choice to a lane choice (discussions #354 and
  /// #803). Guarded like the v160 rename, so a database that reaches 170 by
  /// restore or sync-adopt (neither runs onUpgrade) heals in beforeOpen. The
  /// value rewrite is idempotent: it only touches the two retired spellings
  /// and anything that is not a known lane name.
  Future<void> _assertGasConsumptionDisplayColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('sac_unit') &&
        !names.contains('gas_consumption_display')) {
      await customStatement(
        'ALTER TABLE diver_settings '
        'RENAME COLUMN sac_unit TO gas_consumption_display',
      );
    } else if (!names.contains('gas_consumption_display')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN gas_consumption_display '
        "TEXT NOT NULL DEFAULT 'both'",
      );
      return;
    }
    await customStatement(
      'UPDATE diver_settings SET gas_consumption_display = '
      'CASE gas_consumption_display '
      "WHEN 'litersPerMin' THEN 'rmv' "
      "WHEN 'pressurePerMin' THEN 'sac' "
      "WHEN 'sac' THEN 'sac' WHEN 'rmv' THEN 'rmv' WHEN 'both' THEN 'both' "
      "ELSE 'both' END "
      "WHERE gas_consumption_display NOT IN ('sac', 'rmv', 'both')",
    );
  }

  /// v170, rung only: a saved dive-table layout names its columns by enum
  /// value, and the sacRate column split into sac and rmv. Point each
  /// diver's layout at the lane they were seeing. Runs after
  /// [_assertGasConsumptionDisplayColumn] so the lane names are final.
  ///
  /// Never called from beforeOpen: diveFieldFromName aliases sacRate to sac
  /// for layouts that arrive later by sync, and re-running this on every
  /// open would rewrite rows the diver has since changed. No
  /// HLC bump: every device applies the same deterministic rewrite to its
  /// own rows, so there is nothing to push.
  Future<void> _rewriteLegacySacRateLayouts() async {
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('view_configs', 'diver_settings')",
    ).get();
    if (tables.length < 2) return;
    await customStatement('''
      UPDATE view_configs
        SET config_json = REPLACE(config_json, '"sacRate"', '"rmv"')
        WHERE config_json LIKE '%"sacRate"%'
          AND diver_id IN (SELECT diver_id FROM diver_settings
                           WHERE gas_consumption_display = 'rmv')
    ''');
    await customStatement('''
      UPDATE view_configs
        SET config_json = REPLACE(config_json, '"sacRate"', '"sac"')
        WHERE config_json LIKE '%"sacRate"%'
    ''');
  }

  /// v188: the two insurer phone numbers the emergency card leads with.
  /// Column-only and independently guarded, so an interrupted upgrade that
  /// added one of the two still gets the other.
  Future<void> _assertInsurancePhoneColumns() async {
    final cols = await customSelect("PRAGMA table_info('divers')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('insurance_emergency_phone')) {
      await customStatement(
        'ALTER TABLE divers ADD COLUMN insurance_emergency_phone TEXT',
      );
    }
    if (!names.contains('insurance_phone')) {
      await customStatement(
        'ALTER TABLE divers ADD COLUMN insurance_phone TEXT',
      );
    }
  }

  /// Idempotent DDL for the v181 divers.photo and buddies.photo columns.
  /// Holds a 512x512 square JPEG, so it is nullable with no default. Self-
  /// guards on each table existing, which is what makes it safe to call from
  /// both the ladder and beforeOpen.
  Future<void> _assertProfilePhotoColumns() async {
    for (final table in const ['divers', 'buddies']) {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('photo')) {
        await customStatement('ALTER TABLE $table ADD COLUMN photo BLOB');
      }
    }
  }

  /// Idempotent DDL for diver_settings.default_planner_water_type (v198).
  /// Existing rows get salt, matching the new-plan default.
  Future<void> _assertDefaultPlannerWaterTypeColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('default_planner_water_type')) return;
    await customStatement(
      "ALTER TABLE diver_settings ADD COLUMN default_planner_water_type "
      "TEXT NOT NULL DEFAULT 'salt'",
    );
  }

  /// Idempotent DDL for diver_settings.group_trips_in_dive_list (v204).
  /// Existing rows default to off, matching a fresh install: turning the dive
  /// list into trip groups is opt-in.
  Future<void> _assertGroupTripsInDiveListColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('group_trips_in_dive_list')) return;
    await customStatement(
      'ALTER TABLE diver_settings ADD COLUMN group_trips_in_dive_list '
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  /// Idempotent DDL for the diver_settings CCR ppO2 limits (v231, issue
  /// #2342). Existing rows get the defaults the planner already assumed for
  /// a new CCR plan (0.7 / 1.3) and the 1.6 bar flush ceiling.
  Future<void> _assertCcrPpO2LimitColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    const columns = {
      'ccr_setpoint_low': '0.7',
      'ccr_setpoint_high': '1.3',
      'ccr_diluent_mod_pp_o2': '1.6',
    };
    for (final entry in columns.entries) {
      if (names.contains(entry.key)) continue;
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN '
        '${entry.key} REAL NOT NULL DEFAULT ${entry.value}',
      );
    }
  }

  /// Idempotent DDL for diver_settings.auto_tag_imports (v211, issue #998).
  /// Existing rows default to on, matching the wizard's prior behavior of
  /// always pre-filling an import tag.
  Future<void> _assertAutoTagImportsColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('auto_tag_imports')) return;
    await customStatement(
      'ALTER TABLE diver_settings ADD COLUMN '
      'auto_tag_imports INTEGER NOT NULL DEFAULT 1',
    );
  }
}
