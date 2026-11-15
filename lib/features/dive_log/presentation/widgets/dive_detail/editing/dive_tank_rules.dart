import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveTankRules');
const _uuid = Uuid();

/// Reads a trip's slots as they stood at a moment of the dive.
typedef TripSlotReader =
    Future<List<TripCylinderState>> Function(String tripId, DateTime at);

/// The cylinders linked to a slot by a suggestion, not by the diver.
const _suggestedKey = 'tankSlotsSuggested';

/// The cylinders whose suggestion the diver turned down with None.
const _declinedKey = 'tankSlotsDeclined';

/// Sets the sitting's cylinders. Their order is left as given: renumbering
/// is [removeSittingTank]'s, as it is the form's (`_removeTank`).
void setTanks(EditSession<Dive> session, List<DiveTank> tanks) {
  if (session.isFrozen || session.isDisposed) return;
  session.set(diveTanksField, List<DiveTank>.unmodifiable(tanks));
}

/// Removes the cylinder [tankId] and numbers the rest from 0, as the form
/// does (`dive_edit_page.dart:4454`).
void removeSittingTank(EditSession<Dive> session, String tankId) {
  final kept = [
    for (final t in session.valueOf(diveTanksField))
      if (t.id != tankId) t,
  ];
  setTanks(session, [
    for (var i = 0; i < kept.length; i++)
      kept[i].order == i ? kept[i] : kept[i].copyWith(order: i),
  ]);
}

/// A cylinder to add after [tanks], as the form's `_addTank` builds it
/// (`dive_edit_page.dart:4427`): [preset]'s size, or [defaultVolume]; the
/// diver's [defaultStartPressure], 50 bar at the end, air, back gas when it
/// is the first and a stage after. A fresh id, as `updateDive` requires.
DiveTank newSittingTank({
  required List<DiveTank> tanks,
  required TankPresetEntity? preset,
  required double defaultVolume,
  required double defaultStartPressure,
}) => DiveTank(
  id: _uuid.v4(),
  volume: preset?.volumeLiters ?? defaultVolume,
  workingPressure: preset?.workingPressureBar,
  startPressure: defaultStartPressure,
  endPressure: 50.0,
  role: tanks.isEmpty ? TankRole.backGas : TankRole.stage,
  material: preset?.material,
  order: tanks.length,
  presetName: preset?.name,
);

/// The trip the sitting's dive is on, by id.
String? _tripIdOf(Dive dive) => dive.tripId ?? dive.trip?.id;

/// Which cylinders carry a link a suggestion made, for `TankRow.suggested`.
Set<String> suggestedTankIds(EditSession<Dive> session) =>
    session.recall<Set<String>>(_suggestedKey) ?? const {};

Set<String> _declined(EditSession<Dive> session) =>
    session.recall<Set<String>>(_declinedKey) ?? const {};

/// Suggests a trip slot for each cylinder added in this sitting that has
/// none and whose suggestion the diver has not declined, as the form does
/// when a cylinder is added or the trip set (`_suggestTripCylinders`). A
/// cylinder the dive was stored with is never given one.
///
/// [readSlots] is asked for the sitting's trip at the dive's entry; its
/// answer is dropped when either has changed meanwhile, or the sitting has
/// ended or is being saved. Tracked, so Save waits for it.
void suggestTankSlots(
  EditSession<Dive> session, {
  required TripSlotReader readSlots,
}) {
  final asked = session.working;
  final tripId = _tripIdOf(asked);
  if (tripId == null) return;
  final at = asked.effectiveEntryTime;
  session.track(() async {
    final List<TripCylinderState> states;
    try {
      states = await readSlots(tripId, at);
    } catch (error, stackTrace) {
      _log.warning(
        'Reading the trip slots for a sitting failed',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (session.isDisposed || session.isFrozen) return;
    final now = session.working;
    if (_tripIdOf(now) != tripId || now.effectiveEntryTime != at) return;
    final storedIds = {for (final t in session.stored.tanks) t.id};
    final declined = _declined(session);
    final tanks = session.valueOf(diveTanksField);
    final result = suggestTripCylindersForTanks(
      tanks: tanks,
      states: states,
      eligibleTankIds: {
        for (final t in tanks)
          if (!storedIds.contains(t.id) && !declined.contains(t.id)) t.id,
      },
    );
    if (result.suggested.isEmpty) return;
    session.remember(_suggestedKey, {
      ...suggestedTankIds(session),
      ...result.suggested,
    });
    setTanks(session, result.tanks);
  }());
}

/// The diver chose a slot for [tankId], or None ([none]): the link is no
/// longer a suggestion, and a None is not overruled by the next one.
void tankSlotChosen(
  EditSession<Dive> session,
  String tankId, {
  required bool none,
}) {
  session.remember(_suggestedKey, {
    for (final id in suggestedTankIds(session))
      if (id != tankId) id,
  });
  if (none) session.remember(_declinedKey, {..._declined(session), tankId});
}

/// After the trip changed (issue #4527, plan 3's open rule): every slot
/// link is cleared, since a slot belongs to one trip, the notes of
/// suggested and declined cylinders start again, and slots on the new trip
/// are suggested ([suggestTankSlots]), as the form's `_setTrip` does.
void tanksAfterTripChange(
  EditSession<Dive> session, {
  required TripSlotReader readSlots,
}) {
  if (session.isFrozen || session.isDisposed) return;
  final tanks = session.valueOf(diveTanksField);
  if (tanks.any((t) => t.tripCylinderId != null)) {
    setTanks(session, [
      for (final t in tanks)
        t.tripCylinderId == null ? t : t.copyWith(clearTripCylinderId: true),
    ]);
  }
  session
    ..remember(_suggestedKey, const <String>{})
    ..remember(_declinedKey, const <String>{});
  suggestTankSlots(session, readSlots: readSlots);
}
