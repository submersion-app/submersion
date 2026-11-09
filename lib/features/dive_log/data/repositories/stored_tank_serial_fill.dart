import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// How far apart, in bar, a stored cylinder's start pressure and a fresh
/// reading's may be and still be one cylinder. Readings of one log differ
/// only by unit rounding, a fraction of a bar.
const double _pressureToleranceBar = 1.0;

/// The serial a stored cylinder [row] should take from [readingSerial], the
/// transmitter a fresh download of the same computer reports for the tank
/// paired with it, or null to leave it (issue #4347).
///
/// Only a cylinder with no serial takes one, and only when both start
/// pressures are known and agree: the pairing is by index, and a file
/// import's index need not be the computer's, so the pressure confirms
/// that the two describe one cylinder before it takes another's setup.
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
  if ((stored - readingStartPressure).abs() > _pressureToleranceBar) {
    return null;
  }
  return serial;
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
