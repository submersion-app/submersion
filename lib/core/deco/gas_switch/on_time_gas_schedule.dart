import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_window_detector.dart';

/// The recorded gas schedule as it would have been had the diver switched on
/// time in every window of [windows]: each window breathes its gas from its
/// first sample, any recorded switch inside it is dropped, and the recorded
/// gas resumes at the window's last sample. Everything outside the windows is
/// as dived.
List<ProfileGasSegment> withSwitchesOnTime(
  List<ProfileGasSegment> recorded,
  List<DetectedSwitchWindow> windows,
  List<int> timestamps,
) {
  var result = [...recorded];
  for (final window in windows) {
    final startTs = timestamps[window.startIndex];
    final endTs = timestamps[window.endIndex];
    final resume = activeSegmentAt(recorded, endTs);
    final kept = [
      for (final s in result)
        if (s.startTimestamp < startTs || s.startTimestamp >= endTs) s,
    ];
    result = [
      ...kept,
      ProfileGasSegment(
        startTimestamp: startTs,
        fN2: window.gas.fN2,
        fHe: window.gas.fHe,
      ),
      if (endTs > startTs && !kept.any((s) => s.startTimestamp == endTs))
        ProfileGasSegment(
          startTimestamp: endTs,
          fN2: resume.fN2,
          fHe: resume.fHe,
        ),
    ]..sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
  }
  return result;
}
