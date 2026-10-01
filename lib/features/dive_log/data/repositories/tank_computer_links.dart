import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// Nulls `computer_id` on every tank [where] selects and stages those tanks,
/// the way clearCylinderGearLinks does for gear. Returns the number cleared.
///
/// Call it before deleting the computers the tanks name. The schema's ON
/// DELETE SET NULL would clear them too, but that write moves no clock: no
/// peer learns of it, and the device-local caches keyed on
/// `diveSourceStampSql`, which counts each tank through its clock, keep a
/// sensor summary attributed to the deleted computer. Staging a tank stamps
/// a new clock on it. The parent dive is deliberately NOT staged (#1769):
/// re-stamping it would let this device's whole dive row overwrite a newer
/// edit to that dive made on another device.
Future<int> clearTankComputerLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Expression<bool> Function($DiveTanksTable t) where, {
  required int now,
}) async {
  final ids =
      await (db.selectOnly(db.diveTanks)
            ..addColumns([db.diveTanks.id])
            ..where(where(db.diveTanks)))
          .map((r) => r.read(db.diveTanks.id)!)
          .get();
  if (ids.isEmpty) return 0;
  await (db.update(db.diveTanks)..where(where)).write(
    DiveTanksCompanion(
      computerId: const Value(null),
      // Its own clock, beside the marks below (#2644).
      hlc: Value(await syncRepository.issueRowClock()),
    ),
  );
  for (final id in ids) {
    await syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  return ids.length;
}
