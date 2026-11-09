import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// Gives target tank [targetTankId] the transmitter serial of [merged], the
/// secondary's tank a consolidation folds into it, when the target has none
/// (issue #4388): a file import that knew the cylinder but not its
/// transmitter. A serial the target has is never replaced. Only when the
/// pairing rests on more than chance: a mix that more than one cylinder on
/// either dive breathes was paired by order, and a wrong serial would carry
/// another cylinder's setup. [tankRows] are every folded dive's cylinders as
/// they stood before the fold.
Future<void> fillMergedTankSerial(
  AppDatabase db,
  SyncRepository sync, {
  required DiveTank merged,
  required String targetTankId,
  required List<DiveTank> tankRows,
  required int now,
}) async {
  final serial = normalizeTransmitterSerial(merged.transmitterSerial);
  if (serial == null) return;
  final target = tankRows.where((r) => r.id == targetTankId).firstOrNull;
  if (target == null) return;
  bool sameMix(DiveTank a, DiveTank b) =>
      a.o2Percent == b.o2Percent && a.hePercent == b.hePercent;
  int onDive(DiveTank tank) =>
      tankRows.where((r) => r.diveId == tank.diveId && sameMix(r, tank)).length;
  if (onDive(target) != 1 || onDive(merged) != 1) return;
  // Read now, not from [tankRows]: an earlier secondary in this fold may
  // have filled it already.
  final current = await (db.select(
    db.diveTanks,
  )..where((t) => t.id.equals(targetTankId))).getSingleOrNull();
  if (current == null ||
      normalizeTransmitterSerial(current.transmitterSerial) != null) {
    return;
  }
  await (db.update(db.diveTanks)..where((t) => t.id.equals(targetTankId)))
      .write(DiveTanksCompanion(transmitterSerial: Value(serial)));
  await sync.markRecordPending(
    entityType: 'diveTanks',
    recordId: targetTankId,
    localUpdatedAt: now,
  );
}
