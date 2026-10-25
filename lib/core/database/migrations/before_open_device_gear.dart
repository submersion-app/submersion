part of 'app_database_migrations.dart';

/// The open-time heal for one Equipment entry per device (issue #3676), split
/// out of before_open.dart to keep it under the migration file size limit.
extension BeforeOpenDeviceGear on AppDatabase {
  /// Gives every dive computer and transmitter row its Equipment item. Safe
  /// on every open, unlike the v175 backfill it supersedes for this job:
  /// deleting an item now deletes its device too, so a device without one
  /// only arises from an older peer's delete or a sync, and must get one back.
  /// AFTER the #1288 pass, so a computer it just registered is covered.
  /// Local-only, deterministic ids, no HLC bump.
  Future<void> _healDeviceGear() async {
    await ensureDeviceGearLinks(this);
  }
}
