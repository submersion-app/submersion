import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/deco_type.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show DiveProfilePoint;
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// A hold in the safety stop band, in seconds from the start of the dive.
typedef StopWindow = ({int start, int end});

/// Takes the calculated safety stops that were required decompression out of
/// [events], and returns the windows they covered.
///
/// A stop is decompression when deco was still owed on arriving in the band.
/// An obligation that cleared on the way up leaves a voluntary hold, so that
/// stop stays (issue #4079). A computer's own safety stop event is never
/// touched. Without a stop to remove, [events] is returned as it came.
///
/// [ndlCurve] is the curve the analysis ends up showing, one value per
/// [profile] sample, with a negative value meaning in deco. [events] holds
/// each calculated stop's start before its end, as detection emits them.
({List<ProfileEvent> events, List<StopWindow> windows}) splitOutDecoStops(
  List<ProfileEvent> events, {
  required List<DiveProfilePoint> profile,
  required List<int> ndlCurve,
}) {
  final removed = <String>{};
  final windows = <StopWindow>[];
  ProfileEvent? opened;
  for (final event in events) {
    if (event.source != EventSource.computed) continue;
    if (event.eventType == ProfileEventType.safetyStopStart) {
      opened = event;
    } else if (event.eventType == ProfileEventType.safetyStopEnd &&
        opened != null) {
      final window = (start: opened.timestamp, end: event.timestamp);
      if (_owedOnArrival(window, profile, ndlCurve)) {
        removed.addAll([opened.id, event.id]);
        windows.add(window);
      }
      opened = null;
    }
  }
  if (removed.isEmpty) return (events: events, windows: const []);
  return (
    events: [
      for (final event in events)
        if (!removed.contains(event.id)) event,
    ],
    windows: windows,
  );
}

/// The safety stops [events] carries, whoever recorded them. A start with no
/// end has no window. [events] is sorted by timestamp.
List<StopWindow> safetyStopWindows(List<ProfileEvent> events) {
  final windows = <StopWindow>[];
  int? start;
  for (final event in events) {
    if (event.eventType == ProfileEventType.safetyStopStart) {
      start ??= event.timestamp;
    } else if (event.eventType == ProfileEventType.safetyStopEnd &&
        start != null) {
      windows.add((start: start, end: event.timestamp));
      start = null;
    }
  }
  return windows;
}

/// Whether the sample at [index] reads as in deco. What the computer recorded
/// outranks [ndlCurve], which can be the app's own model.
bool isDecoSample(
  List<DiveProfilePoint> profile,
  List<int> ndlCurve,
  int index,
) {
  final decoType = profile[index].decoType;
  if (decoType == kDecoTypeDecoStop) return true;
  if (decoType == kDecoTypeSafetyStop) return false;
  return index < ndlCurve.length && ndlCurve[index] < 0;
}

/// Whether the diver reached [stop] with decompression still to do. Some
/// computers run a safety stop after light deco, so one anywhere in the hold
/// keeps it unless the computer called the arrival itself a deco stop.
bool _owedOnArrival(
  StopWindow stop,
  List<DiveProfilePoint> profile,
  List<int> ndlCurve,
) {
  final arrival = profile.indexWhere((p) => p.timestamp == stop.start);
  if (arrival < 0) return false;
  final computerSafetyStop = profile
      .skip(arrival)
      .takeWhile((p) => p.timestamp <= stop.end)
      .any((p) => p.decoType == kDecoTypeSafetyStop);
  if (computerSafetyStop && profile[arrival].decoType != kDecoTypeDecoStop) {
    return false;
  }
  return isDecoSample(profile, ndlCurve, arrival);
}
