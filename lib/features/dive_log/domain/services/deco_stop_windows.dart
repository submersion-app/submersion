import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/deco_type.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show DiveProfilePoint;
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// A stretch of a dive, in seconds from its start, that held in the safety
/// stop band while decompression was owed.
typedef DecoStopWindow = ({int start, int end});

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
({List<ProfileEvent> events, List<DecoStopWindow> windows}) splitOutDecoStops(
  List<ProfileEvent> events, {
  required List<DiveProfilePoint> profile,
  required List<int> ndlCurve,
}) {
  final removed = <String>{};
  final windows = <DecoStopWindow>[];
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

/// Whether the diver reached [stop] with decompression still to do. What the
/// computer recorded outranks the curve: some computers run a safety stop
/// after light deco, and the curve can be the app's own model.
bool _owedOnArrival(
  DecoStopWindow stop,
  List<DiveProfilePoint> profile,
  List<int> ndlCurve,
) {
  final arrival = profile.indexWhere((p) => p.timestamp == stop.start);
  if (arrival < 0) return false;
  if (profile[arrival].decoType == kDecoTypeDecoStop) return true;
  final computerSafetyStop = profile.any(
    (p) =>
        p.timestamp >= stop.start &&
        p.timestamp <= stop.end &&
        p.decoType == kDecoTypeSafetyStop,
  );
  if (computerSafetyStop) return false;
  return arrival < ndlCurve.length && ndlCurve[arrival] < 0;
}
