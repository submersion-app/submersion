import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/setpoint_segments.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  ProfileEvent sp(String id, int ts, double value) =>
      ProfileEvent.setpointChange(
        id: id,
        diveId: 'd1',
        timestamp: ts,
        setpoint: value,
        createdAt: now,
      );

  group('buildSetpointSegments', () {
    test('empty events yields empty segments', () {
      expect(buildSetpointSegments([]), isEmpty);
    });

    test('single event yields one open-ended segment', () {
      final segments = buildSetpointSegments([sp('e1', 0, 0.7)]);
      expect(segments.length, 1);
      expect(segments[0].startTimestamp, 0);
      expect(segments[0].endTimestamp, isNull);
      expect(segments[0].setpoint, 0.7);
    });

    test('two events yield two segments with first closed at second', () {
      final segments = buildSetpointSegments([
        sp('e1', 0, 0.7),
        sp('e2', 1500, 1.3),
      ]);
      expect(segments.length, 2);
      expect(segments[0].startTimestamp, 0);
      expect(segments[0].endTimestamp, 1500);
      expect(segments[0].setpoint, 0.7);
      expect(segments[1].startTimestamp, 1500);
      expect(segments[1].endTimestamp, isNull);
      expect(segments[1].setpoint, 1.3);
    });

    test('events out of order are sorted defensively', () {
      final segments = buildSetpointSegments([
        sp('e2', 1500, 1.3),
        sp('e1', 0, 0.7),
      ]);
      expect(segments[0].startTimestamp, 0);
      expect(segments[1].startTimestamp, 1500);
    });

    test('consecutive events with same setpoint are coalesced', () {
      final segments = buildSetpointSegments([
        sp('e1', 0, 0.7),
        sp('e2', 500, 0.7),
        sp('e3', 1500, 1.3),
      ]);
      expect(segments.length, 2);
      expect(segments[0].startTimestamp, 0);
      expect(segments[0].endTimestamp, 1500);
      expect(segments[0].setpoint, 0.7);
      expect(segments[1].setpoint, 1.3);
    });

    test('non-setpointChange events are filtered out', () {
      final bookmark = ProfileEvent.bookmark(
        id: 'b1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
      );
      final segments = buildSetpointSegments([
        sp('e1', 0, 0.7),
        bookmark,
        sp('e2', 1500, 1.3),
      ]);
      expect(segments.length, 2);
    });

    test('setpointChange with null value is filtered out', () {
      final nullValueEvent = ProfileEvent(
        id: 'e_null',
        diveId: 'd1',
        timestamp: 0,
        eventType: ProfileEventType.setpointChange,
        createdAt: now,
        // value intentionally omitted — defaults to null
      );
      expect(buildSetpointSegments([nullValueEvent]), isEmpty);
    });
  });

  group('setpointAt', () {
    test('returns null for timestamp before first segment', () {
      final segments = buildSetpointSegments([sp('e1', 500, 0.7)]);
      expect(setpointAt(segments, 100), isNull);
    });

    test('returns segment setpoint at exact segment start', () {
      final segments = buildSetpointSegments([sp('e1', 500, 0.7)]);
      expect(setpointAt(segments, 500), 0.7);
    });

    test('returns segment setpoint within segment range', () {
      final segments = buildSetpointSegments([
        sp('e1', 0, 0.7),
        sp('e2', 1500, 1.3),
      ]);
      expect(setpointAt(segments, 750), 0.7);
      expect(setpointAt(segments, 1499), 0.7);
      expect(setpointAt(segments, 1500), 1.3);
      expect(setpointAt(segments, 2000), 1.3);
    });

    test('returns last segment setpoint for timestamps past all segments', () {
      final segments = buildSetpointSegments([sp('e1', 500, 1.2)]);
      expect(setpointAt(segments, 10000), 1.2);
    });

    test('empty segments returns null', () {
      expect(setpointAt(const [], 500), isNull);
    });
  });
}
