part of '../app_database_migrations.dart';

/// Gear photos (issue #3355).
extension EquipmentPhotoMigrations on AppDatabase {
  /// v352: media.observation_id, the check-in a gear photo backs up, and
  /// equipment.cover_media_id, the photo that stands for an item. Plain
  /// nullable TEXT with no foreign key and no backfill. Idempotent; called
  /// from the v352 onUpgrade step and the beforeOpen backstop.
  Future<void> _assertEquipmentPhotoColumns() async {
    if (await _tableExists('media')) {
      await _addColumnIfMissing('media', 'observation_id', 'TEXT');
    }
    if (await _tableExists('equipment')) {
      await _addColumnIfMissing('equipment', 'cover_media_id', 'TEXT');
    }
  }
}
