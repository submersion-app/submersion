import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';
import 'package:submersion/core/deco/gas_switch/on_time_gas_schedule.dart';

import 'gas_switch_test_profiles.dart';

void main() {
  final dive = sampleProfile(standardDecoDive);
  final ean50 = gasOf(0.5);

  /// Start timestamps, and fO2 in whole percent (rounded, so air's 0.79 vs
  /// 0.7902 cannot make the comparison flaky).
  (List<int>, List<int>) shape(List<ProfileGasSegment> segments) => (
    [for (final s in segments) s.startTimestamp],
    [for (final s in segments) (segmentFO2(s) * 100).round()],
  );

  test('a late switch moves to the ideal time and keeps the recorded one', () {
    final window = DetectedSwitchWindow(
      gas: ean50,
      startIndex: indexAt(dive, 1630),
      endIndex: indexAt(dive, 1910),
      switchIndex: indexAt(dive, 1910),
    );
    final result = withSwitchesOnTime(
      [seg(0, 0.21), seg(1905, 0.5)],
      [window],
      dive.timestamps,
    );
    // The switch at 1905 lies inside the window and is replaced; the gas
    // then resumes at the window end.
    expect(shape(result).$1, [0, 1630, 1910]);
    expect(shape(result).$2, [21, 50, 50]);
  });

  test('a missed window resumes the recorded gas at its end', () {
    final window = DetectedSwitchWindow(
      gas: ean50,
      startIndex: indexAt(dive, 1630),
      endIndex: indexAt(dive, 2510),
    );
    final result = withSwitchesOnTime(
      [seg(0, 0.21), seg(2540, 1.0)],
      [window],
      dive.timestamps,
    );
    expect(shape(result).$1, [0, 1630, 2510, 2540]);
    expect(shape(result).$2, [21, 50, 21, 100]);
  });

  test('no windows leaves the schedule untouched', () {
    final recorded = [seg(0, 0.21), seg(1690, 0.5)];
    expect(withSwitchesOnTime(recorded, const [], dive.timestamps), recorded);
  });
}
