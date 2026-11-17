import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gas_switch_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveTankRules');
const _uuid = Uuid();

/// Reads a trip's slots as they stood at a moment of the dive.
typedef TripSlotReader =
    Future<List<TripCylinderState>> Function(String tripId, DateTime at);

/// A [TripSlotReader] over [container] for dive [diveId], never counting the
/// dive's own use (`_tripCylinderKeyFor`). The provider is auto-disposed, so
/// a listener holds it while the read is in flight; the container outlives
/// the widget that asked.
TripSlotReader tripSlotReader(ProviderContainer container, String diveId) =>
    (tripId, at) async {
      final provider = tripCylinderStatesAtProvider((
        tripId: tripId,
        atMillis: at.millisecondsSinceEpoch,
        excludeDiveId: diveId,
      ));
      final hold = container.listen(provider, (_, _) {});
      try {
        return await container.read(provider.future);
      } finally {
        hold.close();
      }
    };

/// The cylinders linked to a slot by a suggestion, not by the diver.
const _suggestedKey = 'tankSlotsSuggested';

/// The cylinders whose suggestion the diver turned down with None.
const _declinedKey = 'tankSlotsDeclined';

/// How many times the cylinders were replaced from outside their rows.
const _replacedKey = 'tankRowsReplaced';

/// Moves each time the sitting's cylinders are replaced from outside their
/// rows (a saved configuration, a set, the last dive at a center, a site's
/// location set taken back, an exchange). The Cylinders editor keys its
/// rows with it, so an open row is built again from its cylinder instead of
/// keeping the text it was showing, which its next keystroke would write
/// back over the new values.
int tankRowsGeneration(EditSession<Dive> session) =>
    session.recall<int>(_replacedKey) ?? 0;

/// Sets the sitting's cylinders. Their order is left as given: renumbering
/// is [removeSittingTank]'s, as it is the form's (`_removeTank`). Switches
/// whose cylinder is gone go with it ([dropGasSwitchesWithoutTank]).
/// [replaced] is a change made from outside the rows ([tankRowsGeneration]).
void setTanks(
  EditSession<Dive> session,
  List<DiveTank> tanks, {
  bool replaced = false,
}) {
  if (session.isFrozen || session.isDisposed) return;
  if (replaced) {
    session.remember(_replacedKey, tankRowsGeneration(session) + 1);
  }
  session.set(diveTanksField, List<DiveTank>.unmodifiable(tanks));
  dropGasSwitchesWithoutTank(session);
}

/// Removes the cylinder [tankId] and numbers the rest from 0.
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

/// A fresh id for a cylinder the sitting adds: `updateDive` refuses one
/// with none.
String newSittingTankId() => _uuid.v4();

/// A cylinder to add after [tanks], as the old dive form built one: [preset]'s
/// size, or [defaultVolume]; the diver's [defaultStartPressure], 50 bar at the
/// end, air, back gas when it is the first and a stage after. A fresh id, as
/// `updateDive` requires.
DiveTank newSittingTank({
  required List<DiveTank> tanks,
  required TankPresetEntity? preset,
  required double defaultVolume,
  required double defaultStartPressure,
}) => DiveTank(
  id: newSittingTankId(),
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
    // A new dive's seed is not stored: its starter cylinder is offered a
    // slot, as the form offers its own (issue #4527, plan 8).
    final storedIds = session.isNew
        ? const <String>{}
        : {for (final t in session.stored.tanks) t.id};
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
///
/// Back on the trip the dive is stored on, a stored cylinder gets its own
/// link back rather than none: changing the trip and changing it back is
/// no change.
void tanksAfterTripChange(
  EditSession<Dive> session, {
  required TripSlotReader readSlots,
}) {
  if (session.isFrozen || session.isDisposed) return;
  final storedTripId = _tripIdOf(session.stored);
  final backOnStored =
      storedTripId != null && _tripIdOf(session.working) == storedTripId;
  final storedLinks = <String, String?>{
    if (backOnStored)
      for (final t in session.stored.tanks) t.id: t.tripCylinderId,
  };
  DiveTank relinked(DiveTank t) {
    final link = storedLinks[t.id];
    if (link == t.tripCylinderId) return t;
    return link == null
        ? t.copyWith(clearTripCylinderId: true)
        : t.copyWith(tripCylinderId: link);
  }

  final tanks = session.valueOf(diveTanksField);
  final next = [for (final t in tanks) relinked(t)];
  if (!listEquals(next, tanks)) setTanks(session, next);
  session
    ..remember(_suggestedKey, const <String>{})
    ..remember(_declinedKey, const <String>{});
  suggestTankSlots(session, readSlots: readSlots);
}
