import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// The merged dive's tanks, one per physical cylinder, and where each source
/// tank went.
class SequentialTankMerge {
  const SequentialTankMerge({required this.tanks, required this.tankIdMap});

  /// Chronological by first appearance, with fresh ids and `order`
  /// re-sequenced from zero.
  final List<DiveTank> tanks;

  /// Source tank id -> merged tank id. Several source tanks map to one
  /// merged tank when they are the same cylinder, so each half's pressure
  /// series, gas switches and events land on the tank they were logged on.
  final Map<String, String> tankIdMap;
}

/// Folds the tanks of chronologically [sorted] sequential dives into one row
/// per physical cylinder (#2036).
///
/// A dive split in two by a surface interval (a sump, a surfacing to fix
/// something) breathed the same cylinders throughout, and its computer logs
/// them on both halves. Keeping every source tank showed each cylinder twice,
/// once per half, each with that half's pressures only.
///
/// Each later dive's tanks are matched against the cylinders already carried:
/// first by transmitter serial, which is the cylinder's physical identity;
/// then, for a tank with no serial on one side, by gas mix. Either way the
/// pressure must not have risen across the gap: a transmitter moved onto a
/// fresh cylinder reports the same serial on a different tank. A cylinder is
/// claimed by at most one tank per dive, so a dive's own twin cylinders on
/// one mix stay two. Anything unmatched is a new cylinder.
///
/// Only the outer pressures survive a fold (the first half's start, the last
/// half's end). A cylinder with a transmitter log keeps each half's readings
/// in its pressure series, which is what separating the dive rebuilds from;
/// a hand-entered one has nothing else, so separating it hands both halves
/// the combined pair. Accepted: the duplicate cylinder was the worse error.
SequentialTankMerge mergeSequentialTanks(
  List<Dive> sorted, {
  required String Function() idGenerator,
}) {
  final cylinders = <DiveTank>[];
  final tankIdMap = <String, String>{};

  for (final dive in sorted) {
    final tanks = [...dive.tanks]..sort((x, y) => x.order.compareTo(y.order));
    // Only cylinders carried from earlier dives are candidates: two tanks of
    // this dive are never the same cylinder.
    final carried = cylinders.length;
    final claimed = <int>{};
    final matchOf = <String, int>{};

    // Pass 1: serials, so a tank whose serial names a specific cylinder
    // claims that one before a serial-less cylinder on the same mix can.
    for (final tank in tanks) {
      for (var i = 0; i < carried; i++) {
        if (claimed.contains(i)) continue;
        if (_serialIdentity(cylinders[i], tank) == true &&
            _didNotRise(cylinders[i], tank)) {
          matchOf[tank.id] = i;
          claimed.add(i);
          break;
        }
      }
    }

    // Pass 2: the gas-mix heuristic for what is left, taking the cylinder
    // whose last pressure the tank continues most closely.
    for (final tank in tanks) {
      if (matchOf.containsKey(tank.id)) continue;
      int? best;
      var bestGap = double.infinity;
      for (var i = 0; i < carried; i++) {
        if (claimed.contains(i)) continue;
        if (!_continues(cylinders[i], tank)) continue;
        final gap = _pressureGap(cylinders[i], tank);
        if (gap < bestGap) {
          best = i;
          bestGap = gap;
        }
      }
      if (best != null) {
        matchOf[tank.id] = best;
        claimed.add(best);
      }
    }

    for (final tank in tanks) {
      final match = matchOf[tank.id];
      if (match == null) {
        cylinders.add(tank.copyWith(id: idGenerator()));
        tankIdMap[tank.id] = cylinders.last.id;
      } else {
        cylinders[match] = _fold(cylinders[match], tank);
        tankIdMap[tank.id] = cylinders[match].id;
      }
    }
  }

  return SequentialTankMerge(
    tanks: [
      for (var i = 0; i < cylinders.length; i++)
        cylinders[i].copyWith(order: i),
    ],
    tankIdMap: tankIdMap,
  );
}

/// Same tolerance consolidation uses to call two logged mixes the same gas.
const double _gasTolerancePct = 0.5;

/// How far a cylinder's pressure may rise across the surface interval and
/// still be the same cylinder. Breathing it down at the surface lowers the
/// reading, and a cylinder warming from the water into the air gains a few
/// bar; a refill or a swap gains far more.
const double _maxPressureRiseBar = 10.0;

/// True when both tanks carry the same transmitter serial, false when both
/// carry one and they differ, null when either lacks one.
bool? _serialIdentity(DiveTank earlier, DiveTank later) {
  final a = normalizeTransmitterSerial(earlier.transmitterSerial);
  final b = normalizeTransmitterSerial(later.transmitterSerial);
  if (a == null || b == null) return null;
  return a == b;
}

bool _continues(DiveTank earlier, DiveTank later) {
  final bySerial = _serialIdentity(earlier, later);
  if (bySerial == false) return false;
  if (!_didNotRise(earlier, later)) return false;
  if (bySerial == true) return true;
  final o2Close =
      (earlier.gasMix.o2 - later.gasMix.o2).abs() <= _gasTolerancePct;
  final heClose =
      (earlier.gasMix.he - later.gasMix.he).abs() <= _gasTolerancePct;
  return o2Close && heClose;
}

/// Whether [later] starts no more than [_maxPressureRiseBar] above where
/// [earlier] ended. A missing reading carries no evidence either way.
bool _didNotRise(DiveTank earlier, DiveTank later) {
  final end = earlier.endPressure;
  final start = later.startPressure;
  if (end == null || start == null) return true;
  return start - end <= _maxPressureRiseBar;
}

/// How closely [later] picks up where [earlier] left off, for ranking
/// candidates. An unknown pair ranks as the worst still-acceptable one, so a
/// cylinder whose pressures line up is preferred over one that only might.
double _pressureGap(DiveTank earlier, DiveTank later) {
  final end = earlier.endPressure;
  final start = later.startPressure;
  if (end == null || start == null) return _maxPressureRiseBar;
  return (start - end).abs();
}

/// [later]'s readings folded into the cylinder carried so far: the earliest
/// value any half reports for each field, except the end pressure, which is
/// the latest one reported.
DiveTank _fold(DiveTank earlier, DiveTank later) => earlier.copyWith(
  name: earlier.name ?? later.name,
  volume: earlier.volume ?? later.volume,
  workingPressure: earlier.workingPressure ?? later.workingPressure,
  startPressure: earlier.startPressure ?? later.startPressure,
  endPressure: later.endPressure ?? earlier.endPressure,
  material: earlier.material ?? later.material,
  presetName: earlier.presetName ?? later.presetName,
  computerId: earlier.computerId ?? later.computerId,
  // Normalized, like the matching: a "no transmitter" sentinel ('0', blank)
  // on the earlier half must not hide a real serial on a later one. With no
  // real serial on either side, null leaves the earlier raw value as it was.
  transmitterSerial:
      normalizeTransmitterSerial(earlier.transmitterSerial) ??
      normalizeTransmitterSerial(later.transmitterSerial),
  sourceTankIndex: earlier.sourceTankIndex ?? later.sourceTankIndex,
  regulatorEquipmentId:
      earlier.regulatorEquipmentId ?? later.regulatorEquipmentId,
  equipmentId: earlier.equipmentId ?? later.equipmentId,
  decoSwitchDepth: earlier.decoSwitchDepth ?? later.decoSwitchDepth,
);
