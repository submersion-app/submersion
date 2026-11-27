part of '../app_database_migrations.dart';

/// Gear items linked to photos and videos (issue #5046).
extension MediaEquipmentMigrations on AppDatabase {
  /// v388: the media_equipment table and its equipment lookup index. The
  /// unique (media_id, equipment_id) pair is part of the table. Idempotent;
  /// a partial fixture without either parent is left alone.
  Future<void> _assertMediaEquipmentSchema() async {
    if (!await _tableExists('media')) return;
    if (!await _tableExists('equipment')) return;
    if (!await _tableExists('media_equipment')) {
      await Migrator(this).createTable(mediaEquipment);
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_equipment_equipment '
      'ON media_equipment (equipment_id)',
    );
  }
}
