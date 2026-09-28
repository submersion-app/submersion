import 'package:uuid/uuid.dart';

import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// Fixed namespace for the ids of passport copies of trip fills (UUID v5 of
/// the trip event id). Never change: stored copies are found by it.
const String kTripFillPassportNamespace =
    '6b2f0c4e-8d1a-4f7e-9c35-2a7e5d913b08';

/// The id of the passport copy of trip event [tripEventId]. Derived, so
/// every device agrees on it and an edit or delete finds the copy.
String tripFillPassportCopyId(String tripEventId) =>
    const Uuid().v5(kTripFillPassportNamespace, tripEventId);

/// Pure. The passport record for a trip fill: the analysed mix when there
/// is one, else the ordered mix, else air; the fill time as the diver's
/// local wall clock, which is how passport fills store it (trip events keep
/// the wall clock stamped UTC).
CylinderFill passportCopyOf(
  TripCylinderEvent fill, {
  required String passportId,
  required String equipmentId,
  String? diverId,
  String? stationName,
}) {
  final analysed = fill.analyzedO2 != null;
  final at = fill.occurredAt;
  return CylinderFill(
    id: tripFillPassportCopyId(fill.id),
    diverId: diverId,
    passportId: passportId,
    equipmentId: equipmentId,
    filledAt: DateTime(
      at.year,
      at.month,
      at.day,
      at.hour,
      at.minute,
      at.second,
    ),
    o2Percent: fill.analyzedO2 ?? fill.o2Percent ?? 21.0,
    hePercent: analysed ? (fill.analyzedHe ?? 0.0) : (fill.hePercent ?? 0.0),
    pressureBar: fill.pressure,
    stationName: stationName,
    source: FillSource.manual,
    notes: fill.note,
    createdAt: fill.createdAt,
    updatedAt: fill.updatedAt,
  );
}

/// Keeps a passport copy of each trip fill on one of the diver's own
/// cylinders. Fill edits and fill deletes follow; slot and trip deletes keep
/// the copy, because the cylinder really was filled (decision 2026-09-26).
class TripFillPassportCopier {
  TripFillPassportCopier({
    CylinderFillRepository? fills,
    CylinderPassportRepository? passports,
  }) : _fills = fills ?? CylinderFillRepository(),
       _passports = passports ?? CylinderPassportRepository();

  final CylinderFillRepository _fills;
  final CylinderPassportRepository _passports;

  /// After a trip event on [slot] is saved: writes or updates the copy of a
  /// fill on an owned cylinder. An adjustment never has one; an event that
  /// was a fill and no longer is loses its copy. Pass [stationResolved]
  /// false when the station list could not be read: an existing copy then
  /// keeps its station name rather than losing it to a failed lookup.
  Future<void> afterSave(
    TripCylinderEvent event,
    TripCylinder slot, {
    String? diverId,
    String? stationName,
    bool stationResolved = true,
  }) async {
    final copyId = tripFillPassportCopyId(event.id);
    if (event.kind != TripCylinderEventKind.fill) {
      if (await _fills.getById(copyId) != null) await _fills.delete(copyId);
      return;
    }
    // A fill on a rental slot has no copy to write or keep up to date, so
    // it never needs the lookup.
    final equipmentId = slot.equipmentId;
    if (equipmentId == null) return;
    final existing = await _fills.getById(copyId);
    final passportId = await _passports.ensurePassportId(
      equipmentId,
      diverId: diverId,
    );
    final copy = passportCopyOf(
      event,
      passportId: passportId,
      equipmentId: equipmentId,
      diverId: diverId,
      stationName: stationResolved ? stationName : existing?.stationName,
    );
    if (existing == null) {
      await _fills.create(copy);
    } else {
      await _fills.update(copy.copyWith(createdAt: existing.createdAt));
    }
  }

  /// After a trip fill is deleted on its own (not with its slot or trip):
  /// the copy goes too.
  Future<void> afterDelete(String tripEventId) async {
    final copyId = tripFillPassportCopyId(tripEventId);
    if (await _fills.getById(copyId) != null) await _fills.delete(copyId);
  }
}
