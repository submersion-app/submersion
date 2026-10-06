import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';

/// Depth below a gas's MOD that a sample must exceed to count as "deeper than
/// the MOD": absorbs waves and sensor noise at a stop near the MOD.
const double modHysteresisMeters = 1.0;

/// A stretch where a richer eligible gas was carried but not breathed, before
/// the tolerance and obligation rules decide whether it is flagged.
class DetectedSwitchWindow {
  const DetectedSwitchWindow({
    required this.gas,
    required this.startIndex,
    required this.endIndex,
    this.switchIndex,
  });

  /// The gas the ideal ascent would have been breathing.
  final AvailableGas gas;

  /// First behind sample.
  final int startIndex;

  /// Sample at which the window stopped: the switch, a richer ideal gas taking
  /// over, or the last sample.
  final int endIndex;

  /// First sample from [startIndex] onward that breathes [gas]; null when the
  /// diver never did (a missed switch).
  final int? switchIndex;
}

class SwitchWindowDetection {
  const SwitchWindowDetection({
    required this.assessedGasCount,
    required this.windows,
  });

  /// Gases the dive took deeper than their MOD and then ascended past.
  final int assessedGasCount;
  final List<DetectedSwitchWindow> windows;
}

/// Compares the gas breathed at each sample with the gas the ideal ascent
/// (OptimalOcAscentGas over the gases already eligible) would breathe there.
///
/// A gas is assessed only once the dive has been deeper than its MOD plus
/// [modHysteresisMeters]; it becomes eligible at the first sample after the
/// last such sample that is at or above the MOD, so a mid-dive excursion never
/// opens a window. A sample is
/// behind when the ideal gas is richer than the breathed one and the diver has
/// not breathed the ideal gas since it became eligible: a return to a leaner
/// gas after switching is an air break, not a late switch.
SwitchWindowDetection detectSwitchWindows({
  required List<double> depths,
  required List<int> timestamps,
  required List<ProfileGasSegment> gasSegments,
  required List<AvailableGas> gases,
  required double maxPpO2,
}) {
  final n = depths.length;
  final idealIndex = <int, int>{};
  for (var g = 0; g < gases.length; g++) {
    final threshold = gases[g].maxPpO2Mod + modHysteresisMeters;
    final lastDeep = depths.lastIndexWhere((d) => d > threshold);
    if (lastDeep < 0) continue;
    // The ideal point is the first sample after that crossing which is at or
    // above the MOD itself, not merely inside the hysteresis band. A gas the
    // final ascent never brings to its MOD (a recording that stops between
    // the two) has nothing to judge, so it is not assessed.
    final mod = gases[g].maxPpO2Mod + 1e-9;
    final first = depths.indexWhere((d) => d <= mod, lastDeep + 1);
    if (first < 0) continue;
    idealIndex[g] = first;
  }
  if (idealIndex.isEmpty) {
    return const SwitchWindowDetection(assessedGasCount: 0, windows: []);
  }

  final actual = [
    for (var i = 0; i < n; i++) activeSegmentAt(gasSegments, timestamps[i]),
  ];
  bool breathes(int i, AvailableGas gas) =>
      sameMix(segmentFO2(actual[i]), actual[i].fHe, gas.fO2, gas.fHe);

  final breathedSinceIdeal = <int>{};
  final windows = <DetectedSwitchWindow>[];
  int? openGas;
  var openStart = 0;

  void close(int endIndex) {
    final gas = gases[openGas!];
    int? switchIndex;
    for (var k = openStart; k < n; k++) {
      if (breathes(k, gas)) {
        switchIndex = k;
        break;
      }
    }
    windows.add(
      DetectedSwitchWindow(
        gas: gas,
        startIndex: openStart,
        endIndex: endIndex,
        switchIndex: switchIndex,
      ),
    );
    openGas = null;
  }

  for (var i = 0; i < n; i++) {
    for (final entry in idealIndex.entries) {
      if (entry.value <= i && breathes(i, gases[entry.key])) {
        breathedSinceIdeal.add(entry.key);
      }
    }
    final ideal = _idealGasIndex(i, depths[i], gases, idealIndex, maxPpO2);
    final current = openGas;
    if (current != null) {
      // An open window ends when its gas is breathed, when the diver moves to
      // a gas at least as rich, or when a richer gas becomes ideal. Depth
      // noise at a stop near the MOD (a 6 m O2 stop reading 5.9, 6.2, 5.9 m)
      // must not split one late switch into many.
      final richerIdeal =
          ideal != null && gases[ideal].fO2 > gases[current].fO2;
      final onRicherGas =
          segmentFO2(actual[i]) + mixMatchTolerance >= gases[current].fO2;
      if (!breathedSinceIdeal.contains(current) &&
          !richerIdeal &&
          !onRicherGas) {
        continue;
      }
      close(i);
    }
    final behind =
        ideal != null &&
        !breathedSinceIdeal.contains(ideal) &&
        gases[ideal].fO2 > segmentFO2(actual[i]) + mixMatchTolerance;
    if (behind) {
      openGas = ideal;
      openStart = i;
    }
  }
  if (openGas != null) close(n - 1);

  return SwitchWindowDetection(
    assessedGasCount: idealIndex.length,
    windows: windows,
  );
}

/// Index into [gases] of the ideal gas at sample [i], or null when no
/// assessed gas is eligible there (none past its ideal index and at or above
/// its MOD).
int? _idealGasIndex(
  int i,
  double depth,
  List<AvailableGas> gases,
  Map<int, int> idealIndex,
  double maxPpO2,
) {
  final eligible = [
    for (final entry in idealIndex.entries)
      if (entry.value <= i && depth <= gases[entry.key].maxPpO2Mod + 1e-9)
        entry.key,
  ];
  if (eligible.isEmpty) return null;
  final pick = OptimalOcAscentGas(
    gases: [for (final g in eligible) gases[g]],
    maxPpO2: maxPpO2,
  ).gasForDepth(depth);
  for (final g in eligible) {
    if (gases[g].fN2 == pick.fN2 && gases[g].fHe == pick.fHe) return g;
  }
  return eligible.first;
}
