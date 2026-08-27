import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  group('ProfileEvent source field', () {
    test('setpointChange defaults to EventSource.imported', () {
      final e = ProfileEvent.setpointChange(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        setpoint: 1.2,
        createdAt: now,
      );
      expect(e.source, EventSource.imported);
    });

    test('gasSwitch defaults to EventSource.imported', () {
      final e = ProfileEvent.gasSwitch(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 10.0,
        tankId: 't1',
        createdAt: now,
      );
      expect(e.source, EventSource.imported);
    });

    test('bookmark defaults to EventSource.user', () {
      final e = ProfileEvent.bookmark(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
      );
      expect(e.source, EventSource.user);
    });

    test('ascentRateWarning defaults to EventSource.computed', () {
      final e = ProfileEvent.ascentRateWarning(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 10.0,
        rate: 18.0,
        createdAt: now,
      );
      expect(e.source, EventSource.computed);
    });

    test('maxDepth defaults to EventSource.computed', () {
      final e = ProfileEvent.maxDepth(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 30.0,
        createdAt: now,
      );
      expect(e.source, EventSource.computed);
    });

    test('safetyStop defaults to EventSource.computed', () {
      final e = ProfileEvent.safetyStop(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 5.0,
        createdAt: now,
      );
      expect(e.source, EventSource.computed);
    });

    test('ascentStart defaults to EventSource.computed', () {
      final e = ProfileEvent.ascentStart(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
      );
      expect(e.source, EventSource.computed);
    });

    test('explicit source overrides factory default', () {
      final e = ProfileEvent.ascentRateWarning(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 10.0,
        rate: 18.0,
        createdAt: now,
        source: EventSource.imported,
      );
      expect(e.source, EventSource.imported);
    });

    test('source is part of equality', () {
      final imported = ProfileEvent.bookmark(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
        source: EventSource.imported,
      );
      final user = ProfileEvent.bookmark(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
      );
      expect(imported == user, isFalse);
    });
  });

  group('ProfileEvent new factories (Slice C.2)', () {
    final now = DateTime.utc(2026, 1, 1);

    test('decoStop defaults to decoStopStart with source=imported', () {
      final e = ProfileEvent.decoStop(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 6.0,
        createdAt: now,
      );
      expect(e.eventType, ProfileEventType.decoStopStart);
      expect(e.source, EventSource.imported);
      expect(e.depth, 6.0);
    });

    test('decoStop isStart=false produces decoStopEnd', () {
      final e = ProfileEvent.decoStop(
        id: 'e1',
        diveId: 'd1',
        timestamp: 500,
        depth: 3.0,
        createdAt: now,
        isStart: false,
      );
      expect(e.eventType, ProfileEventType.decoStopEnd);
    });

    test('decoViolation defaults to alert severity + source=imported', () {
      final e = ProfileEvent.decoViolation(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        value: 18.0,
        createdAt: now,
      );
      expect(e.eventType, ProfileEventType.decoViolation);
      expect(e.severity, EventSeverity.alert);
      expect(e.source, EventSource.imported);
      expect(e.value, 18.0);
    });

    test('ppO2High defaults to warning severity + source=imported', () {
      final e = ProfileEvent.ppO2High(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        value: 1.65,
        createdAt: now,
      );
      expect(e.eventType, ProfileEventType.ppO2High);
      expect(e.severity, EventSeverity.warning);
      expect(e.source, EventSource.imported);
      expect(e.value, 1.65);
    });

    test('ppO2Low defaults to warning severity + source=imported', () {
      final e = ProfileEvent.ppO2Low(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        value: 0.15,
        createdAt: now,
      );
      expect(e.eventType, ProfileEventType.ppO2Low);
      expect(e.severity, EventSeverity.warning);
      expect(e.source, EventSource.imported);
      expect(e.value, 0.15);
    });

    test('explicit source overrides factory default on new factories', () {
      final dv = ProfileEvent.decoViolation(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
        source: EventSource.computed,
      );
      expect(dv.source, EventSource.computed);
    });
  });

  // Task 11: computerId attributes an event to the dive computer that
  // logged it, so the profile chart can filter events by the toggle bar.
  group('ProfileEvent computerId field', () {
    test('defaults to null', () {
      final e = ProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: ProfileEventType.bookmark,
        createdAt: now,
      );
      expect(e.computerId, isNull);
    });

    test('constructor round-trips computerId', () {
      final e = ProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: ProfileEventType.bookmark,
        computerId: 'comp-uuid-1',
        createdAt: now,
      );
      expect(e.computerId, 'comp-uuid-1');
    });

    test('copyWith updates computerId while leaving other fields intact', () {
      final e = ProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: ProfileEventType.bookmark,
        computerId: 'comp-uuid-1',
        createdAt: now,
      );
      final copy = e.copyWith(computerId: 'comp-uuid-2');
      expect(copy.computerId, 'comp-uuid-2');
      expect(copy.timestamp, 100);
    });

    test('copyWith without computerId preserves the existing value', () {
      final e = ProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: ProfileEventType.bookmark,
        computerId: 'comp-uuid-1',
        createdAt: now,
      );
      final copy = e.copyWith(timestamp: 200);
      expect(copy.computerId, 'comp-uuid-1');
    });

    test('equality and props include computerId', () {
      final a = ProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: ProfileEventType.bookmark,
        computerId: 'comp-uuid-1',
        createdAt: now,
      );
      final b = ProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: ProfileEventType.bookmark,
        computerId: 'comp-uuid-1',
        createdAt: now,
      );
      final c = ProfileEvent(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        eventType: ProfileEventType.bookmark,
        computerId: 'comp-uuid-2',
        createdAt: now,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
