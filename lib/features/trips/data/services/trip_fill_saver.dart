import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// Writes the fills of one fill sheet. Keep one per open sheet: it
/// remembers what its earlier attempts stored, so after a failure Save
/// again updates those fills instead of adding a second one to a slot, and
/// a slot the diver has unchecked since loses the fill an attempt wrote.
class TripFillSaver {
  TripFillSaver({
    required TripCylinderRepository repository,
    required TripFillPassportCopier copier,
  }) : _repository = repository,
       _copier = copier;

  final TripCylinderRepository _repository;
  final TripFillPassportCopier _copier;

  /// Fills stored by earlier calls, by slot id.
  Map<String, TripCylinderEvent> _written = const {};

  /// Writes one new fill per slot in [drafts] (their ids are ignored) and
  /// returns the stored fills in [drafts] order. Slots stored by an earlier
  /// call are updated; the rest are created together in one transaction;
  /// slots stored earlier but absent now lose that fill and its copy.
  Future<List<TripCylinderEvent>> writeFills(
    List<TripCylinderEvent> drafts,
  ) async {
    final slotIds = {for (final d in drafts) d.tripCylinderId};
    for (final gone in [
      for (final w in _written.values)
        if (!slotIds.contains(w.tripCylinderId)) w,
    ]) {
      await _repository.deleteEvent(
        gone.id,
        alongside: () => _copier.afterDelete(gone.id),
      );
      _written = {
        for (final w in _written.entries)
          if (w.key != gone.tripCylinderId) w.key: w.value,
      };
    }

    final candidates = [
      for (final d in drafts)
        if (_written[d.tripCylinderId] case final stored?)
          d.copyWith(
            id: stored.id,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt,
          ),
    ];
    final updates = <TripCylinderEvent>[];
    for (final u in candidates) {
      try {
        await _repository.updateEvent(u);
        updates.add(u);
      } on TripCylinderEventMissing {
        // Deleted since the earlier attempt (by a sync, say): the diver
        // still wants this fill, so it is created again below.
        _written = {
          for (final w in _written.entries)
            if (w.key != u.tripCylinderId) w.key: w.value,
        };
      }
    }
    final fresh = [
      for (final d in drafts)
        if (!_written.containsKey(d.tripCylinderId)) d,
    ];
    final created = fresh.isEmpty
        ? const <TripCylinderEvent>[]
        : await _repository.createEvents(fresh);
    _written = {
      ..._written,
      for (final w in [...updates, ...created]) w.tripCylinderId: w,
    };
    return [for (final d in drafts) _written[d.tripCylinderId]!];
  }

  /// Writes an edit of an existing fill.
  Future<TripCylinderEvent> writeEdit(TripCylinderEvent fill) async {
    await _repository.updateEvent(fill);
    return fill;
  }

  /// Copies each fill on one of the diver's own cylinders to its passport.
  /// Fills whose slot is not in [slotsById] are skipped. [stationResolved]
  /// false keeps an existing copy's station name (see
  /// [TripFillPassportCopier.afterSave]).
  Future<void> copyToPassports(
    List<TripCylinderEvent> fills,
    Map<String, TripCylinder> slotsById, {
    String? diverId,
    String? stationName,
    bool stationResolved = true,
  }) async {
    for (final fill in fills) {
      final slot = slotsById[fill.tripCylinderId];
      if (slot == null) continue;
      await _copier.afterSave(
        fill,
        slot,
        diverId: diverId,
        stationName: stationName,
        stationResolved: stationResolved,
      );
    }
  }
}
