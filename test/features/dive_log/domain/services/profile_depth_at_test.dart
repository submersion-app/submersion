import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';

void main() {
  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 60, depth: 10),
    DiveProfilePoint(timestamp: 120, depth: 20),
  ];

  test('empty profile is null', () {
    expect(profileDepthAt(const [], 10), isNull);
  });

  test('a sample time returns that depth', () {
    expect(profileDepthAt(profile, 60), 10);
  });

  test('between samples interpolates', () {
    expect(profileDepthAt(profile, 90), 15);
  });

  test('outside the span is null', () {
    expect(profileDepthAt(profile, 121), isNull);
    expect(profileDepthAt(profile, -1), isNull);
  });
}
