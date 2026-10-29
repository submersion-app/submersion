part of '../app_database_migrations.dart';

/// Per-O2-band deco ppO2 limits and the explicit-depth override for 100%
/// O2 (issue #3580), Dive Planner only. Both are optional layers over the
/// existing single `ppO2MaxDeco`/`ppO2Deco` value, off by default: no
/// existing diver's planning behavior changes until they turn one on.
extension PpO2DecoBandMigrations on AppDatabase {
  /// v319: diver_settings gains the band toggle/values and the
  /// explicit-depth toggle/value; dive_plans gains the matching per-plan
  /// overrides (null = follow the diver's Settings). Idempotent; called
  /// from the rung and the beforeOpen backstop.
  Future<void> _assertPpO2DecoBandColumns() async {
    await _addColumnIfMissing(
      'diver_settings',
      'ppo2_deco_bands_enabled',
      'INTEGER NOT NULL DEFAULT 0 CHECK (ppo2_deco_bands_enabled IN (0, 1))',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'ppo2_deco_band1',
      'REAL NOT NULL DEFAULT 1.6',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'ppo2_deco_band2',
      'REAL NOT NULL DEFAULT 1.6',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'ppo2_deco_band3',
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
    await _addColumnIfMissing('dive_plans', 'ppo2_deco_band1', 'REAL');
    await _addColumnIfMissing('dive_plans', 'ppo2_deco_band2', 'REAL');
    await _addColumnIfMissing('dive_plans', 'ppo2_deco_band3', 'REAL');
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
      'ppo2_deco_bands_explicitly_off',
      'INTEGER NOT NULL DEFAULT 0 '
          'CHECK (ppo2_deco_bands_explicitly_off IN (0, 1))',
    );
    await _addColumnIfMissing(
      'dive_plans',
      'max_o2_depth_explicitly_off',
      'INTEGER NOT NULL DEFAULT 0 '
          'CHECK (max_o2_depth_explicitly_off IN (0, 1))',
    );
  }
}
