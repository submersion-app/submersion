import 'package:submersion/core/database/database.dart';

/// Which cylinders on a dive are one physical cylinder, and which row of them
/// stays when the duplicates are removed (issue #4393).
///
/// The usual duplicate is two computers paired to one transmitter, their
/// dives consolidated: each brought its own row for the same cylinder. Two
/// rows carrying one transmitter serial are the same cylinder by definition;
/// the twin detector (tank_assignment) also pairs rows whose pressure curves
/// match when neither has a serial.

/// Tolerance below which two mixes are the same (percentage points).
const double _mixTolerance = 0.05;

String? _normalSerial(String? serial) {
  final s = serial?.trim().toUpperCase();
  return s == null || s.isEmpty ? null : s;
}

/// Tanks grouped by transmitter serial, ignoring case and surrounding
/// whitespace: each group of two or more, ids sorted, groups ordered by
/// their first id. Tanks without a serial are left out.
List<List<String>> serialGroups(List<DiveTank> tanks) {
  final bySerial = <String, List<String>>{};
  for (final t in tanks) {
    final serial = _normalSerial(t.transmitterSerial);
    if (serial == null) continue;
    (bySerial[serial] ??= []).add(t.id);
  }
  final groups = [
    for (final ids in bySerial.values)
      if (ids.length >= 2) (ids.toList()..sort()),
  ]..sort((a, b) => a.first.compareTo(b.first));
  return groups;
}

/// The cylinders a twin finding (tank ids [tankIdA] and [tankIdB]) is about,
/// among the dive's live [tanks]: the whole serial group of [tankIdA] when
/// the twins share a transmitter, else the pair. Ids no longer on the dive
/// are dropped, and fewer than two left means nothing to merge (empty).
List<String> duplicateGroupFor({
  required String tankIdA,
  required String tankIdB,
  required bool sameTransmitter,
  required List<DiveTank> tanks,
}) {
  final live = {for (final t in tanks) t.id};
  final List<String> group;
  if (sameTransmitter) {
    group = serialGroups(
      tanks,
    ).firstWhere((g) => g.contains(tankIdA), orElse: () => const []);
  } else {
    group = ([tankIdA, tankIdB].where(live.contains).toList())..sort();
  }
  return group.length >= 2 ? group : const [];
}

/// How much of a cylinder the diver described. Gas mix is not counted:
/// `o2Percent` defaults to 21, so an unset mix looks like air.
int _detail(DiveTank t) => [
  t.volume != null,
  t.workingPressure != null,
  t.tankName != null || t.presetName != null,
  t.equipmentId != null,
  t.regulatorEquipmentId != null,
].where((has) => has).length;

/// Whether [t] is the primary source's row: it names that source, or it names
/// none and has no computer or the primary's computer (an unattributed tank
/// belongs to the primary, v251).
bool _isPrimarys(
  DiveTank t,
  String? primarySourceId,
  String? primaryComputerId,
) {
  if (primarySourceId == null) return false;
  if (t.sourceId != null) return t.sourceId == primarySourceId;
  return t.computerId == null || t.computerId == primaryComputerId;
}

/// The id of the row in [group] that stays: the primary source's when only
/// some rows are its, then the most diver-entered detail, then the lowest
/// id, so the choice is the same every time.
String pickSurvivor(
  List<DiveTank> group, {
  required String? primarySourceId,
  String? primaryComputerId,
}) {
  final primary = [
    for (final t in group)
      if (_isPrimarys(t, primarySourceId, primaryComputerId)) t,
  ];
  final candidates = primary.isEmpty || primary.length == group.length
      ? group
      : primary;
  final ranked = candidates.toList()
    ..sort((a, b) {
      final byDetail = _detail(b).compareTo(_detail(a));
      return byDetail != 0 ? byDetail : a.id.compareTo(b.id);
    });
  return ranked.first.id;
}

/// Whether any two rows of [group] carry a different gas: then the diver,
/// not the app, says which mix the cylinder held.
bool mixesDiffer(List<DiveTank> group) {
  for (final a in group) {
    for (final b in group) {
      if ((a.o2Percent - b.o2Percent).abs() > _mixTolerance ||
          (a.hePercent - b.hePercent).abs() > _mixTolerance) {
        return true;
      }
    }
  }
  return false;
}
