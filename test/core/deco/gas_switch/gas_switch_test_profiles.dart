import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';

typedef SampledProfile = ({List<int> timestamps, List<double> depths});

/// Samples a piecewise-linear dive every [step] seconds through
/// [waypoints] (seconds, metres).
SampledProfile sampleProfile(List<(int, double)> waypoints, {int step = 10}) {
  final timestamps = <int>[];
  final depths = <double>[];
  for (var t = waypoints.first.$1; t <= waypoints.last.$1; t += step) {
    timestamps.add(t);
    depths.add(_depthAt(waypoints, t));
  }
  if (timestamps.last != waypoints.last.$1) {
    timestamps.add(waypoints.last.$1);
    depths.add(waypoints.last.$2);
  }
  return (timestamps: timestamps, depths: depths);
}

double _depthAt(List<(int, double)> waypoints, int t) {
  for (var k = 1; k < waypoints.length; k++) {
    final (t1, d1) = waypoints[k];
    if (t <= t1) {
      final (t0, d0) = waypoints[k - 1];
      return t1 == t0 ? d1 : d0 + (d1 - d0) * (t - t0) / (t1 - t0);
    }
  }
  return waypoints.last.$2;
}

/// A cylinder with its MOD at [maxPpO2].
AvailableGas gasOf(double fO2, {double fHe = 0, double maxPpO2 = 1.6}) =>
    AvailableGas(
      fN2: 1 - fO2 - fHe,
      fHe: fHe,
      maxPpO2Mod: O2ToxicityCalculator.calculateMod(fO2, maxPpO2: maxPpO2),
    );

/// A recorded gas segment starting at [t].
ProfileGasSegment seg(int t, double fO2, {double fHe = 0}) =>
    ProfileGasSegment(startTimestamp: t, fN2: 1 - fO2 - fHe, fHe: fHe);

/// 25 min at 40 m, then stops at 21, 18, 15, 12, 9, 6 and 3 m. EAN50's MOD
/// (22 m at 1.6) is first reached at the 21 m stop (t = 1630); O2's (6 m)
/// at t = 2510.
const standardDecoDive = <(int, double)>[
  (0, 0),
  (120, 40),
  (1500, 40),
  (1630, 21),
  (1750, 21),
  (1770, 18),
  (1890, 18),
  (1910, 15),
  (2030, 15),
  (2050, 12),
  (2230, 12),
  (2250, 9),
  (2490, 9),
  (2510, 6),
  (3110, 6),
  (3130, 3),
  (3730, 3),
  (3750, 0),
];

int indexAt(SampledProfile profile, int timestamp) =>
    profile.timestamps.indexOf(timestamp);
