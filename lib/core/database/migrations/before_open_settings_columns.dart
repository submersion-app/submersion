part of 'app_database_migrations.dart';

/// Backstops for the newest diver_settings and dive_plans columns, split out
/// of before_open.dart to keep it under the migration file size limit.
extension BeforeOpenSettingsColumns on AppDatabase {
  /// Re-asserts what a database that arrived by restore or sync-adopt, or one
  /// a renumbered rung skipped, may lack. Each helper is idempotent.
  Future<void> _assertSettingsColumnsFromV307() async {
    // v307 backstop: diver_settings air-break/turn-pressure defaults and
    // dive_plans.air_breaks_explicitly_off.
    await _assertAirBreaksTurnPressureDefaultColumns();
    // v308 backstop: dive_plans reserve_pressure/gf_low/gf_high made
    // nullable, diver_settings.planner_reserve_pressure added.
    await _assertDivePlanReserveAndGfNullable();
    // v310 backstop: diver_settings.downloads_follow_computer_owner.
    await _assertDownloadOwnerColumn();
    // v315 backstop: diver_settings.omit_unused_oc_gases.
    await _assertOmitUnusedOcGasesColumn();
  }
}
