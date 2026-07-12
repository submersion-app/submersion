import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/profile_resampler.dart';

ComparisonProfile p(List<double> t, List<double> d) => ComparisonProfile(
  id: 'a',
  label: 'A',
  color: const Color(0xFF00D4FF),
  times: t,
  depths: d,
  maxDepthMeters: d.fold(0.0, (a, b) => b > a ? b : a),
);

void main() {
  final prof = p(const [0, 60, 120], const [0, 30, 10]);

  test('interpolates between samples', () {
    expect(ProfileResampler.depthAt(prof, 30), closeTo(15, 1e-9));
    expect(ProfileResampler.depthAt(prof, 90), closeTo(20, 1e-9));
  });
  test('clamps before first and after last sample', () {
    expect(ProfileResampler.depthAt(prof, -10), 0);
    expect(ProfileResampler.depthAt(prof, 999), 10);
  });
  test('returns exact sample values on the knots', () {
    expect(ProfileResampler.depthAt(prof, 60), 30);
  });
  test('empty profile yields 0', () {
    expect(ProfileResampler.depthAt(p(const [], const []), 5), 0);
  });
}
