import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #2930: SAC by cylinder leaves out surface time at the ends of the
/// recording, as the dive's own SAC does, so a single-cylinder dive's row
/// agrees with the headline number.
void main() {
  const service = GasAnalysisService();

  // 30 minutes at 18 m, then 10 minutes logged at the surface, one sample
  // every 10 seconds.
  final profile = [
    for (var t = 0; t <= 40 * 60; t += 10)
      DiveProfilePoint(
        timestamp: t,
        depth: t == 0
            ? 0
            : t < 30 * 60
            ? 18
            : 0.3,
      ),
  ];

  Dive dive(List<DiveProfilePoint> samples) => Dive(
    id: 'd',
    dateTime: DateTime(2026, 1, 1),
    runtime: const Duration(minutes: 40),
    avgDepth: 13.5,
    tanks: const [DiveTank(id: 't', startPressure: 200, endPressure: 110)],
    profile: samples,
  );

  test('a single cylinder agrees with the dive SAC on a surface tail', () {
    final d = dive(profile);
    final rows = service.calculateCylinderSac(dive: d, profile: profile);
    expect(d.gasUse, isNotNull);
    expect(rows.single.sacRate, closeTo(d.sac!, 1e-9));
    expect(rows.single.usageDuration, Duration(seconds: d.gasUse!.seconds));
  });

  test('a zero runtime ends the cylinder at the end of the window', () {
    // A runtime stored as zero says nothing about when the dive ended, so
    // the window's own end stands in rather than cutting the cylinder to
    // nothing.
    final d = dive(profile).copyWith(runtime: Duration.zero);
    final rows = service.calculateCylinderSac(dive: d, profile: profile);
    expect(d.gasUse, isNotNull);
    expect(rows.single.usageDuration, Duration(seconds: d.gasUse!.seconds));
    expect(rows.single.sacRate, isNotNull);
  });

  test('a dive with no surface tail is unchanged', () {
    final noTail = [
      for (final p in profile)
        if (p.timestamp <= 30 * 60) p,
    ];
    final d = dive(noTail).copyWith(runtime: const Duration(minutes: 30));
    final rows = service.calculateCylinderSac(dive: d, profile: noTail);
    expect(d.gasUse, isNull);
    expect(rows.single.usageDuration, const Duration(minutes: 30));
  });
}
