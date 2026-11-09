import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// Gives target tank [targetTankId] the transmitter serial of [merged], the
/// secondary's tank a consolidation folds into it, when the target has none
/// (issue #4388): a file import that knew the cylinder but not its
/// transmitter. A serial the target has is never replaced.
///
/// Only when the pairing rests on more than chance, since a wrong serial
/// would carry another cylinder's setup: either the mix (within the fold's
/// own gas tolerance) is on no other cylinder of either dive, or both start
/// pressures are known, agree, and single out this pair among the cylinders
/// on that mix, as a sidemount pair filled to different pressures does.
/// [tankRows] are every folded dive's cylinders as they stood before the
/// fold.
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
  if (!_pairIsCertain(target, merged, tankRows)) return;
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

bool _pairIsCertain(DiveTank target, DiveTank merged, List<DiveTank> rows) {
  const tolerance = DiveConsolidationBuilder.gasTolerancePct;
  bool sameMix(DiveTank a, DiveTank b) =>
      (a.o2Percent - b.o2Percent).abs() <= tolerance &&
      (a.hePercent - b.hePercent).abs() <= tolerance;
  List<DiveTank> mixMates(DiveTank of, DiveTank like) => [
    for (final r in rows)
      if (r.diveId == of.diveId && sameMix(r, like)) r,
  ];
  final targetMates = mixMates(target, merged);
  final mergedMates = mixMates(merged, target);
  if (targetMates.length == 1 && mergedMates.length == 1) return true;

  final targetStart = target.startPressure;
  final mergedStart = merged.startPressure;
  if (targetStart == null || mergedStart == null) return false;
  if (!sameCylinderStartPressure(targetStart, mergedStart)) return false;
  bool near(DiveTank r, double bar) =>
      r.startPressure != null &&
      sameCylinderStartPressure(r.startPressure!, bar);
  return targetMates.where((r) => near(r, mergedStart)).length == 1 &&
      mergedMates.where((r) => near(r, targetStart)).length == 1;
}
