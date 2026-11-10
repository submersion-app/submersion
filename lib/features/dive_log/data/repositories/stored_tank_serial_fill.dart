import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// [matches] (from `matchStoredTanks`) corrected by start pressure for the
/// cylinders a file import wrote: no computer and no source index, so only
/// their order paired them. A UDDF import before #4363 stored every such
/// cylinder at order 0, so a re-download paired only its first reading, and
/// with whichever cylinder sorted first, and added the rest as new cylinders
/// (issue #4388).
///
/// A reading whose order pairing disagrees on start pressure, or that has no
/// pairing, takes the one free file-imported cylinder within tolerance of its
/// start pressure, when no other such reading is within tolerance of that
/// cylinder. A pairing this cannot improve is kept as it was, so a cylinder
/// with no pressure on either side behaves as before.
Map<int, DiveTank> pairFileTanksByPressure(
  Map<int, DiveTank> matches,
  List<DiveTank> stored,
  List<({int index, double? startPressure})> readings,
) {
  bool fileTank(DiveTank r) =>
      r.computerId == null && r.sourceTankIndex == null;
  final pressureOf = {for (final r in readings) r.index: r.startPressure};
  bool agrees(DiveTank row, double? reading) {
    final stored = row.startPressure;
    if (stored == null || reading == null) return true;
    return sameCylinderStartPressure(stored, reading);
  }

  final result = <int, DiveTank>{
    for (final MapEntry(key: index, value: row) in matches.entries)
      if (!fileTank(row) || agrees(row, pressureOf[index])) index: row,
  };
  final taken = {for (final row in result.values) row.id};
  final pending = [
    for (final r in readings)
      if (!result.containsKey(r.index) && r.startPressure != null) r,
  ];
  final free = [
    for (final row in stored)
      if (fileTank(row) && row.startPressure != null && !taken.contains(row.id))
        row,
  ];
  for (final reading in pending) {
    final near = [
      for (final row in free)
        if (!taken.contains(row.id) &&
            sameCylinderStartPressure(
              row.startPressure!,
              reading.startPressure!,
            ))
          row,
    ];
    if (near.length != 1) continue;
    final row = near.single;
    final rivals = pending.where(
      (r) => sameCylinderStartPressure(row.startPressure!, r.startPressure!),
    );
    if (rivals.length != 1) continue;
    result[reading.index] = row;
    taken.add(row.id);
  }
  // A disagreeing pairing nothing better replaced stays, as before.
  for (final MapEntry(key: index, value: row) in matches.entries) {
    if (result.containsKey(index) || taken.contains(row.id)) continue;
    result[index] = row;
    taken.add(row.id);
  }
  return result;
}

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
