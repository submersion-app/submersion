import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

const _uuid = Uuid();

/// Converts the `events` maps a file parser emits into [ProfileEvent]s.
///
/// Shared by the first import (`UddfEntityImporter`) and the resync writer
/// (`DiveReimportService`), which must persist the same events from the same
/// file: a second conversion would let the two drift apart, and a resync that
/// interpreted the events differently from the import it replays is a
/// regression the diver sees as events changing type.
///
/// Malformed or unknown entries are skipped rather than raising: parsers gain
/// event types over time, and partial events are forward-compatibility noise.
/// [onSkipped] receives a line for each, for callers that log.
List<ProfileEvent> profileEventsFromParsed({
  required String diveId,
  required Iterable<Map<String, dynamic>> eventMaps,
  required DateTime now,
  void Function(String message)? onSkipped,
}) {
  final events = <ProfileEvent>[];
  for (final m in eventMaps) {
    final eventTypeStr = m['eventType'] as String?;
    if (eventTypeStr == null || eventTypeStr.isEmpty) continue;
    final timestamp = m['timestamp'] as int?;
    if (timestamp == null) continue;
    final value = m['value'] as double?;
    final description = m['description'] as String?;
    switch (eventTypeStr) {
      case 'setpointChange':
        if (value == null) continue;
        events.add(
          ProfileEvent.setpointChange(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamp,
            setpoint: value,
            createdAt: now,
          ),
        );
        break;

      case 'bookmark':
        events.add(
          ProfileEvent.bookmark(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamp,
            note: description,
            createdAt: now,
            // override the `user` factory default
            source: EventSource.imported,
          ),
        );
        break;

      case 'safetyStopStart':
        events.add(
          ProfileEvent.safetyStop(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamp,
            // The parser does not emit depth on event elements; the same
            // placeholder is used across the safety/deco/ascent cases.
            depth: 0.0,
            createdAt: now,
            isStart: true,
            // override the `computed` factory default
            source: EventSource.imported,
          ),
        );
        break;

      case 'decoStopStart':
        events.add(
          ProfileEvent.decoStop(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamp,
            depth: 0.0,
            createdAt: now,
          ),
        );
        break;

      case 'decoViolation':
        events.add(
          ProfileEvent.decoViolation(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamp,
            value: value,
            createdAt: now,
          ),
        );
        break;

      case 'ascentRateWarning':
        if (value == null) {
          onSkipped?.call(
            'Skipping ascentRateWarning event with missing value',
          );
          continue;
        }
        events.add(
          ProfileEvent.ascentRateWarning(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamp,
            depth: 0.0,
            rate: value,
            createdAt: now,
            source: EventSource.imported,
          ),
        );
        break;

      case 'ppO2High':
        if (value == null) {
          onSkipped?.call('Skipping ppO2High event with missing value');
          continue;
        }
        events.add(
          ProfileEvent.ppO2High(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamp,
            value: value,
            createdAt: now,
          ),
        );
        break;

      case 'ppO2Low':
        if (value == null) {
          onSkipped?.call('Skipping ppO2Low event with missing value');
          continue;
        }
        events.add(
          ProfileEvent.ppO2Low(
            id: _uuid.v4(),
            diveId: diveId,
            timestamp: timestamp,
            value: value,
            createdAt: now,
          ),
        );
        break;

      default:
        onSkipped?.call(
          'Skipping unknown profile event type from parser: $eventTypeStr',
        );
        break;
    }
  }
  return events;
}
