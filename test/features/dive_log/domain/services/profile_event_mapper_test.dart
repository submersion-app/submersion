import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveProfileEvent;
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';

void main() {
  group('mapDiveProfileEventToProfileEvent source field', () {
    test('reads source=imported from DB row', () {
      const dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: 'setpointChange',
        severity: 'info',
        description: null,
        depth: null,
        value: 1.2,
        tankId: null,
        source: 'imported',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(domain.source, EventSource.imported);
      expect(domain.eventType, ProfileEventType.setpointChange);
      expect(domain.value, 1.2);
    });

    test('reads source=computed from DB row', () {
      const dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: 'ascentRateWarning',
        severity: 'warning',
        description: null,
        depth: null,
        value: 18.0,
        tankId: null,
        source: 'computed',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(domain.source, EventSource.computed);
    });

    test('reads source=user from DB row', () {
      const dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: 'bookmark',
        severity: 'info',
        description: 'interesting moment',
        depth: 20.0,
        value: null,
        tankId: null,
        source: 'user',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(domain.source, EventSource.user);
      expect(domain.description, 'interesting moment');
    });

    test('unknown source string falls back to imported', () {
      const dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: 'bookmark',
        severity: 'info',
        description: null,
        depth: null,
        value: null,
        tankId: null,
        source: 'gibberish',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(domain.source, EventSource.imported);
    });

    test('roundtrip: computed event from DB preserves source', () {
      const dbEvent = DiveProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 500,
        eventType: 'ascentRateCritical',
        severity: 'alert',
        description: null,
        depth: 5.0,
        value: 22.0,
        tankId: null,
        source: 'computed',
        createdAt: 1700000000000,
      );
      final domain = mapDiveProfileEventToProfileEvent(dbEvent);
      expect(
        domain.source,
        EventSource.computed,
        reason: 'DB source=computed must NOT default to imported on read',
      );
    });
  });
}
