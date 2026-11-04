import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/deco_type.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show DiveProfilePoint;
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// A hold in the safety stop band, in seconds from the start of the dive.
typedef StopWindow = ({int start, int end});

/// Shallower than this, in metres, a diver has left a stop for the surface.
const safetyStopExitShallow = 1.5;

/// Deeper than this, in metres, a diver has descended away from a stop.
const safetyStopExitDeep = 8.0;

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

/// The safety stops in [events] that belong to [analyzedSource] (see
/// [ProfileEvent.countsFor]), since an analysis keeps every computer's events
/// for the chart to filter. [events] is sorted by timestamp.
///
/// Only a calculated stop has an end. Every import writes a computer's stop as
/// a lone start, so a start with no end of its own runs to the end of its hold
/// on [profile].
List<StopWindow> safetyStopWindows(
  List<ProfileEvent> events, {
  required List<DiveProfilePoint> profile,
  ({String? computerId})? analyzedSource,
}) {
  final stops = [
    for (final event in events)
      if (event.countsFor(analyzedSource) &&
          (event.eventType == ProfileEventType.safetyStopStart ||
              event.eventType == ProfileEventType.safetyStopEnd))
        event,
  ];
  final windows = <StopWindow>[];
  for (final (i, stop) in stops.indexed) {
    if (stop.eventType != ProfileEventType.safetyStopStart) continue;
    final next = stops.elementAtOrNull(i + 1);
    windows.add((
      start: stop.timestamp,
      end: next?.eventType == ProfileEventType.safetyStopEnd
          ? next!.timestamp
          : _endOfHold(stop.timestamp, profile),
    ));
  }
  return windows;
}

/// The last sample from [start] before the diver clearly left the hold, by the
/// rule that closes a calculated stop.
int _endOfHold(int start, List<DiveProfilePoint> profile) {
  var end = start;
  for (final point in profile) {
    if (point.timestamp < start) continue;
    if (point.depth < safetyStopExitShallow ||
        point.depth > safetyStopExitDeep) {
      break;
    }
    end = point.timestamp;
  }
  return end;
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
