import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/utils/time_weighted_mean.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/gas_use_window.dart';

const _tank = DiveTank(
  id: 't1',
  volume: 12,
  startPressure: 200,
  endPressure: 100,
);

/// 20 minutes underwater, then 10 at the surface with the computer still
/// logging.
const _tailProfile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 60, depth: 15),
  DiveProfilePoint(timestamp: 1140, depth: 15),
  DiveProfilePoint(timestamp: 1200, depth: 0.4),
  DiveProfilePoint(timestamp: 1500, depth: 0.3),
  DiveProfilePoint(timestamp: 1800, depth: 0.2),
];

/// The same dive, ending when the diver surfaced.
const _noTailProfile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 60, depth: 15),
  DiveProfilePoint(timestamp: 1140, depth: 15),
  DiveProfilePoint(timestamp: 1200, depth: 0),
];

Dive _dive({
  Duration? runtime = const Duration(minutes: 30),
  double? avgDepth = 10,
  List<DiveProfilePoint> profile = const [],
  GasUse? storedGasUse,
  DiveMode diveMode = DiveMode.oc,
}) => Dive(
  id: 'd',
  dateTime: DateTime.utc(2026, 1, 1),
  runtime: runtime,
  avgDepth: avgDepth,
  tanks: const [_tank],
  profile: profile,
  storedGasUse: storedGasUse,
  diveMode: diveMode,
);

/// Whole-dive SAC and RMV leave out surface time at the ends of the recording
/// (issue #2930).
void main() {
  final tailAvg = timeWeightedMean(
    _tailProfile.take(4),
    time: (p) => p.timestamp,
    value: (p) => p.depth,
  )!;

  test('a surface tail is left out of the SAC', () {
    final dive = _dive(profile: _tailProfile);
    expect(dive.gasUse, GasUse(seconds: 1200, avgDepth: tailAvg));
    final ambient = dive.environment.pressureAtDepth(tailAvg);
    expect(dive.sac, closeTo(100 / 20 / ambient, 1e-9));
  });

  test('a dive with no surface tail keeps the runtime and average depth', () {
    final dive = _dive(
      runtime: const Duration(minutes: 20),
      profile: _noTailProfile,
    );
    expect(dive.gasUse, isNull);
    final ambient = dive.environment.pressureAtDepth(10);
    expect(dive.sac, closeTo(100 / 20 / ambient, 1e-9));
  });

  test('a runtime already shorter than the window is not cut again', () {
    final dive = _dive(
      runtime: const Duration(minutes: 15),
      profile: _tailProfile,
    );
    final ambient = dive.environment.pressureAtDepth(tailAvg);
    expect(dive.sac, closeTo(100 / 15 / ambient, 1e-9));
  });

  test('a dive read without samples uses its stored window', () {
    const stored = GasUse(seconds: 1200, avgDepth: 12);
    final dive = _dive(storedGasUse: stored);
    expect(dive.gasUse, stored);
    final ambient = dive.environment.pressureAtDepth(12);
    expect(dive.sac, closeTo(100 / 20 / ambient, 1e-9));

    final untrimmed = _dive().rmvFor(GasModel.ideal)!;
    final trimmed = dive.rmvFor(GasModel.ideal)!;
    // Gas used (liters) is the same; only the time and the depth change.
    final gasLiters = untrimmed * 30 * _dive().environment.pressureAtDepth(10);
    expect(trimmed, closeTo(gasLiters / 20 / ambient, 1e-9));
  });

  test('the profile wins over a stored window', () {
    final dive = _dive(
      profile: _tailProfile,
      storedGasUse: const GasUse(seconds: 60, avgDepth: 3),
    );
    expect(dive.gasUse!.seconds, 1200);
  });

  test('a profile with nothing to trim ignores a stored window', () {
    final dive = _dive(
      runtime: const Duration(minutes: 20),
      profile: _noTailProfile,
      storedGasUse: const GasUse(seconds: 60, avgDepth: 3),
    );
    expect(dive.gasUse, isNull);
  });

  test('rebreather and runtime-less dives still have no SAC', () {
    expect(_dive(profile: _tailProfile, diveMode: DiveMode.ccr).sac, isNull);
    expect(
      _dive(
        runtime: null,
        avgDepth: 10,
        storedGasUse: const GasUse(seconds: 1200, avgDepth: 12),
      ).sac,
      isNull,
    );
  });
}
