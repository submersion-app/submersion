import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

void main() {
  test('ProfileSample.shiftedBy moves only the timestamp', () {
    const s = ProfileSample(timestamp: 10, depth: 5.0, temperature: 21.0);
    final t = s.shiftedBy(90);
    expect(t.timestamp, 100);
    expect(t.depth, 5.0);
    expect(t.temperature, 21.0);
    expect(s.timestamp, 10);
  });

  test('TankPressureSample.shiftedBy moves only the timestamp', () {
    const s = TankPressureSample(timestamp: 10, pressure: 200.0);
    final t = s.shiftedBy(-5);
    expect(t.timestamp, 5);
    expect(t.pressure, 200.0);
  });
}
