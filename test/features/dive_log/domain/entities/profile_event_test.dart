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
}
