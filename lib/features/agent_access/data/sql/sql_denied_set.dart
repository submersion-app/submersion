/// What the SQL window may not read.
///
/// A table the change log policy classes as excluded must appear in exactly
/// one of the two sets here, and `sql_denied_set_test.dart` fails when a new
/// one does not, so nobody adds a machine table and exposes it by accident. A
/// table the policy has never heard of is refused outright.
library;

import 'package:submersion/core/database/change_log/change_log_policy.dart';

/// Credentials, keys, sync bookkeeping, local publish and subscription state,
/// the change log, and machine state with no bearing on a diver's question.
const Set<String> kSqlDeniedTables = {
  'cached_regions',
  'change_log_context',
  'change_log_events',
  'change_log_fields',
  'change_log_operations',
  'connected_accounts',
  'deletion_log',
  'local_publish_states',
  'media_fetch_diagnostics',
  'media_repair_log',
  'media_subscription_state',
  'nearby_peers',
  'network_credential_hosts',
  'pending_photo_suggestions',
  'scheduled_notifications',
  'shared_libraries',
  'shared_library_backups',
  'shared_library_members',
  'shared_library_memberships',
  'shared_site_states',
  'shared_site_suggestions',
  'sync_metadata',
  'sync_peer_cursors',
  'sync_records',
  'view_configs',
};

/// Tables outside the change log that hold what statistics are made of.
const Set<String> kSqlReadableExcludedTables = {
  'dive_derived_metrics',
  'dive_sensor_summaries',
  'equipment_condition_reviews',
  'equipment_findings',
  'equipment_service_status',
  'gps_track_points_local',
  'quality_findings',
  'rule_run_changes',
  'rule_runs',
  'trip_day_weather',
};

/// Columns refused on any table that is otherwise readable: the credentials
/// the change log never records, and the URLs of a private feed and of the
/// items in it, which can carry an access token in the query string. Those
/// stay out of [changeLogCredentialColumns] because the log still records
/// edits to them.
const Set<String> kSqlDeniedColumns = {
  ...changeLogCredentialColumns,
  'manifest_url',
  'url',
};

/// Matches [name] as a whole identifier, so `url` never matches `base64url`.
RegExp sqlNamePattern(String name) => RegExp('\\b${RegExp.escape(name)}\\b');

/// Whether [sql] names a denied column, in any case and however it is quoted.
bool sqlNamesDeniedColumn(String sql) {
  final lower = sql.toLowerCase();
  return kSqlDeniedColumns.any(
    (column) => sqlNamePattern(column).hasMatch(lower),
  );
}

/// SQLite's own catalogue: structure, never data.
const String kSqlSchemaTable = 'sqlite_schema';

/// Whether the SQL window may read [table]. An unknown table is not readable.
bool sqlTableReadable(String table) {
  if (table == kSqlSchemaTable) return true;
  if (kSqlDeniedTables.contains(table)) return false;
  return changeLogTables.containsKey(table);
}
