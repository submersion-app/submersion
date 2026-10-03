import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveProfileEvent;
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// Maps a Drift [DiveProfileEvent] row to a domain [ProfileEvent].
///
/// Converts string-based eventType and severity fields to their corresponding
/// enum values. Unknown event types default to [ProfileEventType.bookmark],
/// unknown severities default to [EventSeverity.info].
ProfileEvent mapDiveProfileEventToProfileEvent(DiveProfileEvent dbEvent) {
  return ProfileEvent(
    id: dbEvent.id,
    diveId: dbEvent.diveId,
    timestamp: dbEvent.timestamp,
    eventType: _parseEventType(dbEvent.eventType),
    severity: _parseSeverity(dbEvent.severity),
    description: dbEvent.description,
    depth: dbEvent.depth,
    value: dbEvent.value,
    tankId: dbEvent.tankId,
    source: _parseSource(dbEvent.source),
    computerId: dbEvent.computerId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(dbEvent.createdAt),
  );
}

/// Parse a string event type to [ProfileEventType] enum.
///
/// Falls back to [ProfileEventType.bookmark] for unknown values.
ProfileEventType _parseEventType(String eventType) {
  for (final value in ProfileEventType.values) {
    if (value.name == eventType) {
      return value;
    }
  }
  return ProfileEventType.bookmark;
}

/// Parse a string severity to [EventSeverity] enum.
///
/// Falls back to [EventSeverity.info] for unknown values.
EventSeverity _parseSeverity(String severity) {
  for (final value in EventSeverity.values) {
    if (value.name == severity) {
      return value;
    }
  }
  return EventSeverity.info;
}

/// Parse a string source to [EventSource] enum.
///
/// Falls back to [EventSource.imported] for unknown values — this matches
/// the DB column's DEFAULT 'imported' and keeps pre-Slice-C rows and any
/// malformed data interpretable rather than throwing.
EventSource _parseSource(String source) {
  for (final value in EventSource.values) {
    if (value.name == source) {
      return value;
    }
  }
  return EventSource.imported;
}

/// Merges auto-detected events with DB-loaded events, deduplicating by
/// (timestamp, eventType).
///
/// When duplicates exist, the DB event (from [dbEvents]) is kept: it is the
/// computer's own record and can carry its exact label (#1523), and the chart
/// hides computed events by default on a dive that has the computer's, so
/// keeping the computed one would drop the marker entirely.
///
/// [analyzedSource] is set for a per-source analysis and names the computer
/// whose profile [autoEvents] were computed on; its `computerId` is null for
/// a source with no computer (a file import). Only that computer's events
/// (and ones with no computer) then win a tie; another computer's colliding
/// event is kept alongside the computed one, because the chart hides it
/// whenever that computer is not shown. A null [analyzedSource] (a
/// dive-level analysis) lets any DB event win. The result is sorted by
/// timestamp ascending.
List<ProfileEvent> mergeEvents(
  List<ProfileEvent> autoEvents,
  List<ProfileEvent> dbEvents, {
  ({String? computerId})? analyzedSource,
}) {
  if (dbEvents.isEmpty) return List.of(autoEvents);
  if (autoEvents.isEmpty) {
    final sorted = List.of(dbEvents);
    sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted;
  }

  // Build a set of keys from the DB events that win a tie
  final dbKeys = <(int, ProfileEventType)>{
    for (final event in dbEvents)
      if (analyzedSource == null ||
          event.computerId == null ||
          event.computerId == analyzedSource.computerId)
        (event.timestamp, event.eventType),
  };

  // Start with all DB events, add non-duplicate auto-detected events
  final merged = List<ProfileEvent>.of(dbEvents);
  for (final autoEvent in autoEvents) {
    if (!dbKeys.contains((autoEvent.timestamp, autoEvent.eventType))) {
      merged.add(autoEvent);
    }
  }

  merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return merged;
}

/// [events] with [ProfileEvent.computerManufacturer] filled in from each
/// event's computer, looked up once per computer through [manufacturerOf].
/// An event with no computer, or one the lookup does not know, is returned
/// unchanged.
///
/// The manufacturer only refines a marker label, so a lookup that throws
/// leaves that computer's events unstamped rather than failing the events
/// (and the profile analysis that awaits them). The repository lookup logs
/// its own failure.
Future<List<ProfileEvent>> withComputerManufacturers(
  List<ProfileEvent> events,
  Future<String?> Function(String computerId) manufacturerOf,
) async {
  final ids = {
    for (final event in events)
      if (event.computerId != null) event.computerId!,
  }.toList();
  if (ids.isEmpty) return events;
  final found = await Future.wait([
    for (final id in ids)
      manufacturerOf(id).then<String?>((m) => m, onError: (Object _) => null),
  ]);
  final manufacturers = {for (var i = 0; i < ids.length; i++) ids[i]: found[i]};
  return [
    for (final event in events)
      switch (manufacturers[event.computerId]) {
        final String manufacturer => event.copyWith(
          computerManufacturer: manufacturer,
        ),
        null => event,
      },
  ];
}
