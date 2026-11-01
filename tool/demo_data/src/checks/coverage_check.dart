import 'package:submersion/core/database/database.dart';

/// Tables the demo logbook leaves empty on purpose, each with the reason.
///
/// Every other table must have rows, so that every part of the app shows
/// something in demo mode (issue #3708). A table added to the schema fails
/// the coverage test until a seeder fills it or this list explains why not.
const demoCoverageExclusions = <String, String>{
  // Sync bookkeeping: demo mode never syncs.
  'deletion_log': 'sync bookkeeping; demo mode never syncs',
  'sync_metadata': 'sync bookkeeping; demo mode never syncs',
  'sync_peer_cursors': 'sync bookkeeping; demo mode never syncs',
  'sync_records': 'sync bookkeeping; demo mode never syncs',
  'local_publish_states': 'sync bookkeeping; demo mode never syncs',
  'nearby_peers': 'devices paired with this one; nearby sync is sealed',
  // Club shared site libraries: sealed in demo mode.
  'shared_libraries': 'shared site libraries are sealed in demo mode',
  'shared_library_backups': 'shared site libraries are sealed in demo mode',
  'shared_library_members': 'shared site libraries are sealed in demo mode',
  'shared_library_memberships': 'shared site libraries are sealed in demo mode',
  'shared_site_states': 'shared site libraries are sealed in demo mode',
  'shared_site_suggestions': 'shared site libraries are sealed in demo mode',
  'library_site_notes': 'shared site libraries are sealed in demo mode',
  // Accounts and remote stores: sealed in demo mode, and personal.
  'connected_accounts': 'accounts are sealed in demo mode',
  'media_stores': 'media stores are sealed in demo mode',
  'media_subscriptions': 'remote photo services are sealed in demo mode',
  'media_subscription_state': 'remote photo services are sealed in demo mode',
  'network_credential_hosts': 'credentials are never part of sample data',
  // Device-local state the app writes as it runs.
  'scheduled_notifications': 'device reminders; the preparer clears them',
  'cached_regions': 'offline map cache of this device',
  'gps_track_points_local': 'device-local recording buffer',
  'media_fetch_diagnostics': 'device diagnostics',
  'media_repair_log': 'device repair history',
  'imported_files': 'import history; imports are sealed in demo mode',
  'csv_presets': 'import presets; imports are sealed in demo mode',
  'pending_photo_suggestions':
      'found by scanning this device\'s photo library; sealed in demo mode',
  // Computed by the app as it runs.
  'equipment_service_status': 'a local cache the app rebuilds from the gear',
  'dive_safety_reviews': 'computed by the app when a dive is opened',
  'dive_safety_findings': 'computed by the app when a dive is opened',
};

class CoverageCheck {
  CoverageCheck._();

  /// Tables in [db] with no rows that [demoCoverageExclusions] does not
  /// explain.
  static Future<List<String>> emptyTables(AppDatabase db) async {
    final empty = <String>[];
    for (final t in db.allTables) {
      final name = t.actualTableName;
      if (demoCoverageExclusions.containsKey(name)) continue;
      final row = await db
          .customSelect('SELECT EXISTS (SELECT 1 FROM "$name") AS filled')
          .getSingle();
      if (row.read<int>('filled') == 0) empty.add(name);
    }
    return empty..sort();
  }
}
