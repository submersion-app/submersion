part of 'app_database_migrations.dart';

/// The table-creation backstops from v217 on, run in this order from
/// `_beforeOpen`. Split out of before_open.dart, which reached the 800-line
/// limit (issue #2502). Each one is idempotent, so a database that arrives by
/// restore or sync-adopt, or sits above a rung that a parallel branch shipped
/// later, still gains the tables.
extension TableBackstopsFromV217 on AppDatabase {
  Future<void> _tableBackstopsFromV217() async {
    // v217 backstop: site classification tables, seed and indexes
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertSiteClassificationSchema();

    // v219 backstop: the equipment tag junction and its index
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertEquipmentTagSchema();

    // v221 backstop: the rental gear notes table (parallel-branch
    // version-collision self-heal; createTable is idempotent).
    await _assertDiveCenterGearNotesSchema();

    // v232 backstop: the trip cylinder tables and the dive_tanks link
    // (parallel-branch version-collision self-heal; all idempotent).
    await _assertTripCylindersSchema();

    // v234 backstop: the equipment sharing tables and the share pair
    // index (parallel-branch version-collision self-heal; all
    // idempotent).
    await _assertEquipmentSharingSchema();

    // v235 backstop: connection_maps and idx_sightings_dive_id
    // (parallel-branch version-collision self-heal; idempotent).
    await _assertConnectionMapsSchema();

    // v238 backstop: re-assert the saved_queries table. A database that
    // arrives by restore or sync-adopt never runs onUpgrade, and one
    // already at 239 or later skips the v238 rung.
    await _assertSavedQueriesSchema();

    // v242 backstop: the equipment service cache (local, idempotent).
    await _assertEquipmentServiceStatusTable();

    // v245 backstop: the certifications buddy index (idempotent).
    await _assertCertificationsBuddyIndex();
    // v247 backstop: the Explore derived metrics (local, idempotent).
    await _assertDerivedMetricsTable();

    // v248 backstop: trip_equipment and its item index (idempotent).
    await _assertTripEquipmentSchema();

    // v250 backstop: trip_hides and site_hides (idempotent).
    await _assertTripHidesSchema();
    await _assertSiteHidesSchema();

    // v265 backstop: Insights observation dismissals and muted rules.
    await _assertInsightObservationsSchema();

    // v267 backstop: the custom certification tables (parallel-branch
    // version-collision self-heal; idempotent).
    await _assertCustomCertificationSchema();

    // v268 backstop: the equipment location tables (parallel-branch
    // version-collision self-heal; idempotent).
    await _assertEquipmentLocationSchema();
  }
}
