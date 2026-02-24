import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveProfileEvent;
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';

void main() {
  group('mapDiveProfileEventToProfileEvent', () {
    test('maps known event type strings to correct ProfileEventType', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-1',
        diveId: 'dive-1',
        timestamp: 120,
        eventType: 'safetyStopStart',
        severity: 'info',
        description: 'Safety stop',
        depth: 5.0,
        value: null,
        tankId: null,
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);

      expect(result.id, 'evt-1');
      expect(result.diveId, 'dive-1');
      expect(result.timestamp, 120);
      expect(result.eventType, ProfileEventType.safetyStopStart);
      expect(result.severity, EventSeverity.info);
      expect(result.description, 'Safety stop');
      expect(result.depth, 5.0);
      expect(result.value, isNull);
      expect(result.tankId, isNull);
    });

    test('maps decoStopStart event type', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-2',
        diveId: 'dive-1',
        timestamp: 300,
        eventType: 'decoStopStart',
        severity: 'info',
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.eventType, ProfileEventType.decoStopStart);
    });

    test('maps decoViolation event type with alert severity', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-3',
        diveId: 'dive-1',
        timestamp: 400,
        eventType: 'decoViolation',
        severity: 'alert',
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.eventType, ProfileEventType.decoViolation);
      expect(result.severity, EventSeverity.alert);
    });

    test('maps gasSwitch event type with tankId', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-4',
        diveId: 'dive-1',
        timestamp: 500,
        eventType: 'gasSwitch',
        severity: 'info',
        tankId: 'tank-2',
        depth: 21.0,
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.eventType, ProfileEventType.gasSwitch);
      expect(result.tankId, 'tank-2');
      expect(result.depth, 21.0);
    });

    test('maps bookmark event type', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-5',
        diveId: 'dive-1',
        timestamp: 600,
        eventType: 'bookmark',
        severity: 'info',
        description: 'Saw turtle',
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.eventType, ProfileEventType.bookmark);
      expect(result.description, 'Saw turtle');
    });

    test('maps ascentRateWarning event type with warning severity', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-6',
        diveId: 'dive-1',
        timestamp: 700,
        eventType: 'ascentRateWarning',
        severity: 'warning',
        value: 12.5,
        depth: 15.0,
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.eventType, ProfileEventType.ascentRateWarning);
      expect(result.severity, EventSeverity.warning);
      expect(result.value, 12.5);
    });

    test('maps ppO2High event type', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-7',
        diveId: 'dive-1',
        timestamp: 800,
        eventType: 'ppO2High',
        severity: 'alert',
        value: 1.6,
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.eventType, ProfileEventType.ppO2High);
      expect(result.severity, EventSeverity.alert);
      expect(result.value, 1.6);
    });

    test('maps unknown event type to bookmark', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-8',
        diveId: 'dive-1',
        timestamp: 900,
        eventType: 'unknownEventType',
        severity: 'info',
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.eventType, ProfileEventType.bookmark);
    });

    test('maps unknown severity to info', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-9',
        diveId: 'dive-1',
        timestamp: 1000,
        eventType: 'bookmark',
        severity: 'unknownSeverity',
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.severity, EventSeverity.info);
    });

    test('maps warning severity string', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-10',
        diveId: 'dive-1',
        timestamp: 1100,
        eventType: 'bookmark',
        severity: 'warning',
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.severity, EventSeverity.warning);
    });

    test('maps alert severity string', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-11',
        diveId: 'dive-1',
        timestamp: 1200,
        eventType: 'bookmark',
        severity: 'alert',
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(result.severity, EventSeverity.alert);
    });

    test('converts createdAt from epoch milliseconds to DateTime', () {
      const dbEvent = DiveProfileEvent(
        id: 'evt-12',
        diveId: 'dive-1',
        timestamp: 0,
        eventType: 'bookmark',
        severity: 'info',
        createdAt: 1700000000000,
      );

      final result = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(
        result.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('maps all known ProfileEventType enum values', () {
      // Verify that all enum values that exist in the DB can be mapped
      final knownTypes = [
        'descentStart',
        'descentEnd',
        'ascentStart',
        'safetyStopStart',
        'safetyStopEnd',
        'decoStopStart',
        'decoStopEnd',
        'gasSwitch',
        'maxDepth',
        'ascentRateWarning',
        'ascentRateCritical',
        'decoViolation',
        'missedStop',
        'lowGas',
        'cnsWarning',
        'cnsCritical',
        'ppO2High',
        'ppO2Low',
        'setpointChange',
        'bookmark',
        'alert',
        'note',
      ];

      for (final typeName in knownTypes) {
        final dbEvent = DiveProfileEvent(
          id: 'evt-$typeName',
          diveId: 'dive-1',
          timestamp: 0,
          eventType: typeName,
          severity: 'info',
          createdAt: 1700000000000,
        );

        final result = mapDiveProfileEventToProfileEvent(dbEvent);
        // Should map to the matching enum value, not fallback to bookmark
        expect(
          result.eventType.name,
          typeName,
          reason: 'Failed to map event type: $typeName',
        );
      }
    });
  });

  group('mergeEvents', () {
    final now = DateTime.now();

    test('returns empty list when both inputs are empty', () {
      final result = mergeEvents([], []);
      expect(result, isEmpty);
    });

    test('returns auto-detected events when DB events are empty', () {
      final autoEvents = [
        ProfileEvent(
          id: 'auto-1',
          diveId: 'dive-1',
          timestamp: 100,
          eventType: ProfileEventType.maxDepth,
          createdAt: now,
        ),
      ];

      final result = mergeEvents(autoEvents, []);
      expect(result.length, 1);
      expect(result.first.id, 'auto-1');
    });

    test('returns DB events when auto-detected events are empty', () {
      final dbEvents = [
        ProfileEvent(
          id: 'db-1',
          diveId: 'dive-1',
          timestamp: 200,
          eventType: ProfileEventType.bookmark,
          createdAt: now,
        ),
      ];

      final result = mergeEvents([], dbEvents);
      expect(result.length, 1);
      expect(result.first.id, 'db-1');
    });

    test('merges events from both sources', () {
      final autoEvents = [
        ProfileEvent(
          id: 'auto-1',
          diveId: 'dive-1',
          timestamp: 100,
          eventType: ProfileEventType.maxDepth,
          createdAt: now,
        ),
      ];
      final dbEvents = [
        ProfileEvent(
          id: 'db-1',
          diveId: 'dive-1',
          timestamp: 200,
          eventType: ProfileEventType.bookmark,
          createdAt: now,
        ),
      ];

      final result = mergeEvents(autoEvents, dbEvents);
      expect(result.length, 2);
    });

    test('deduplicates by (timestamp, eventType), keeping auto-detected', () {
      final autoEvents = [
        ProfileEvent(
          id: 'auto-1',
          diveId: 'dive-1',
          timestamp: 120,
          eventType: ProfileEventType.safetyStopStart,
          severity: EventSeverity.info,
          createdAt: now,
        ),
      ];
      final dbEvents = [
        ProfileEvent(
          id: 'db-1',
          diveId: 'dive-1',
          timestamp: 120,
          eventType: ProfileEventType.safetyStopStart,
          severity: EventSeverity.info,
          createdAt: now,
        ),
      ];

      final result = mergeEvents(autoEvents, dbEvents);
      expect(result.length, 1);
      // Auto-detected event is kept (first one wins)
      expect(result.first.id, 'auto-1');
    });

    test('keeps both when same timestamp but different eventType', () {
      final autoEvents = [
        ProfileEvent(
          id: 'auto-1',
          diveId: 'dive-1',
          timestamp: 120,
          eventType: ProfileEventType.safetyStopStart,
          createdAt: now,
        ),
      ];
      final dbEvents = [
        ProfileEvent(
          id: 'db-1',
          diveId: 'dive-1',
          timestamp: 120,
          eventType: ProfileEventType.bookmark,
          createdAt: now,
        ),
      ];

      final result = mergeEvents(autoEvents, dbEvents);
      expect(result.length, 2);
    });

    test('keeps both when same eventType but different timestamp', () {
      final autoEvents = [
        ProfileEvent(
          id: 'auto-1',
          diveId: 'dive-1',
          timestamp: 100,
          eventType: ProfileEventType.ascentRateWarning,
          createdAt: now,
        ),
      ];
      final dbEvents = [
        ProfileEvent(
          id: 'db-1',
          diveId: 'dive-1',
          timestamp: 200,
          eventType: ProfileEventType.ascentRateWarning,
          createdAt: now,
        ),
      ];

      final result = mergeEvents(autoEvents, dbEvents);
      expect(result.length, 2);
    });

    test('sorts merged events by timestamp', () {
      final autoEvents = [
        ProfileEvent(
          id: 'auto-1',
          diveId: 'dive-1',
          timestamp: 300,
          eventType: ProfileEventType.maxDepth,
          createdAt: now,
        ),
      ];
      final dbEvents = [
        ProfileEvent(
          id: 'db-1',
          diveId: 'dive-1',
          timestamp: 100,
          eventType: ProfileEventType.bookmark,
          createdAt: now,
        ),
        ProfileEvent(
          id: 'db-2',
          diveId: 'dive-1',
          timestamp: 500,
          eventType: ProfileEventType.gasSwitch,
          createdAt: now,
        ),
      ];

      final result = mergeEvents(autoEvents, dbEvents);
      expect(result.length, 3);
      expect(result[0].timestamp, 100);
      expect(result[1].timestamp, 300);
      expect(result[2].timestamp, 500);
    });

    test('deduplicates multiple overlapping events correctly', () {
      final autoEvents = [
        ProfileEvent(
          id: 'auto-1',
          diveId: 'dive-1',
          timestamp: 100,
          eventType: ProfileEventType.safetyStopStart,
          createdAt: now,
        ),
        ProfileEvent(
          id: 'auto-2',
          diveId: 'dive-1',
          timestamp: 200,
          eventType: ProfileEventType.ascentRateWarning,
          createdAt: now,
        ),
        ProfileEvent(
          id: 'auto-3',
          diveId: 'dive-1',
          timestamp: 300,
          eventType: ProfileEventType.maxDepth,
          createdAt: now,
        ),
      ];
      final dbEvents = [
        ProfileEvent(
          id: 'db-1',
          diveId: 'dive-1',
          timestamp: 100,
          eventType: ProfileEventType.safetyStopStart, // duplicate
          createdAt: now,
        ),
        ProfileEvent(
          id: 'db-2',
          diveId: 'dive-1',
          timestamp: 150,
          eventType: ProfileEventType.bookmark, // unique
          createdAt: now,
        ),
        ProfileEvent(
          id: 'db-3',
          diveId: 'dive-1',
          timestamp: 200,
          eventType: ProfileEventType.ascentRateWarning, // duplicate
          createdAt: now,
        ),
      ];

      final result = mergeEvents(autoEvents, dbEvents);
      // 3 auto + 1 unique DB = 4 (2 DB events are duplicates)
      expect(result.length, 4);
      expect(result.map((e) => e.timestamp).toList(), [100, 150, 200, 300]);
    });
  });
}
