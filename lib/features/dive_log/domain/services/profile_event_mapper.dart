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

/// Merges auto-detected events with DB-loaded events, deduplicating by
/// (timestamp, eventType).
///
/// When duplicates exist, the auto-detected event (from [autoEvents]) is
/// kept. The result is sorted by timestamp ascending.
List<ProfileEvent> mergeEvents(
  List<ProfileEvent> autoEvents,
  List<ProfileEvent> dbEvents,
) {
  if (dbEvents.isEmpty) return List.of(autoEvents);
  if (autoEvents.isEmpty) {
    final sorted = List.of(dbEvents);
    sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted;
  }

  // Build a set of keys from auto-detected events for deduplication
  final autoKeys = <(int, ProfileEventType)>{};
  for (final event in autoEvents) {
    autoKeys.add((event.timestamp, event.eventType));
  }

  // Start with all auto-detected events, add non-duplicate DB events
  final merged = List<ProfileEvent>.of(autoEvents);
  for (final dbEvent in dbEvents) {
    final key = (dbEvent.timestamp, dbEvent.eventType);
    if (!autoKeys.contains(key)) {
      merged.add(dbEvent);
    }
  }

  merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return merged;
}
