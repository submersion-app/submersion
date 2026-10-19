/// When each cylinder of a CCR dive lost pressure, split into loop time and
/// open-circuit time (issue #3307).
///
/// A Shearwater reads a transmitter's role off the first letter of its name,
/// so a bailout named "OC" arrives as the oxygen supply. The mixes cannot
/// expose that (the importer defaults an oxygen supply to 100%), but the
/// timing can: an O2 supply or a diluent drains while the diver is on the
/// loop, a bailout only once they switch to open circuit. Comparing drop
/// RATES rather than shares keeps a constant-mass-flow (mCCR) O2 supply,
/// which bleeds at one rate throughout, from ever looking like a bailout.
library;

import 'package:submersion/core/constants/enums.dart';

/// Smallest drop on open circuit, in bar, that can flag a cylinder.
const double kBailoutMinOcDropBar = 20.0;

/// Shortest total open-circuit time, in seconds, worth judging.
const int kBailoutMinOcSeconds = 120;

/// How many times faster than on the loop a cylinder must drain on open
/// circuit to count as the bailout.
const double kBailoutMinRateRatio = 4.0;

/// Whether a cylinder of [roleName] (a [TankRole] name) is breathed on the
/// loop. Everything else a CCR diver switches to is open circuit.
bool isLoopTankRole(String? roleName) =>
    roleName == TankRole.diluent.name || roleName == TankRole.oxygenSupply.name;

/// The role a name-derived transmitter tank takes once the timeline shows
/// it was breathed as [ocRoleName]'s gas: that open-circuit role (bailout, or
/// a deco or stage gas), or bailout when the cylinder is gone or is a loop
/// gas.
TankRole openCircuitTargetRole(String? ocRoleName) {
  if (ocRoleName == null || isLoopTankRole(ocRoleName)) return TankRole.bailout;
  return TankRole.values.asNameMap()[ocRoleName] ?? TankRole.bailout;
}

typedef TimelineSwitch<K> = ({int t, K tankKey});
typedef TimelinePressure = ({int t, double bar});

/// One cylinder that drained like a bailout.
class BailoutEvidence<K> {
  const BailoutEvidence({
    required this.tankKey,
    required this.ocDropBar,
    required this.loopRate,
    required this.ocRate,
    required this.ocTankKey,
  });

  final K tankKey;

  /// Pressure lost during open-circuit time, in bar.
  final double ocDropBar;

  /// Drop rates in bar per minute.
  final double loopRate;
  final double ocRate;

  /// The open-circuit target that was active for the largest share of
  /// [ocDropBar]: the gas this cylinder was actually breathed as.
  final K ocTankKey;
}

/// Null when the dive cannot be judged: no switches, a first switch to the
/// loop (so the starting gas is unknown), or no open-circuit time at all.
/// Otherwise one entry per [candidates] key that drained like a bailout.
///
/// [isLoopTank] says whether a switch target is a loop gas. Samples after
/// [inWaterEndSeconds] are ignored, so topside bleed-down never counts.
List<BailoutEvidence<K>>? bailoutEvidence<K>({
  required List<TimelineSwitch<K>> switches,
  required bool Function(K tankKey) isLoopTank,
  required Map<K, List<TimelinePressure>> pressures,
  required Iterable<K> candidates,
  required int? inWaterEndSeconds,
}) {
  if (switches.isEmpty) return null;
  final ordered = [...switches]..sort((a, b) => a.t.compareTo(b.t));
  if (isLoopTank(ordered.first.tankKey)) return null;

  final end = inWaterEndSeconds ?? _lastSampleTime(pressures, ordered);

  var ocSeconds = 0;
  for (var i = 0; i < ordered.length; i++) {
    final from = ordered[i].t.clamp(0, end);
    final to = (i + 1 < ordered.length ? ordered[i + 1].t : end).clamp(0, end);
    if (!isLoopTank(ordered[i].tankKey)) ocSeconds += to - from;
  }
  if (ocSeconds <= 0) return null;
  if (ocSeconds < kBailoutMinOcSeconds) return const [];
  final loopSeconds = end - ocSeconds;

  final out = <BailoutEvidence<K>>[];
  for (final key in candidates) {
    final samples = _withoutDropouts(pressures[key] ?? const []);
    if (samples.length < 2) continue;
    var loopDrop = 0.0;
    final ocDropByTarget = <K, double>{};
    // One cursor over the time-sorted switches: the open-circuit target
    // active at the current sample, or null while on the loop.
    var next = 0;
    K? target;
    for (var i = 1; i < samples.length; i++) {
      final t = samples[i].t;
      if (t > end) break;
      while (next < ordered.length && ordered[next].t <= t) {
        final key = ordered[next++].tankKey;
        target = isLoopTank(key) ? null : key;
      }
      final drop = samples[i - 1].bar - samples[i].bar;
      if (drop <= 0) continue;
      if (target == null) {
        loopDrop += drop;
      } else {
        ocDropByTarget[target] = (ocDropByTarget[target] ?? 0) + drop;
      }
    }
    final ocDrop = ocDropByTarget.values.fold(0.0, (a, b) => a + b);
    if (ocDrop <= kBailoutMinOcDropBar) continue;
    final ocRate = ocDrop / (ocSeconds / 60);
    final loopRate = loopSeconds > 0 ? loopDrop / (loopSeconds / 60) : 0.0;
    if (ocRate < kBailoutMinRateRatio * loopRate) continue;
    final ocTankKey = ocDropByTarget.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    out.add(
      BailoutEvidence(
        tankKey: key,
        ocDropBar: ocDrop,
        loopRate: loopRate,
        ocRate: ocRate,
        ocTankKey: ocTankKey,
      ),
    );
  }
  return out;
}

/// Biggest dip below both neighbours, in bar, still read as a real reading.
const double _kDropoutDipBar = 10.0;

/// [samples] without transmitter dropouts: readings of zero or less, and an
/// isolated sample far below both its neighbours. Either would otherwise
/// count as a drop of the whole cylinder.
List<TimelinePressure> _withoutDropouts(List<TimelinePressure> samples) {
  final positive = [
    for (final s in samples)
      if (s.bar > 0) s,
  ];
  return [
    for (var i = 0; i < positive.length; i++)
      if (i == 0 ||
          i == positive.length - 1 ||
          positive[i - 1].bar - positive[i].bar <= _kDropoutDipBar ||
          positive[i + 1].bar - positive[i].bar <= _kDropoutDipBar)
        positive[i],
  ];
}

int _lastSampleTime<K>(
  Map<K, List<TimelinePressure>> pressures,
  List<TimelineSwitch<K>> ordered,
) {
  var last = ordered.last.t;
  for (final s in pressures.values) {
    if (s.isNotEmpty && s.last.t > last) last = s.last.t;
  }
  return last;
}
