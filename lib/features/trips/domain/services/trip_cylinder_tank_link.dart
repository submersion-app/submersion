import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

/// Pure. [tank] linked to [slot] and filled from it: the mix and start
/// pressure from the slot's current state, the size, working pressure,
/// material and preset from the slot when it has them (decided 2026-09-28).
/// Whatever the slot does not know keeps the tank's own value; the end
/// pressure is always the diver's to log.
DiveTank tankFromTripCylinder(DiveTank tank, TripCylinderState slot) {
  final c = slot.cylinder;
  final hasSpecs = c.volume != null || c.workingPressure != null;
  return tank.copyWith(
    tripCylinderId: c.id,
    gasMix: slot.mix,
    startPressure: slot.pressure,
    volume: c.volume,
    workingPressure: c.workingPressure,
    material: c.material,
    presetName: c.presetName,
    // Specs from the slot with no preset name or material must not keep
    // the tank's old ones, or the tank would claim a cylinder it is not.
    clearPresetName: hasSpecs && c.presetName == null,
    clearMaterial: hasSpecs && c.material == null,
  );
}

/// Pure. Links each tank in [eligibleTankIds] that has no link to the slot
/// [suggestTripCylinder] picks for it, filled by [tankFromTripCylinder].
/// Slots other tanks already hold, and slots given to an earlier tank in
/// this pass, are excluded, so two tanks never share one. Returns the tanks
/// in their order and the ids of the tanks it linked.
({List<DiveTank> tanks, Set<String> suggested}) suggestTripCylindersForTanks({
  required List<DiveTank> tanks,
  required List<TripCylinderState> states,
  required Set<String> eligibleTankIds,
}) {
  final byId = {for (final s in states) s.cylinder.id: s};
  var taken = {
    for (final t in tanks)
      if (t.tripCylinderId != null) t.tripCylinderId!,
  };
  var suggested = const <String>{};
  var out = const <DiveTank>[];
  for (final t in tanks) {
    final pick = eligibleTankIds.contains(t.id) && t.tripCylinderId == null
        ? suggestTripCylinder(
            states: states,
            tankMix: t.gasMix,
            excludedCylinderIds: taken,
          )
        : null;
    if (pick == null) {
      out = [...out, t];
      continue;
    }
    taken = {...taken, pick.id};
    suggested = {...suggested, t.id};
    out = [...out, tankFromTripCylinder(t, byId[pick.id]!)];
  }
  return (tanks: out, suggested: suggested);
}
