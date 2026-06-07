import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

int _deviceCounter = 0;

/// Make the current in-memory DB look like a DIFFERENT device that shares the
/// same cloud: assign a fresh `device_id` and reset sync state (clears pending/
/// conflict records, the deletion log, and lastSync).
///
/// Round-trip tests use this to model genuine cross-device sync. Under
/// per-device sync files each device writes `submersion_sync_<deviceId>.json`
/// and skips its OWN file on read, so "device B" must have a distinct deviceId
/// from "device A" for A's file to be seen as foreign and applied.
Future<void> impersonateFreshDevice() async {
  final repo = SyncRepository();
  // Ensure the metadata row exists before we update it.
  await repo.getDeviceId();
  _deviceCounter++;
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "UPDATE sync_metadata SET device_id = ? WHERE id = 'global'",
    ['test-device-$_deviceCounter'],
  );
  await repo.resetSyncState();
}

/// Force a non-null last-sync timestamp on the current device. Conflict
/// detection in `_mergeEntity` only engages when `lastSync != null`, so tests
/// that exercise the concurrent-edit / conflict path must set this after
/// seeding but before the conflicting pull.
Future<void> setLastSync(DateTime time) async {
  await SyncRepository().updateLastSyncTime(time);
}
