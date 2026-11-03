import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_battery_reading.dart';

NavTrackPoint _p(int timestamp, double? volts) => NavTrackPoint(
  timestamp: timestamp,
  north: 0,
  east: 0,
  depth: 0,
  batteryVolts: volts,
);

void main() {
  test('first and last plausible reading, and the change between them', () {
    final reading = NavTrackBatteryReading.of([
      _p(0, 3.9),
      _p(10, 3.85),
      _p(20, 3.78),
    ])!;
    expect(reading.start, 3.9);
    expect(reading.end, 3.78);
    expect(reading.change, closeTo(-0.12, 1e-9));
  });

  test('a leading 0.00V sample is not the start reading (018.DAT.csv)', () {
    final reading = NavTrackBatteryReading.of([
      _p(0, 0),
      _p(1, 3.9),
      _p(200, 3.78),
    ])!;
    expect(reading.start, 3.9);
  });

  test('samples without a reading are skipped at both ends', () {
    final reading = NavTrackBatteryReading.of([
      _p(0, null),
      _p(1, 3.9),
      _p(2, 3.8),
      _p(3, null),
    ])!;
    expect(reading.start, 3.9);
    expect(reading.end, 3.8);
  });

  test('a single reading starts and ends the track with no change', () {
    final reading = NavTrackBatteryReading.of([_p(0, null), _p(1, 3.9)])!;
    expect(reading.start, 3.9);
    expect(reading.end, 3.9);
    expect(reading.change, 0);
  });

  test('no reading at all when every sample is 0V or null', () {
    expect(NavTrackBatteryReading.of([_p(0, null), _p(1, 0)]), isNull);
    expect(NavTrackBatteryReading.of(const []), isNull);
  });
}
