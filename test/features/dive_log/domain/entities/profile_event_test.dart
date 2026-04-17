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
}
