/// What the change log records, table by table (issue #3922).
///
/// The triggers are generated from this file, so a table or column is added
/// to the log, or kept out of it, here and nowhere else.
library;

import 'package:submersion/core/services/sync/child_column_clears.dart';
import 'package:submersion/core/services/sync/device_local_fields.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

enum ChangeLogClass {
  /// Inserts, updates and deletes are all recorded.
  tracked,

  /// Machine rows a restore needs: only a delete is recorded, with a copy of
  /// the row.
  deleteCopyOnly,

  /// No triggers.
  excluded,
}

/// Every table in `allTables`, plus the raw SQL tables in
/// `changeLogRawTableSpecs`. A test fails on a table missing from here, so a
/// new table cannot be left out by accident.
const Map<String, ChangeLogClass> changeLogTables = {
  'buddies': ChangeLogClass.tracked,
  'certification_currency_events': ChangeLogClass.tracked,
  'certification_currency_prefs': ChangeLogClass.tracked,
  'certification_currency_rules': ChangeLogClass.tracked,
  'certifications': ChangeLogClass.tracked,
  'checklist_template_items': ChangeLogClass.tracked,
  'checklist_template_sections': ChangeLogClass.tracked,
  'checklist_templates': ChangeLogClass.tracked,
  'connection_maps': ChangeLogClass.tracked,
  'course_requirement_dives': ChangeLogClass.tracked,
  'course_requirements': ChangeLogClass.tracked,
  'courses': ChangeLogClass.tracked,
  'csv_presets': ChangeLogClass.tracked,
  'custom_certification_agencies': ChangeLogClass.tracked,
  'custom_certification_levels': ChangeLogClass.tracked,
  'cylinder_config_items': ChangeLogClass.tracked,
  'cylinder_configs': ChangeLogClass.tracked,
  'cylinder_fills': ChangeLogClass.tracked,
  'dive_buddies': ChangeLogClass.tracked,
  'dive_buddy_roles': ChangeLogClass.tracked,
  'dive_center_gear_notes': ChangeLogClass.tracked,
  'dive_centers': ChangeLogClass.tracked,
  'dive_computer_connections': ChangeLogClass.tracked,
  'dive_computers': ChangeLogClass.tracked,
  'dive_courses': ChangeLogClass.tracked,
  'dive_custom_fields': ChangeLogClass.tracked,
  'dive_data_sources': ChangeLogClass.tracked,
  'dive_dive_types': ChangeLogClass.tracked,
  'dive_diver_roles': ChangeLogClass.tracked,
  'dive_equipment': ChangeLogClass.tracked,
  'dive_plan_equipment': ChangeLogClass.tracked,
  'dive_plan_mission_legs': ChangeLogClass.tracked,
  'dive_plan_mission_members': ChangeLogClass.tracked,
  'dive_plan_missions': ChangeLogClass.tracked,
  'dive_plan_segments': ChangeLogClass.tracked,
  'dive_plan_tanks': ChangeLogClass.tracked,
  'dive_plans': ChangeLogClass.tracked,
  'dive_profile_events': ChangeLogClass.tracked,
  'dive_roles': ChangeLogClass.tracked,
  'dive_scenarios': ChangeLogClass.tracked,
  'dive_sites': ChangeLogClass.tracked,
  'dive_tags': ChangeLogClass.tracked,
  'dive_tanks': ChangeLogClass.tracked,
  'dive_types': ChangeLogClass.tracked,
  'dive_weights': ChangeLogClass.tracked,
  'diver_settings': ChangeLogClass.tracked,
  'diver_weight_entries': ChangeLogClass.tracked,
  'divers': ChangeLogClass.tracked,
  'dives': ChangeLogClass.tracked,
  'document_pages': ChangeLogClass.tracked,
  'document_tags': ChangeLogClass.tracked,
  'documents': ChangeLogClass.tracked,
  'emergency_chambers': ChangeLogClass.tracked,
  'equipment': ChangeLogClass.tracked,
  'equipment_attributes': ChangeLogClass.tracked,
  'equipment_components': ChangeLogClass.tracked,
  'equipment_location_moves': ChangeLogClass.tracked,
  'equipment_locations': ChangeLogClass.tracked,
  'equipment_observations': ChangeLogClass.tracked,
  'equipment_ownership_events': ChangeLogClass.tracked,
  'equipment_set_geofences': ChangeLogClass.tracked,
  'equipment_set_items': ChangeLogClass.tracked,
  'equipment_sets': ChangeLogClass.tracked,
  'equipment_shares': ChangeLogClass.tracked,
  'equipment_tags': ChangeLogClass.tracked,
  'field_presets': ChangeLogClass.tracked,
  'gas_switches': ChangeLogClass.tracked,
  'gps_tracks': ChangeLogClass.tracked,
  'imported_files': ChangeLogClass.tracked,
  'incidents': ChangeLogClass.tracked,
  'insight_observation_dismissals': ChangeLogClass.tracked,
  'library_site_notes': ChangeLogClass.tracked,
  'liveaboard_detail_records': ChangeLogClass.tracked,
  'media': ChangeLogClass.tracked,
  'media_people': ChangeLogClass.tracked,
  'media_smart_albums': ChangeLogClass.tracked,
  'media_species': ChangeLogClass.tracked,
  'media_stores': ChangeLogClass.tracked,
  'media_subscriptions': ChangeLogClass.tracked,
  'media_tags': ChangeLogClass.tracked,
  'nav_tracks': ChangeLogClass.tracked,
  'pre_dive_checklist_template_items': ChangeLogClass.tracked,
  'pre_dive_checklist_template_sections': ChangeLogClass.tracked,
  'pre_dive_checklist_templates': ChangeLogClass.tracked,
  'pre_dive_session_items': ChangeLogClass.tracked,
  'pre_dive_session_sections': ChangeLogClass.tracked,
  'pre_dive_sessions': ChangeLogClass.tracked,
  'rules': ChangeLogClass.tracked,
  'saved_queries': ChangeLogClass.tracked,
  'service_kinds': ChangeLogClass.tracked,
  'service_records': ChangeLogClass.tracked,
  'service_schedules': ChangeLogClass.tracked,
  'settings': ChangeLogClass.tracked,
  'sightings': ChangeLogClass.tracked,
  'site_features': ChangeLogClass.tracked,
  'site_hides': ChangeLogClass.tracked,
  'site_shares': ChangeLogClass.tracked,
  'site_site_types': ChangeLogClass.tracked,
  'site_species': ChangeLogClass.tracked,
  'site_tags': ChangeLogClass.tracked,
  'site_types': ChangeLogClass.tracked,
  'species': ChangeLogClass.tracked,
  'tags': ChangeLogClass.tracked,
  'tank_presets': ChangeLogClass.tracked,
  'transmitters': ChangeLogClass.tracked,
  'trip_checklist_items': ChangeLogClass.tracked,
  'trip_checklist_sections': ChangeLogClass.tracked,
  'trip_checklists': ChangeLogClass.tracked,
  'trip_cylinder_events': ChangeLogClass.tracked,
  'trip_cylinders': ChangeLogClass.tracked,
  'trip_equipment': ChangeLogClass.tracked,
  'trip_hides': ChangeLogClass.tracked,
  'trip_itinerary_days': ChangeLogClass.tracked,
  'trip_shares': ChangeLogClass.tracked,
  'trips': ChangeLogClass.tracked,
  'weight_preset_entries': ChangeLogClass.tracked,
  'weight_presets': ChangeLogClass.tracked,
  'dive_profile_series': ChangeLogClass.deleteCopyOnly,
  'dive_profile_series_history': ChangeLogClass.deleteCopyOnly,
  'dive_safety_findings': ChangeLogClass.deleteCopyOnly,
  'dive_safety_reviews': ChangeLogClass.deleteCopyOnly,
  'media_enrichment': ChangeLogClass.deleteCopyOnly,
  'tank_pressure_series': ChangeLogClass.deleteCopyOnly,
  'tide_records': ChangeLogClass.deleteCopyOnly,
  'cached_regions': ChangeLogClass.excluded,
  'change_log_context': ChangeLogClass.excluded,
  'change_log_events': ChangeLogClass.excluded,
  'change_log_fields': ChangeLogClass.excluded,
  'change_log_operations': ChangeLogClass.excluded,
  'connected_accounts': ChangeLogClass.excluded,
  'deletion_log': ChangeLogClass.excluded,
  'dive_derived_metrics': ChangeLogClass.excluded,
  'dive_sensor_summaries': ChangeLogClass.excluded,
  'equipment_condition_reviews': ChangeLogClass.excluded,
  'equipment_findings': ChangeLogClass.excluded,
  'equipment_service_status': ChangeLogClass.excluded,
  'gps_track_points_local': ChangeLogClass.excluded,
  'local_publish_states': ChangeLogClass.excluded,
  'media_fetch_diagnostics': ChangeLogClass.excluded,
  'media_repair_log': ChangeLogClass.excluded,
  'media_subscription_state': ChangeLogClass.excluded,
  'nearby_peers': ChangeLogClass.excluded,
  'network_credential_hosts': ChangeLogClass.excluded,
  'pending_photo_suggestions': ChangeLogClass.excluded,
  'quality_findings': ChangeLogClass.excluded,
  'rule_run_changes': ChangeLogClass.excluded,
  'rule_runs': ChangeLogClass.excluded,
  'scheduled_notifications': ChangeLogClass.excluded,
  'shared_libraries': ChangeLogClass.excluded,
  'shared_library_backups': ChangeLogClass.excluded,
  'shared_library_members': ChangeLogClass.excluded,
  'shared_library_memberships': ChangeLogClass.excluded,
  'shared_site_states': ChangeLogClass.excluded,
  'shared_site_suggestions': ChangeLogClass.excluded,
  'sync_metadata': ChangeLogClass.excluded,
  'sync_peer_cursors': ChangeLogClass.excluded,
  'sync_records': ChangeLogClass.excluded,
  'trip_day_weather': ChangeLogClass.excluded,
  'view_configs': ChangeLogClass.excluded,
};

/// The record a child row belongs to in the feed.
class ChangeLogParent {
  const ChangeLogParent({required this.rootTable, required this.column});

  final String rootTable;

  /// The column on the child that holds the parent's id. A row where it is
  /// null is its own root.
  final String column;
}

/// Child tables and their parents. Walk until a table has no entry to reach
/// the root. A table with a `diver_id` of its own and no entry here is a root.
const Map<String, ChangeLogParent> changeLogParents = {
  'certification_currency_events': ChangeLogParent(
    rootTable: 'certifications',
    column: 'certification_id',
  ),
  'certification_currency_prefs': ChangeLogParent(
    rootTable: 'certifications',
    column: 'certification_id',
  ),
  'checklist_template_items': ChangeLogParent(
    rootTable: 'checklist_templates',
    column: 'template_id',
  ),
  'checklist_template_sections': ChangeLogParent(
    rootTable: 'checklist_templates',
    column: 'template_id',
  ),
  'course_requirement_dives': ChangeLogParent(
    rootTable: 'course_requirements',
    column: 'requirement_id',
  ),
  'course_requirements': ChangeLogParent(
    rootTable: 'courses',
    column: 'course_id',
  ),
  'custom_certification_levels': ChangeLogParent(
    rootTable: 'custom_certification_agencies',
    column: 'agency_id',
  ),
  'cylinder_config_items': ChangeLogParent(
    rootTable: 'cylinder_configs',
    column: 'config_id',
  ),
  'cylinder_fills': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'dive_buddies': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_buddy_roles': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_center_gear_notes': ChangeLogParent(
    rootTable: 'dive_centers',
    column: 'dive_center_id',
  ),
  'dive_computer_connections': ChangeLogParent(
    rootTable: 'dive_computers',
    column: 'computer_id',
  ),
  'dive_courses': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_custom_fields': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_data_sources': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_dive_types': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_diver_roles': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_equipment': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_plan_equipment': ChangeLogParent(
    rootTable: 'dive_plans',
    column: 'plan_id',
  ),
  'dive_plan_mission_legs': ChangeLogParent(
    rootTable: 'dive_plans',
    column: 'plan_id',
  ),
  'dive_plan_mission_members': ChangeLogParent(
    rootTable: 'dive_plans',
    column: 'plan_id',
  ),
  'dive_plan_missions': ChangeLogParent(
    rootTable: 'dive_plans',
    column: 'plan_id',
  ),
  'dive_plan_segments': ChangeLogParent(
    rootTable: 'dive_plans',
    column: 'plan_id',
  ),
  'dive_plan_tanks': ChangeLogParent(
    rootTable: 'dive_plans',
    column: 'plan_id',
  ),
  'dive_profile_events': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_profile_series': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_profile_series_history': ChangeLogParent(
    rootTable: 'dives',
    column: 'dive_id',
  ),
  'dive_safety_findings': ChangeLogParent(
    rootTable: 'dives',
    column: 'dive_id',
  ),
  'dive_safety_reviews': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_scenarios': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_tags': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_tanks': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'dive_weights': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'document_pages': ChangeLogParent(
    rootTable: 'documents',
    column: 'document_id',
  ),
  'document_tags': ChangeLogParent(
    rootTable: 'documents',
    column: 'document_id',
  ),
  'equipment_attributes': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'equipment_components': ChangeLogParent(
    rootTable: 'equipment',
    column: 'parent_equipment_id',
  ),
  'equipment_location_moves': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'equipment_observations': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'equipment_ownership_events': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'equipment_set_geofences': ChangeLogParent(
    rootTable: 'equipment_sets',
    column: 'set_id',
  ),
  'equipment_set_items': ChangeLogParent(
    rootTable: 'equipment_sets',
    column: 'set_id',
  ),
  'equipment_shares': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'equipment_tags': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'gas_switches': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'library_site_notes': ChangeLogParent(
    rootTable: 'dive_sites',
    column: 'site_id',
  ),
  'liveaboard_detail_records': ChangeLogParent(
    rootTable: 'trips',
    column: 'trip_id',
  ),
  'media': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'media_enrichment': ChangeLogParent(rootTable: 'media', column: 'media_id'),
  'media_people': ChangeLogParent(rootTable: 'media', column: 'media_id'),
  'media_species': ChangeLogParent(rootTable: 'media', column: 'media_id'),
  'media_tags': ChangeLogParent(rootTable: 'media', column: 'media_id'),
  'pre_dive_checklist_template_items': ChangeLogParent(
    rootTable: 'pre_dive_checklist_templates',
    column: 'template_id',
  ),
  'pre_dive_checklist_template_sections': ChangeLogParent(
    rootTable: 'pre_dive_checklist_templates',
    column: 'template_id',
  ),
  'pre_dive_session_items': ChangeLogParent(
    rootTable: 'pre_dive_sessions',
    column: 'session_id',
  ),
  'pre_dive_session_sections': ChangeLogParent(
    rootTable: 'pre_dive_sessions',
    column: 'session_id',
  ),
  'service_records': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'service_schedules': ChangeLogParent(
    rootTable: 'equipment',
    column: 'equipment_id',
  ),
  'sightings': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'site_features': ChangeLogParent(rootTable: 'dive_sites', column: 'site_id'),
  'site_hides': ChangeLogParent(rootTable: 'dive_sites', column: 'site_id'),
  'site_shares': ChangeLogParent(rootTable: 'dive_sites', column: 'site_id'),
  'site_site_types': ChangeLogParent(
    rootTable: 'dive_sites',
    column: 'site_id',
  ),
  'site_species': ChangeLogParent(rootTable: 'dive_sites', column: 'site_id'),
  'site_tags': ChangeLogParent(rootTable: 'dive_sites', column: 'site_id'),
  'tank_pressure_series': ChangeLogParent(
    rootTable: 'dives',
    column: 'dive_id',
  ),
  'tide_records': ChangeLogParent(rootTable: 'dives', column: 'dive_id'),
  'trip_checklist_items': ChangeLogParent(
    rootTable: 'trip_checklists',
    column: 'checklist_id',
  ),
  'trip_checklist_sections': ChangeLogParent(
    rootTable: 'trip_checklists',
    column: 'checklist_id',
  ),
  'trip_checklists': ChangeLogParent(rootTable: 'trips', column: 'trip_id'),
  'trip_cylinder_events': ChangeLogParent(
    rootTable: 'trip_cylinders',
    column: 'trip_cylinder_id',
  ),
  'trip_cylinders': ChangeLogParent(rootTable: 'trips', column: 'trip_id'),
  'trip_equipment': ChangeLogParent(rootTable: 'trips', column: 'trip_id'),
  'trip_hides': ChangeLogParent(rootTable: 'trips', column: 'trip_id'),
  'trip_itinerary_days': ChangeLogParent(rootTable: 'trips', column: 'trip_id'),
  'trip_shares': ChangeLogParent(rootTable: 'trips', column: 'trip_id'),
  'weight_preset_entries': ChangeLogParent(
    rootTable: 'weight_presets',
    column: 'preset_id',
  ),
};

/// Sync bookkeeping, as SQL names. A test pins this to the conflict
/// catalogue's list, less `id`, which lives in a presentation file this
/// library may not import.
const Set<String> changeLogBookkeepingColumns = {
  'hlc',
  'device_id',
  'origin_device_id',
  'synced_at',
  'created_at',
  'updated_at',
};

/// Never written to the log, not even in a delete copy.
const Set<String> changeLogCredentialColumns = {
  'signing_private_key',
  'library_key',
  'spare_key',
  'credentials_ref',
  'credentials_host_id',
  'instance_token',
};

/// Device stamps that move without the diver doing anything, beyond the
/// groups [changeLogIgnoredColumns] already covers.
const Map<String, Set<String>> _ignoredStamps = {
  'dive_computers': {'last_dive_fingerprint', 'last_download_timestamp'},
  'dive_computer_connections': {'last_used_at'},
  'dive_data_sources': {'last_parsed_at'},
  'media_stores': {'last_sweep_at'},
};

/// The columns an update does not record: bookkeeping, credentials, the fact
/// groups' columns and clocks, device-local columns and device stamps. A
/// diver's list arrangement is a fact group too: sorting is one of the most
/// frequent taps in the app, and an entry per sort would bury real edits.
Set<String> changeLogIgnoredColumns(String table) {
  final entity = columnJsonKey(table);
  return {
    ...changeLogBookkeepingColumns,
    ...changeLogCredentialColumns,
    ...?_ignoredStamps[table],
    for (final group in SyncFactGroups.of(entity)) ...{
      group.clockColumn,
      ...group.columns.values,
    },
    for (final key in deviceLocalSyncColumns[entity] ?? const <String>{})
      changeLogSqlName(key),
  };
}

/// Whether a delete copy leaves [column] out. A clock is never restored, and
/// a credential is never logged.
bool changeLogDeleteCopySkips(String column) =>
    column == 'hlc' ||
    column.endsWith('_hlc') ||
    changeLogCredentialColumns.contains(column);

/// Keys of the `settings` table that record how a list was left, for the
/// same reason [changeLogIgnoredColumns] leaves out a diver's list
/// arrangement.
const Set<String> _displaySettingsKeys = {
  'media_library_view_mode',
  'media_library_sort',
  'equipment_arrangement',
};

/// Logged tables that never sync, so a restored row has no tombstone to clear
/// and no pending mark to take.
const Set<String> changeLogDeviceLocalTables = {'dive_profile_series_history'};

/// Machine tables whose row belongs to another row besides its root, by
/// column and that row's table. Such a row's delete copy is kept when that
/// row has gone, even with the root alive: reverting a deleted tank must
/// bring its pressure curve back.
const Map<String, Map<String, String>> changeLogMachineOwners = {
  'tank_pressure_series': {
    'tank_id': 'dive_tanks',
    'source_id': 'dive_data_sources',
  },
  'dive_profile_series': {'source_id': 'dive_data_sources'},
  'media_enrichment': {'media_id': 'media'},
};

/// An extra trigger guard for tables where some rows are not user data, or
/// null. [prefix] is `OLD` or `NEW`.
String? changeLogRowGuard(String table, String prefix) {
  if (table != 'settings') return null;
  final keys = ({
    ...deviceLocalSettingsKeys,
    ..._displaySettingsKeys,
  }.toList()..sort()).map((key) => "'$key'").join(', ');
  return '$prefix."key" NOT IN ($keys)';
}

/// The SQL name of a JSON key, the inverse of [columnJsonKey].
String changeLogSqlName(String jsonKey) => jsonKey.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '_${match[0]!.toLowerCase()}',
);
