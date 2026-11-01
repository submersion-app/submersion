import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Nitrogen fraction the deco engine breathes for [mix]: air is the exact
/// atmospheric fraction, everything else the remainder after O2 and He
/// (mirrors the dive detail page's buildProfileGasSegments).
double fN2Of(GasMix mix) =>
    mix.isAir ? airN2Fraction : (100.0 - mix.o2 - mix.he) / 100.0;

/// From [startTimestamp] the diver breathes [tankId] (null = no tank known,
/// treated as air).
class TankInterval extends Equatable {
  const TankInterval({required this.startTimestamp, required this.tankId});
  final int startTimestamp;
  final String? tankId;
  @override
  List<Object?> get props => [startTimestamp, tankId];
}

/// Which carried tank is breathed when, over a profile.
class TankSchedule extends Equatable {
  const TankSchedule({required this.intervals, required this.tanks});

  /// Ascending by [TankInterval.startTimestamp]; never empty.
  final List<TankInterval> intervals;
  final List<DiveTank> tanks;

  /// The dive's schedule: back gas (else the first tank) from
  /// [originTimestamp], then each recorded switch in time order. Switches to
  /// the tank already in force are dropped; two switches at one timestamp
  /// keep the later-sorted one.
  factory TankSchedule.fromDive({
    required List<DiveTank> tanks,
    required List<ScenarioGasSwitch> switches,
    int originTimestamp = 0,
  }) {
    final primary = tanks.isEmpty
        ? null
        : tanks.firstWhere(
            (t) => t.role == TankRole.backGas,
            orElse: () => tanks.first,
          );
    final intervals = <TankInterval>[
      TankInterval(startTimestamp: originTimestamp, tankId: primary?.id),
    ];
    final sorted = List<ScenarioGasSwitch>.from(switches)
      ..sort((a, b) {
        final c = a.timestamp.compareTo(b.timestamp);
        return c != 0 ? c : a.tankId.compareTo(b.tankId);
      });
    for (final s in sorted) {
      if (s.timestamp < originTimestamp) continue;
      if (intervals.last.startTimestamp == s.timestamp) {
        intervals[intervals.length - 1] = TankInterval(
          startTimestamp: s.timestamp,
          tankId: s.tankId,
        );
        continue;
      }
      intervals.add(
        TankInterval(startTimestamp: s.timestamp, tankId: s.tankId),
      );
    }
    return TankSchedule(intervals: collapseIntervals(intervals), tanks: tanks);
  }

  /// Drops intervals that repeat the tank already in force.
  static List<TankInterval> collapseIntervals(List<TankInterval> raw) {
    final out = <TankInterval>[];
    for (final i in raw) {
      if (out.isNotEmpty && out.last.tankId == i.tankId) continue;
      out.add(i);
    }
    return out;
  }

  String? tankIdAt(int timestamp) {
    var id = intervals.first.tankId;
    for (final i in intervals) {
      if (i.startTimestamp <= timestamp) {
        id = i.tankId;
      } else {
        break;
      }
    }
    return id;
  }

  DiveTank? tankById(String? id) {
    if (id == null) return null;
    for (final t in tanks) {
      if (t.id == id) return t;
    }
    return null;
  }

  DiveTank? tankAt(int timestamp) => tankById(tankIdAt(timestamp));

  GasMix mixAt(int timestamp) => tankAt(timestamp)?.gasMix ?? const GasMix();

  /// Open-circuit gas segments for ProfileAnalysisService / BuhlmannAlgorithm.
  List<ProfileGasSegment> toGasSegments() => [
    for (final i in intervals)
      () {
        final mix = tankById(i.tankId)?.gasMix ?? const GasMix();
        return ProfileGasSegment(
          startTimestamp: i.startTimestamp,
          fN2: fN2Of(mix),
          fHe: mix.he / 100.0,
        );
      }(),
  ];

  /// Recorded switches strictly after [timestamp].
  List<ScenarioGasSwitch> switchesAfter(int timestamp) => [
    for (final i in intervals)
      if (i.startTimestamp > timestamp && i.tankId != null)
        ScenarioGasSwitch(timestamp: i.startTimestamp, tankId: i.tankId!),
  ];

  TankSchedule withTanks(List<DiveTank> newTanks) =>
      TankSchedule(intervals: intervals, tanks: newTanks);

  /// Breathe [tankId] from [fromTimestamp] until the next recorded switch;
  /// intervals before stay, later switches stay. [addedTank] joins [tanks].
  TankSchedule switchedTo(
    String tankId, {
    required int fromTimestamp,
    DiveTank? addedTank,
  }) {
    final before = intervals.where((i) => i.startTimestamp < fromTimestamp);
    final after = intervals.where((i) => i.startTimestamp > fromTimestamp);
    final merged = <TankInterval>[
      ...before,
      TankInterval(startTimestamp: fromTimestamp, tankId: tankId),
      ...after,
    ];
    return TankSchedule(
      intervals: collapseIntervals(merged),
      tanks: addedTank == null ? tanks : [...tanks, addedTank],
    );
  }

  @override
  List<Object?> get props => [intervals, tanks];
}

/// The richest carried mix breathable at [depthMeters] under [maxPpO2]
/// (MOD at the deco ppO2, the OptimalOcAscentGas rule), preferring higher
/// O2 then higher He. Falls back to the back gas, else the first tank, when
/// nothing is eligible; null when [tanks] is empty.
DiveTank? bestTankForDepth(
  List<DiveTank> tanks,
  double depthMeters, {
  required double maxPpO2,
}) {
  if (tanks.isEmpty) return null;
  DiveTank? best;
  for (final t in tanks) {
    final mod = O2ToxicityCalculator.calculateMod(
      t.gasMix.o2 / 100.0,
      maxPpO2: maxPpO2,
    );
    if (depthMeters > mod + 1e-9) continue;
    if (best == null ||
        t.gasMix.o2 > best.gasMix.o2 ||
        (t.gasMix.o2 == best.gasMix.o2 && t.gasMix.he > best.gasMix.he)) {
      best = t;
    }
  }
  if (best != null) return best;
  return tanks.firstWhere(
    (t) => t.role == TankRole.backGas,
    orElse: () => tanks.first,
  );
}

/// Intervals for breathing the best tank of [pool] by depth over the samples
/// in `[fromTimestamp, toTimestamp)`; one interval per change of tank.
List<TankInterval> intervalsByDepth({
  required List<DiveTank> pool,
  required int fromTimestamp,
  required int toTimestamp,
  required List<int> timestamps,
  required List<double> depths,
  required double maxPpO2,
}) {
  final out = <TankInterval>[];
  String? current;
  var any = false;
  for (var i = 0; i < timestamps.length; i++) {
    final t = timestamps[i];
    if (t < fromTimestamp || t >= toTimestamp) continue;
    final id = bestTankForDepth(pool, depths[i], maxPpO2: maxPpO2)?.id;
    if (!any || id != current) {
      out.add(
        TankInterval(startTimestamp: any ? t : fromTimestamp, tankId: id),
      );
      current = id;
      any = true;
    }
  }
  if (!any) {
    // No sample fell inside the span: pick by the depth nearest its start.
    var best = 0;
    for (var i = 1; i < timestamps.length; i++) {
      if ((timestamps[i] - fromTimestamp).abs() <
          (timestamps[best] - fromTimestamp).abs()) {
        best = i;
      }
    }
    final id = depths.isEmpty
        ? null
        : bestTankForDepth(pool, depths[best], maxPpO2: maxPpO2)?.id;
    out.add(TankInterval(startTimestamp: fromTimestamp, tankId: id));
  }
  return out;
}

/// Every interval after [fromTimestamp] that breathed [lostTankId] (and the
/// part of the interval in force at [fromTimestamp]) is replaced by the best
/// remaining tank for the depth at each sample; the lost tank leaves
/// [TankSchedule.tanks]. [candidates] restricts the substitutes.
TankSchedule substituteTankByDepth(
  TankSchedule schedule, {
  required String lostTankId,
  required int fromTimestamp,
  required List<int> timestamps,
  required List<double> depths,
  required double maxPpO2,
  List<DiveTank>? candidates,
}) {
  final remaining = schedule.tanks.where((t) => t.id != lostTankId).toList();
  final pool = candidates ?? remaining;
  final out = <TankInterval>[];
  final diveEnd = timestamps.isEmpty ? fromTimestamp : timestamps.last + 1;
  for (var k = 0; k < schedule.intervals.length; k++) {
    final interval = schedule.intervals[k];
    final end = k + 1 < schedule.intervals.length
        ? schedule.intervals[k + 1].startTimestamp
        : diveEnd;
    if (end <= fromTimestamp || interval.tankId != lostTankId) {
      out.add(interval);
      continue;
    }
    if (interval.startTimestamp < fromTimestamp) {
      out.add(interval); // the part before T stays on the lost tank
    }
    final start = interval.startTimestamp < fromTimestamp
        ? fromTimestamp
        : interval.startTimestamp;
    out.addAll(
      intervalsByDepth(
        pool: pool,
        fromTimestamp: start,
        toTimestamp: end,
        timestamps: timestamps,
        depths: depths,
        maxPpO2: maxPpO2,
      ),
    );
  }
  return TankSchedule(
    intervals: TankSchedule.collapseIntervals(out),
    tanks: remaining,
  );
}
