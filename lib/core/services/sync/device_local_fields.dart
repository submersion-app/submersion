import 'package:submersion/core/services/sync/child_column_clears.dart';

/// Columns a synced row never carries, by entity type and wire (JSON) key,
/// because their value belongs to one device rather than to the library.
///
/// Export strips them, import refills them from this device, and a save that
/// changes only these columns stamps no sync clock (issue #2947).
const Map<String, Set<String>> deviceLocalSyncColumns = {
  // A host's BLE identifier for a computer; another host's never applies.
  'diveComputers': {'bluetoothAddress'},
  // Reminders follow the OS notification permission, which is per device,
  // and the theme mode follows where the device is used.
  'diverSettings': {
    'notificationsEnabled',
    'serviceReminderDays',
    'reminderTime',
    'tripServiceLeadDays',
    'themeMode',
  },
};

/// Keys of the key/value `settings` table that stay on this device: export
/// filters them, import skips them, and a replace-adopt keeps them.
///
/// Audit (last reviewed for issues #2949 and #2947): every other key written
/// to the `settings` table syncs. Today those are
/// `share_new_records_by_default`, `gas_blender_prefs`,
/// `equipment_arrangement`, `gas_mod_calculator_prefs`,
/// `media_upload_quality_photo`, `media_upload_quality_video`,
/// `media_library_view_mode`, `media_library_sort` and
/// `media_watcher_auto_apply`, plus two keys per connected Lightroom account,
/// `lightroom_<account>_album_ids` and `lightroom_<account>_auto_poll`
/// (written by `LightroomConnectorState`).
///
/// Rule for a new key: "is this answer the same across all of one user's
/// devices?" If not, add it here. Either way, update the "What Syncs Between
/// Devices" section of docs/guide/multi-device-sync.md.
const Set<String> deviceLocalSettingsKeys = {
  // Each device auto-creates its own owner diver at first launch.
  'active_diver_id',
  // The nav layout depends on the screen it is shown on (issue #2947).
  'nav_primary_ids',
  'nav_rail_ids',
  'nav_always_hide_labels',
};

/// Whether the synced record [recordId] of [entityType] is a device-local
/// settings key ([deviceLocalSettingsKeys]): a peer's live copy or tombstone
/// of one never applies here.
bool isDeviceLocalRecord(String entityType, String recordId) =>
    entityType == 'settings' && deviceLocalSettingsKeys.contains(recordId);

/// Whether the SQL column [sqlName] of [entityType]'s table is device-local.
bool isDeviceLocalColumn(String entityType, String sqlName) =>
    deviceLocalSyncColumns[entityType]?.contains(columnJsonKey(sqlName)) ??
    false;

/// [data] without the device-local keys of [entityType]; [data] itself when
/// it carries none.
Map<String, dynamic> withoutDeviceLocalColumns(
  String entityType,
  Map<String, dynamic> data,
) {
  final keys = deviceLocalSyncColumns[entityType];
  if (keys == null || !keys.any(data.containsKey)) return data;
  return {
    for (final entry in data.entries)
      if (!keys.contains(entry.key)) entry.key: entry.value,
  };
}
