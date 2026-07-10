/// Canonical performance-index set for the Submersion database.
///
/// Historically these indexes were created only inside onUpgrade migration
/// blocks, so a database created fresh at a recent schema version -- or
/// arriving via restore or sync-adopt -- never got them and every child-table
/// lookup degraded to a full table scan (issue: large-DB performance,
/// docs/superpowers/specs/2026-07-10-large-db-performance-design.md).
///
/// This list is asserted idempotently on every open from
/// AppDatabase.beforeOpen. Keep it in sync: any migration that adds a
/// performance index must also add it here (the fresh-DB test in
/// test/core/database/performance_indexes_test.dart fails if the DDL
/// references a table missing from the current schema).
///
/// This file must stay Flutter-free: it is imported by tools/db_bench.dart,
/// which runs on the plain Dart VM.
library;

import 'package:drift/drift.dart';

typedef PerformanceIndex = ({String name, String ddl});

const List<PerformanceIndex> kPerformanceIndexes = [
  // -- dives ------------------------------------------------------------
  (
    name: 'idx_dives_diver_datetime',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dives_diver_datetime '
        'ON dives(diver_id, dive_date_time DESC)',
  ),
  (
    name: 'idx_dives_diver_entrytime',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dives_diver_entrytime '
        'ON dives(diver_id, entry_time DESC)',
  ),
  (
    name: 'idx_dives_diver_exittime',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dives_diver_exittime '
        'ON dives(diver_id, exit_time DESC)',
  ),
  // NOTE: an expression index on (diver_id, COALESCE(entry_time,
  // dive_date_time) DESC) matching the paginated list's sort key was
  // evaluated in the WS0 baseline and DROPPED: the planner never selected
  // it (sorting a ~1k-row candidate set beats maintaining expression-index
  // order), so it would cost write amplification for nothing. Evidence in
  // docs/superpowers/specs/2026-07-10-large-db-performance-findings.md.
  (
    name: 'idx_dives_site_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_site_id ON dives(site_id)',
  ),
  (
    name: 'idx_dives_trip_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_trip_id ON dives(trip_id)',
  ),
  (
    name: 'idx_dives_dive_center_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dives_dive_center_id '
        'ON dives(dive_center_id)',
  ),
  (
    name: 'idx_dives_course_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_course_id ON dives(course_id)',
  ),
  (
    name: 'idx_dives_favorite',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dives_favorite '
        'ON dives(diver_id, is_favorite)',
  ),
  // -- per-dive child tables (the million-row scans) ---------------------
  (
    name: 'idx_dive_profiles_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_profiles_dive_id '
        'ON dive_profiles(dive_id)',
  ),
  (
    name: 'idx_tank_pressure_dive_tank',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank '
        'ON tank_pressure_profiles(dive_id, tank_id, timestamp)',
  ),
  (
    name: 'idx_dive_tanks_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_tanks_dive_id '
        'ON dive_tanks(dive_id)',
  ),
  (
    name: 'idx_dive_equipment_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_equipment_dive_id '
        'ON dive_equipment(dive_id)',
  ),
  (
    name: 'idx_dive_weights_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_weights_dive_id '
        'ON dive_weights(dive_id)',
  ),
  (
    name: 'idx_dive_tags_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_tags_dive_id '
        'ON dive_tags(dive_id)',
  ),
  (
    name: 'idx_dive_tags_tag_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_tags_tag_id '
        'ON dive_tags(tag_id)',
  ),
  (
    name: 'idx_dive_buddies_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_buddies_dive_id '
        'ON dive_buddies(dive_id)',
  ),
  (
    name: 'idx_dive_custom_fields_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_dive_id '
        'ON dive_custom_fields(dive_id)',
  ),
  (
    name: 'idx_dive_custom_fields_key',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_key '
        'ON dive_custom_fields(field_key)',
  ),
  (
    name: 'idx_dive_data_sources_dive_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_data_sources_dive_id '
        'ON dive_data_sources(dive_id)',
  ),
  (
    name: 'idx_tide_records_dive',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_tide_records_dive '
        'ON tide_records(dive_id)',
  ),
  // -- sync ---------------------------------------------------------------
  (
    name: 'idx_sync_records_entity_record',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_sync_records_entity_record '
        'ON sync_records(entity_type, record_id)',
  ),
  // -- reference / feature tables ------------------------------------------
  (
    name: 'idx_site_species_site',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_site_species_site '
        'ON site_species(site_id)',
  ),
  (
    name: 'idx_courses_diver',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_courses_diver ON courses(diver_id)',
  ),
  (
    name: 'idx_media_platform_asset_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_platform_asset_id '
        'ON media(platform_asset_id)',
  ),
  (
    name: 'idx_media_enrichment_media',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_enrichment_media '
        'ON media_enrichment(media_id)',
  ),
  (
    name: 'idx_media_enrichment_dive',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_enrichment_dive '
        'ON media_enrichment(dive_id)',
  ),
  (
    name: 'idx_media_species_media',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_species_media '
        'ON media_species(media_id)',
  ),
  (
    name: 'idx_media_species_species',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_species_species '
        'ON media_species(species_id)',
  ),
  (
    name: 'idx_pending_photo_suggestions_dive',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_pending_photo_suggestions_dive '
        'ON pending_photo_suggestions(dive_id)',
  ),
  (
    name: 'idx_scheduled_notifications_equipment',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_equipment '
        'ON scheduled_notifications(equipment_id)',
  ),
  (
    name: 'idx_view_configs_diver',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_view_configs_diver '
        'ON view_configs(diver_id, view_mode)',
  ),
  (
    name: 'idx_field_presets_diver',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_field_presets_diver '
        'ON field_presets(diver_id, view_mode)',
  ),
  (
    name: 'idx_media_source_type',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_source_type '
        'ON media(source_type)',
  ),
  (
    name: 'idx_media_connector_account',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_connector_account '
        'ON media(connector_account_id)',
  ),
  (
    name: 'idx_media_origin_device',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_media_origin_device '
        'ON media(origin_device_id)',
  ),
  (
    name: 'idx_checklist_template_items_template_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_checklist_template_items_template_id '
        'ON checklist_template_items(template_id)',
  ),
  (
    name: 'idx_trip_checklist_items_trip_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_trip_checklist_items_trip_id '
        'ON trip_checklist_items(trip_id)',
  ),
  (
    name: 'idx_dive_plan_tanks_plan_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_plan_tanks_plan_id '
        'ON dive_plan_tanks(plan_id)',
  ),
  (
    name: 'idx_dive_plan_segments_plan_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_plan_segments_plan_id '
        'ON dive_plan_segments(plan_id)',
  ),
  (
    name: 'idx_gps_track_points_local_track_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_gps_track_points_local_track_id '
        'ON gps_track_points_local(track_id)',
  ),
];

/// Creates any canonical index missing from [db], returning the names of
/// indexes actually created (empty when the database was already healed).
///
/// A statement whose table or column does not exist is skipped: migration
/// tests open minimal old-schema fixtures where most tables (or late-added
/// columns) are absent, and beforeOpen must tolerate them. On any real
/// database the full ladder has run before beforeOpen, so the whole set
/// applies; the fresh-DB test fails loudly if a canonical entry stops
/// matching the current schema, so skips cannot mask a stale list.
///
/// Runs ANALYZE (bounded by analysis_limit) only when something was created,
/// so the query planner picks up the new indexes; every later open is a
/// single sqlite_master read.
Future<List<String>> ensurePerformanceIndexes(GeneratedDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  final existing = rows.map((r) => r.read<String>('name')).toSet();

  final created = <String>[];
  for (final index in kPerformanceIndexes) {
    if (existing.contains(index.name)) continue;
    try {
      await db.customStatement(index.ddl);
      created.add(index.name);
    } catch (e) {
      final message = e.toString();
      final schemaTooOld =
          message.contains('no such table') ||
          message.contains('no such column');
      if (!schemaTooOld) rethrow;
    }
  }
  if (created.isNotEmpty) {
    await db.customStatement('PRAGMA analysis_limit = 400');
    await db.customStatement('ANALYZE');
  }
  return created;
}
