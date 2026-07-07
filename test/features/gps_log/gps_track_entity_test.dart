import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

void main() {
  const track = GpsTrack(
    id: 't1',
    startTime: 1700000000000,
    endTime: 1700003600000,
    tzOffsetMinutes: -300,
    deviceName: 'Phone',
    pointCount: 2,
    points: [
      GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
      GpsTrackPoint(
        timestamp: 1700000100,
        latitude: 3,
        longitude: 4,
        accuracy: 8,
      ),
    ],
  );

  test('copyWith with no arguments preserves every field', () {
    final copy = track.copyWith();
    expect(copy.id, 't1');
    expect(copy.startTime, 1700000000000);
    expect(copy.endTime, 1700003600000);
    expect(copy.tzOffsetMinutes, -300);
    expect(copy.deviceName, 'Phone');
    expect(copy.pointCount, 2);
    expect(copy.points, hasLength(2));
    expect(copy.points.last.accuracy, 8);
  });

  test('copyWith replaces the given fields', () {
    final copy = track.copyWith(
      id: 't2',
      startTime: 1,
      endTime: 2,
      tzOffsetMinutes: 60,
      deviceName: 'Tablet',
      pointCount: 0,
      points: const [],
    );
    expect(copy.id, 't2');
    expect(copy.startTime, 1);
    expect(copy.endTime, 2);
    expect(copy.tzOffsetMinutes, 60);
    expect(copy.deviceName, 'Tablet');
    expect(copy.pointCount, 0);
    expect(copy.points, isEmpty);
  });

  test('constructor defaults are empty-track shaped', () {
    const bare = GpsTrack(id: 'x', startTime: 5);
    expect(bare.endTime, isNull);
    expect(bare.tzOffsetMinutes, 0);
    expect(bare.deviceName, isNull);
    expect(bare.pointCount, 0);
    expect(bare.points, isEmpty);
  });
}
