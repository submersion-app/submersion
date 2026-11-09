import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// The serial a stored cylinder [row] should take from [readingSerial], the
/// transmitter a fresh reading (a re-download, or a resync of its file)
/// reports for the tank paired with it, or null to leave it (issue #4388).
///
/// Only a cylinder with no serial takes one, and only when both start
/// pressures are known and agree: the pairing is by index or position, and
/// a file import's index need not be the computer's, nor its position the
/// file's once the diver has added or removed a cylinder, so the pressure
/// confirms that the two describe one cylinder before it takes another's
/// setup.
String? serialToFill(
  DiveTank row, {
  required String? readingSerial,
  required double? readingStartPressure,
}) {
  final serial = normalizeTransmitterSerial(readingSerial);
  if (serial == null) return null;
  if (normalizeTransmitterSerial(row.transmitterSerial) != null) return null;
  final stored = row.startPressure;
  if (stored == null || readingStartPressure == null) return null;
  return sameCylinderStartPressure(stored, readingStartPressure)
      ? serial
      : null;
}

/// Writes [serial] onto stored cylinder [tankId] and stages it for sync.
Future<void> writeStoredTankSerial(
  AppDatabase db,
  SyncRepository sync,
  String tankId,
  String serial, {
  required int now,
}) async {
  await (db.update(db.diveTanks)..where((t) => t.id.equals(tankId))).write(
    DiveTanksCompanion(transmitterSerial: Value(serial)),
  );
  await sync.markRecordPending(
    entityType: 'diveTanks',
    recordId: tankId,
    localUpdatedAt: now,
  );
}
