part of '../app_database_migrations.dart';

/// The Explore derived metrics (issue #2195).
extension DerivedMetricsMigrations on AppDatabase {
  /// v247: the device-local derived metrics table. Idempotent; skipped on a
  /// partial fixture with no dives table to reference.
  Future<void> _assertDerivedMetricsTable() async {
    if (!await _tableExists('dives')) return;
    await Migrator(this).createTable(diveDerivedMetricsRows);
  }

  /// v347: the gas-use window columns, and where surface breathing stretched
  /// the window (issue #2930). Idempotent; called from
  /// the v347 rung and the beforeOpen backstop. A table [createTable] just
  /// made already has them.
  Future<void> _assertDerivedMetricsGasUseColumns() async {
    if (!await _tableExists('dive_derived_metrics')) return;
    await _addColumnIfMissing('dive_derived_metrics', 'gas_use_s', 'INTEGER');
    await _addColumnIfMissing(
      'dive_derived_metrics',
      'gas_use_avg_depth_m',
      'REAL',
    );
    await _addColumnIfMissing(
      'dive_derived_metrics',
      'surface_breathed_from_s',
      'INTEGER',
    );
    await _addColumnIfMissing(
      'dive_derived_metrics',
      'surface_breathed_until_s',
      'INTEGER',
    );
  }
}
