part of '../app_database_migrations.dart';

/// Per-O2-band deco ppO2 limits and the explicit-depth override for 100%
/// O2 (issue #3580), Dive Planner only. Both are optional layers over the
/// existing single `ppO2MaxDeco`/`ppO2Deco` value, off by default: no
/// existing diver's planning behavior changes until they turn one on.
///
/// Column names are Drift's for the getters: `ppO2DecoBand1` is
/// `pp_o2_deco_band1`, as `ppO2MaxDeco` is `pp_o2_max_deco`.
extension PpO2DecoBandMigrations on AppDatabase {
  /// v319: diver_settings gains the band toggle/values and the
  /// explicit-depth toggle/value; dive_plans gains the matching per-plan
  /// overrides (null = follow the diver's Settings). Idempotent; called
  /// from the rung and the beforeOpen backstop.
  Future<void> _assertPpO2DecoBandColumns() async {
    await _addColumnIfMissing(
      'diver_settings',
      'pp_o2_deco_bands_enabled',
      'INTEGER NOT NULL DEFAULT 0 CHECK (pp_o2_deco_bands_enabled IN (0, 1))',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'pp_o2_deco_band1',
      'REAL NOT NULL DEFAULT 1.6',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'pp_o2_deco_band2',
      'REAL NOT NULL DEFAULT 1.6',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'pp_o2_deco_band3',
      'REAL NOT NULL DEFAULT 1.6',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'max_o2_depth_enabled',
      'INTEGER NOT NULL DEFAULT 0 CHECK (max_o2_depth_enabled IN (0, 1))',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'max_o2_depth_meters',
      'REAL NOT NULL DEFAULT 6.0',
    );
    await _addColumnIfMissing('dive_plans', 'pp_o2_deco_band1', 'REAL');
    await _addColumnIfMissing('dive_plans', 'pp_o2_deco_band2', 'REAL');
    await _addColumnIfMissing('dive_plans', 'pp_o2_deco_band3', 'REAL');
    await _addColumnIfMissing('dive_plans', 'max_o2_depth_meters', 'REAL');
  }

  /// v321: dive_plans gains the per-plan "explicitly off" flags for the
  /// bands and the explicit-depth override, matching
  /// `air_breaks_explicitly_off`'s shape - a plan can force either off
  /// regardless of the diver's Settings toggle, distinct from leaving the
  /// per-plan override unset (which follows that toggle). Idempotent;
  /// called from the rung and the beforeOpen backstop.
  Future<void> _assertPpO2DecoBandsExplicitlyOffColumns() async {
    await _addColumnIfMissing(
      'dive_plans',
      'pp_o2_deco_bands_explicitly_off',
      'INTEGER NOT NULL DEFAULT 0 '
          'CHECK (pp_o2_deco_bands_explicitly_off IN (0, 1))',
    );
    await _addColumnIfMissing(
      'dive_plans',
      'max_o2_depth_explicitly_off',
      'INTEGER NOT NULL DEFAULT 0 '
          'CHECK (max_o2_depth_explicitly_off IN (0, 1))',
    );
  }

  /// The band columns as the v319 and v321 helpers first added them, spelled
  /// `ppo2_*`. Drift never read or wrote them, so they hold only their
  /// defaults; on an upgraded database the `pp_o2_*` columns Drift reads
  /// were missing beside them, and every settings and plan read failed
  /// (issue #3809).
  static const _misspelledColumns = {
    'diver_settings': [
      'ppo2_deco_bands_enabled',
      'ppo2_deco_band1',
      'ppo2_deco_band2',
      'ppo2_deco_band3',
    ],
    'dive_plans': [
      'ppo2_deco_band1',
      'ppo2_deco_band2',
      'ppo2_deco_band3',
      'ppo2_deco_bands_explicitly_off',
    ],
  };

  /// v327: drops whichever misspelled band columns a database carries.
  /// Idempotent and a no-op on a table that is absent. Rung only: every
  /// database the misspelled helpers reached is at v326 or below.
  Future<void> _dropMisspelledPpO2DecoBandColumns() async {
    for (final MapEntry(key: table, value: misspelled)
        in _misspelledColumns.entries) {
      await _dropColumnsIfExist(table, misspelled);
    }
  }
}
