part of '../app_database_migrations.dart';

/// The rungs that take a database to schema version 231 and above.
///
/// New rungs are appended here. When this file nears 800 lines, give
/// it a closed range like its neighbours and start the next one.
extension RungsFromV231 on AppDatabase {
  Future<void> _rungsFromV231(
    Migrator m,
    int from,
    Future<void> Function() reportProgress,
  ) async {
    // v231: diver_settings CCR ppO2 limits (issue #2342). Column-only
    // rung, no backfill.
    if (from < 231) {
      await _assertCcrPpO2LimitColumns();
    }
    if (from < 231) await reportProgress();

    // v232: trip cylinder slots, their ledger and the dive_tanks link
    // (issue #2325). Tables and one nullable column, no backfill.
    if (from < 232) {
      await _assertTripCylindersSchema();
    }
    if (from < 232) await reportProgress();
    // v233: dive_data_sources.source_diver_key (issue #1921). Column
    // only, no backfill: null means "not recorded", which resync treats
    // as "check the file for a second diver's match".
    if (from < 233) {
      await _assertSourceDiverKeyColumn();
    }
    if (from < 233) await reportProgress();
    // v234: equipment sharing (issue #2046). Table-only rung, no
    // backfill: no existing row changes.
    if (from < 234) {
      await _assertEquipmentSharingSchema();
    }
    if (from < 234) await reportProgress();
    // v235: saved Connections maps and the sightings dive index (issue
    // #2322). Table-and-index rung, no backfill.
    if (from < 235) {
      await _assertConnectionMapsSchema();
    }
    if (from < 235) await reportProgress();
    // v237: diver_settings.show_dive_figure (issue #2326). Column-only
    // rung, default off, no backfill.
    if (from < 237) {
      await _assertShowDiveFigureColumn();
    }
    if (from < 237) await reportProgress();
    // v238: saved_queries (issue #2365). A new synced table, so onUpgrade
    // need only create it; idempotent and re-asserted in the beforeOpen
    // backstop, which is what reaches a database already past 238.
    if (from < 238) {
      await _assertSavedQueriesSchema();
    }
    if (from < 238) await reportProgress();
    // v239: regulator service and O2 clean apply to first and second
    // stages (issue #2275). A one-time UPDATE of two built-in rows; not
    // in the backstop, as v202's built-in backfill is not.
    if (from < 239) {
      await _backfillRegulatorPartServiceKinds();
    }
    if (from < 239) await reportProgress();
    // v240: index dive_profile_events by dive (#1926). Scoped event
    // tombstones delete and match events by dive, and the table had no
    // index on it. Index-only rung; the floor rise it ships with is for
    // the tombstones, not for this. Re-asserted in beforeOpen.
    if (from < 240) {
      await _assertProfileEventsDiveIdIndex();
    }
    if (from < 240) await reportProgress();
    // v241: tank_pressure_series.source_id (issue #2440), backfilled
    // where the source is unambiguous.
    if (from < 241) {
      await _assertTankSeriesSourceIdColumn();
      await _backfillTankSeriesSourceIds();
    }
    if (from < 241) await reportProgress();
    // v242: the equipment service cache (issue #2365). Table-only rung;
    // re-asserted in beforeOpen.
    if (from < 242) {
      await _assertEquipmentServiceStatusTable();
    }
    if (from < 242) await reportProgress();
  }
}
