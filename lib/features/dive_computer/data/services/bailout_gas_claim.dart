import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/profile/surfacing_pressure.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_series.dart';

/// The parse after bailout transmitters claimed their gases.
typedef BailoutClaim = ({
  /// Claimed cylinders removed, claimers carrying the claimed mix.
  List<TankData> tanks,

  /// Claimed cylinder index -> the index of the transmitter that claimed it,
  /// so gas switches to the cylinder land on the transmitter instead.
  Map<int, int> remappedIndices,
});

/// Lets a bailout transmitter take the open-circuit gas it was breathed as
/// (issue #3307).
///
/// A Shearwater never links a transmitter to a mix, and its gas list gives
/// the bailout gas a pressureless cylinder of its own. Once the transmitter
/// is known to be the bailout (the registry says so, or the diver set it),
/// that cylinder is the same one: the transmitter claims it, unless the
/// evidence is ambiguous.
///
/// A claimer is a bailout with a transmitter serial, no role source and no
/// recorded mix. It claims the open-circuit gas the timeline says it was
/// breathed as; without timeline evidence, the dive's only pressureless
/// bailout cylinder. Each cylinder is claimed at most once, and none in
/// [keep] (a stored cylinder the diver edited) is ever claimed. [tanks] must
/// be one computer's tanks.
BailoutClaim claimBailoutGases({
  required List<TankData> tanks,
  required List<GasSwitchEvent> switches,
  required Map<int, List<TimelinePressure>> pressuresByIndex,
  required int? inWaterEndSeconds,
  Set<int> keep = const {},
}) {
  final claimers = tanks.where(_isClaimer).toList();
  if (claimers.isEmpty) return (tanks: tanks, remappedIndices: const {});

  final byIndex = {for (final t in tanks) t.index: t};
  final evidence = bailoutEvidence<int>(
    switches: [
      for (final sw in switches) (t: sw.timeSeconds, tankKey: sw.toTankIndex),
    ],
    isLoopTank: (i) => isLoopTankRole(byIndex[i]?.role),
    pressures: pressuresByIndex,
    candidates: claimers.map((t) => t.index),
    inWaterEndSeconds: inWaterEndSeconds,
  );
  final breathedAs = {
    for (final e in evidence ?? const <BailoutEvidence<int>>[])
      e.tankKey: e.ocTankKey,
  };

  final remapped = <int, int>{};
  final claimedMix = <int, TankData>{};
  for (final claimer in claimers) {
    final target = _targetFor(
      claimer,
      breathedAs,
      byIndex,
      tanks,
      remapped,
      keep,
    );
    if (target == null) continue;
    remapped[target.index] = claimer.index;
    claimedMix[claimer.index] = target;
  }
  if (remapped.isEmpty) return (tanks: tanks, remappedIndices: const {});

  return (
    tanks: [
      for (final t in tanks)
        if (!remapped.containsKey(t.index))
          claimedMix[t.index] == null
              ? t
              : t.copyWith(
                  o2Percent: claimedMix[t.index]!.o2Percent,
                  hePercent: claimedMix[t.index]!.hePercent,
                  mixRecorded: true,
                ),
    ],
    remappedIndices: remapped,
  );
}

TankData? _targetFor(
  TankData claimer,
  Map<int, int> breathedAs,
  Map<int, TankData> byIndex,
  List<TankData> tanks,
  Map<int, int> alreadyClaimed,
  Set<int> keep,
) {
  bool free(TankData t) =>
      _isGasCylinder(t) &&
      !keep.contains(t.index) &&
      !alreadyClaimed.containsKey(t.index);

  final fromTimeline = byIndex[breathedAs[claimer.index]];
  if (fromTimeline != null) return free(fromTimeline) ? fromTimeline : null;

  final bailouts = tanks
      .where((t) => t.role == TankRole.bailout.name && free(t))
      .toList();
  return bailouts.length == 1 ? bailouts.single : null;
}

/// [claimBailoutGases] for one computer's share of a CCR dive, with the
/// timeline built from its samples. Any other dive mode is returned as is.
BailoutClaim claimBailoutGasesInDive({
  required List<TankData> tanks,
  required String? diveMode,
  required List<GasSwitchEvent> switches,
  required Iterable<TankPressureSampleView> samples,
  required Iterable<({int t, double depth})> depths,
  Set<int> keep = const {},
}) {
  if (diveMode != DiveMode.ccr.code) {
    return (tanks: tanks, remappedIndices: const {});
  }
  return claimBailoutGases(
    tanks: tanks,
    switches: switches,
    pressuresByIndex: {
      for (final e in groupPressuresByTank(samples).entries)
        e.key: [for (final p in e.value) (t: p.timestamp, bar: p.pressure)],
    },
    inWaterEndSeconds: lastTimeBelowSurfaceThreshold(depths),
    keep: keep,
  );
}

bool _isClaimer(TankData t) =>
    t.role == TankRole.bailout.name &&
    t.roleSource == null &&
    t.transmitterSerial != null &&
    !t.mixRecorded;

/// A cylinder that is only a gas from the computer's list: no transmitter,
/// and a mix the computer recorded.
bool _isGasCylinder(TankData t) => t.transmitterSerial == null && t.mixRecorded;
