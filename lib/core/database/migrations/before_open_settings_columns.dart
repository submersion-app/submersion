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
    // v319 backstop: diver_settings per-O2-band deco ppO2 limits and the
    // explicit MOD for 100% O2, plus the matching dive_plans overrides
    // (issue #3580).
    await _assertPpO2DecoBandColumns();

    // v321 backstop: dive_plans per-plan "explicitly off" flags for the
    // bands and the explicit-depth override (issue #3580).
    await _assertPpO2DecoBandsExplicitlyOffColumns();

    // v322 backstop: diver_settings hypercapnia-bailout toggle/factor/
    // duration, plus the matching dive_plans overrides (issue #3743).
    await _assertHypercapniaBailoutColumns();

    // v323 backstop: diver_settings list arrangement columns and clock.
    await _assertListArrangementColumns();

    // v341 backstop: dive_plans series placement columns and the
    // dive_plan_tanks carry-over columns (issue #3565).
    await _assertDivePlanSeriesColumns();

    // v342 backstop: dive_plans.fixed_start and setting_overrides (issue
    // #3565, phase 2).
    await _assertDivePlanPhase2Columns();

    // v343 backstop: diver_settings.first_day_of_week (issue #4232).
    await _assertFirstDayOfWeekColumn();
    // v347 backstop: diver_settings.show_photo_background_on_dive_cards.
    await _assertDiveCardPhotoBackgroundColumn();

    // v351 backstop: diver_settings.equipment_collapsed_groups (issue #4184).
    await _assertEquipmentCollapsedGroupsColumn();

    // v359 backstop: diver_settings.pin_profile_on_scroll (issue #4423).
    await _assertPinProfileOnScrollColumn();

    // v360 backstop: diver_settings.show_country_flags (issue #4426).
    await _assertShowCountryFlagsColumn();
  }
}
