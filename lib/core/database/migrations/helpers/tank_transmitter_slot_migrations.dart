part of '../app_database_migrations.dart';

/// The physical transmitter slot of a tank (issue #4347).
extension TankTransmitterSlotMigrations on AppDatabase {
  /// Idempotent DDL for the v351 `dive_tanks.transmitter_slot` column. No
  /// backfill: the app fills it at runtime from stored raw bytes and import
  /// files. Skipped on a fixture without the table. Called from the v351 rung
  /// and re-asserted in beforeOpen, since every tank read selects the whole
  /// row.
  Future<void> _assertTankTransmitterSlotColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_tanks')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('transmitter_slot')) return;
    await customStatement(
      'ALTER TABLE dive_tanks ADD COLUMN transmitter_slot INTEGER',
    );
  }

  /// Test hook: re-assert the v351 column on demand so tests can prove the
  /// backstop is idempotent.
  Future<void> assertTankTransmitterSlotColumnForTest() =>
      _assertTankTransmitterSlotColumn();
}
