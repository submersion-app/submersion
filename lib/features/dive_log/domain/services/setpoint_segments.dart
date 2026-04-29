import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// A contiguous time range during which a single CCR setpoint was active.
///
/// Built from a stream of `setpointChange` events via [buildSetpointSegments].
/// [endTimestamp] is exclusive — equal to the next segment's [startTimestamp],
/// or null for the final (open-ended) segment.
class SetpointSegment extends Equatable {
  final int startTimestamp;
  final int? endTimestamp;
  final double setpoint;

  const SetpointSegment({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.setpoint,
  });

  /// Returns true if [t] falls within this segment.
  ///
  /// Start is inclusive, end is exclusive — this matches segment-adjacency
  /// convention so the event at a boundary timestamp is attributed to the
  /// new segment, not the closing one.
  bool containsTimestamp(int t) =>
      t >= startTimestamp && (endTimestamp == null || t < endTimestamp!);

  @override
  List<Object?> get props => [startTimestamp, endTimestamp, setpoint];
}

/// Builds a list of setpoint segments from a list of profile events.
///
/// Filters to `setpointChange` events, sorts defensively by timestamp,
/// and coalesces consecutive events that repeat the same setpoint value.
///
/// If two `setpointChange` events share the same timestamp, their relative
/// ordering after sort is unspecified (Dart `List.sort` is not guaranteed
/// stable); only one will form the active segment. This is acceptable because
/// dive computers do not produce two SP-change events at the same second.
///
/// Returns an empty list when the input contains no setpointChange events.
/// The final segment is open-ended ([endTimestamp] is null).
List<SetpointSegment> buildSetpointSegments(List<ProfileEvent> events) {
  final setpointEvents =
      events
          .where(
            (e) =>
                e.eventType == ProfileEventType.setpointChange &&
                e.value != null,
          )
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  if (setpointEvents.isEmpty) return const [];

  final raw = <SetpointSegment>[];
  for (var i = 0; i < setpointEvents.length; i++) {
    final current = setpointEvents[i];
    final nextTs = i + 1 < setpointEvents.length
        ? setpointEvents[i + 1].timestamp
        : null;
    raw.add(
      SetpointSegment(
        startTimestamp: current.timestamp,
        endTimestamp: nextTs,
        setpoint: current.value!,
      ),
    );
  }

  final coalesced = <SetpointSegment>[];
  for (final segment in raw) {
    // Exact equality is intentional: both values originate from string-parsed
    // sources (UDDF / SSRF `double.tryParse`), so bit-identical doubles indicate
    // a genuine duplicate event. Any future importer that derives setpoint via
    // arithmetic (e.g., unit conversion) will need an epsilon comparison here.
    if (coalesced.isNotEmpty && coalesced.last.setpoint == segment.setpoint) {
      final prev = coalesced.removeLast();
      coalesced.add(
        SetpointSegment(
          startTimestamp: prev.startTimestamp,
          endTimestamp: segment.endTimestamp,
          setpoint: prev.setpoint,
        ),
      );
    } else {
      coalesced.add(segment);
    }
  }

  return coalesced;
}

/// Returns the active setpoint at [timestamp], or null if no segment
/// covers that time.
///
/// For timestamps earlier than the first segment's start, returns null
/// (no event has fired yet, so setpoint is undefined).
double? setpointAt(List<SetpointSegment> segments, int timestamp) {
  for (final segment in segments) {
    if (segment.containsTimestamp(timestamp)) return segment.setpoint;
  }
  return null;
}
