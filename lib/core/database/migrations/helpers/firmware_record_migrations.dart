part of '../app_database_migrations.dart';

/// The version a firmware update installed (v395, issue #5104).
extension FirmwareRecordMigrations on AppDatabase {
  /// `service_records.firmware_version` (TEXT, nullable). No backfill: every
  /// existing record is a service, not a firmware update. Safe from both the
  /// v395 rung and the beforeOpen backstop.
  Future<void> _assertFirmwareRecordColumn() async {
    await _addColumnIfMissing('service_records', 'firmware_version', 'TEXT');
  }
}
