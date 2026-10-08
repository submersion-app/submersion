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

/// Pure. The slots [tank] cannot take because a sibling on its dive holds
/// them. Only a sibling from the same recording counts: one recording's two
/// tanks are two cylinders, but another recording's tank may be its copy of
/// this very cylinder, a row consolidation did not merge, and must be able
/// to share its slot (issue #2661).
///
/// A recording is the tank's computer when it names one. Otherwise it is
/// the tank's data source when that is not the primary (issue #2716: two
/// consolidated sources that name no computer). Otherwise the tank is the
/// dive's own: a hand-added tank, one written before attribution, or the
/// primary source's, all of which are the primary recording, by
/// [primaryComputerId] (`Dive.computerId`) when the dive has one, else by
/// [primarySourceId]. A download stamps its computer on every tank it
/// writes, so without this a hand-added tank would pass for another
/// recording and could share a downloaded tank's slot.
Set<String> tripCylinderIdsTakenFor(
  DiveTank tank,
  List<DiveTank> tanks, {
  required String? primaryComputerId,
  required String? primarySourceId,
}) {
  final primary = primaryComputerId != null
      ? 'computer:$primaryComputerId'
      : 'source:$primarySourceId';
  String recordingOf(DiveTank t) {
    if (t.computerId case final computerId?) return 'computer:$computerId';
    final sourceId = t.sourceId;
    if (sourceId != null && sourceId != primarySourceId) {
      return 'source:$sourceId';
    }
    return primary;
  }

  return {
    for (final t in tanks)
      if (t.id != tank.id && recordingOf(t) == recordingOf(tank))
        ?t.tripCylinderId,
  };
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
