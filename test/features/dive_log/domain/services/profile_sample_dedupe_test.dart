import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/services/profile_sample_dedupe.dart';

void main() {
  test('exact duplicates are dropped, first occurrence kept, order kept', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 1.0),
      ProfileSample(timestamp: 10, depth: 2.0, temperature: 20.0),
      ProfileSample(timestamp: 10, depth: 2.0, temperature: 20.0),
      ProfileSample(timestamp: 20, depth: 3.0),
      ProfileSample(timestamp: 0, depth: 1.0),
    ];
    expect(dedupeExactSamples(samples), [
      const ProfileSample(timestamp: 0, depth: 1.0),
      const ProfileSample(timestamp: 10, depth: 2.0, temperature: 20.0),
      const ProfileSample(timestamp: 20, depth: 3.0),
    ]);
  });

  test('samples that share a timestamp but differ are all kept', () {
    const samples = [
      ProfileSample(timestamp: 10, depth: 2.0),
      ProfileSample(timestamp: 10, depth: 2.5),
      ProfileSample(timestamp: 10, depth: 2.0, temperature: 19.0),
    ];
    expect(dedupeExactSamples(samples), samples);
  });

  test('an empty list stays empty', () {
    expect(dedupeExactSamples(const []), isEmpty);
  });

  test('pressure duplicates are dropped the same way', () {
    const samples = [
      TankPressureSample(timestamp: 0, pressure: 200.0),
      TankPressureSample(timestamp: 0, pressure: 200.0),
      TankPressureSample(timestamp: 5, pressure: 199.0),
    ];
    expect(dedupeExactPressureSamples(samples), [
      const TankPressureSample(timestamp: 0, pressure: 200.0),
      const TankPressureSample(timestamp: 5, pressure: 199.0),
    ]);
  });
}
