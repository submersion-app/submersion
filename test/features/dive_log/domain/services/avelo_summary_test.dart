import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/avelo_summary.dart';

/// Issue #4664: the Avelo summary reproduces Shearwater Cloud's statistics,
/// which count only samples below the surface.
void main() {
  // Before the dive the computer logs a constant buoyancy and 100% at the
  // surface; those samples must not count.
  const profile = [
    DiveProfilePoint(
      timestamp: 0,
      depth: 0.0,
      aveloBuoyancy: -0.096,
      aveloGasRemaining: 100,
    ),
    DiveProfilePoint(
      timestamp: 10,
      depth: 3.1,
      aveloBuoyancy: -0.320,
      aveloGasRemaining: 97,
    ),
    DiveProfilePoint(
      timestamp: 20,
      depth: 15.0,
      aveloBuoyancy: -0.393,
      aveloGasRemaining: 80,
      computerRmv: 27.91,
    ),
    DiveProfilePoint(
      timestamp: 30,
      depth: 10.0,
      aveloBuoyancy: 1.242,
      aveloGasRemaining: 36,
      computerRmv: 10.68,
    ),
    DiveProfilePoint(
      timestamp: 40,
      depth: 0.0,
      aveloBuoyancy: 1.719,
      aveloGasRemaining: 35,
      computerRmv: 16.95,
    ),
  ];

  const pressures = [
    TankPressurePoint(tankId: 'h', timestamp: 0, pressure: 260.0),
    TankPressurePoint(tankId: 'h', timestamp: 10, pressure: 241.2),
    TankPressurePoint(tankId: 'h', timestamp: 20, pressure: 230.0),
    TankPressurePoint(tankId: 'h', timestamp: 30, pressure: 120.0),
    TankPressurePoint(tankId: 'h', timestamp: 40, pressure: 250.0),
  ];

  test('counts only samples below the surface', () {
    final summary = aveloSummaryOf(profile, pressures)!;
    expect(summary.minBuoyancyKg, -0.393);
    expect(summary.maxBuoyancyKg, 1.242);
    expect(summary.meanBuoyancyKg, closeTo((-0.320 - 0.393 + 1.242) / 3, 1e-9));
    expect(summary.minRmv, 10.68);
    expect(summary.maxRmv, 27.91);
    expect(summary.gasRemainingStart, 97);
    expect(summary.gasRemainingEnd, 36);
  });

  test(
    'the highest Hydrotank pressure is taken at underwater samples only',
    () {
      final summary = aveloSummaryOf(profile, pressures)!;
      expect(summary.maxPressureBar, 241.2);
    },
  );

  test('without Hydrotank pressures the pressure is missing alone', () {
    final summary = aveloSummaryOf(profile, null)!;
    expect(summary.maxPressureBar, isNull);
    expect(summary.minBuoyancyKg, -0.393);
  });

  test('a value no underwater sample carries is missing on its own', () {
    final summary = aveloSummaryOf(const [
      DiveProfilePoint(timestamp: 0, depth: 5.0, aveloGasRemaining: 90),
      DiveProfilePoint(timestamp: 10, depth: 6.0, aveloGasRemaining: 88),
    ], null)!;
    expect(summary.gasRemainingStart, 90);
    expect(summary.gasRemainingEnd, 88);
    expect(summary.minBuoyancyKg, isNull);
    expect(summary.maxBuoyancyKg, isNull);
    expect(summary.meanBuoyancyKg, isNull);
    expect(summary.minRmv, isNull);
    expect(summary.maxRmv, isNull);
  });

  test('a dive that never went below the surface has no summary', () {
    expect(
      aveloSummaryOf(const [
        DiveProfilePoint(
          timestamp: 0,
          depth: 0.0,
          aveloBuoyancy: -0.096,
          aveloGasRemaining: 100,
        ),
      ], pressures),
      isNull,
    );
  });

  test('a dive without Avelo data has no summary', () {
    expect(
      aveloSummaryOf(const [
        DiveProfilePoint(timestamp: 0, depth: 10.0, rbt: 600),
        DiveProfilePoint(timestamp: 10, depth: 12.0),
      ], pressures),
      isNull,
    );
  });

  test('a pressure between samples counts when the sample before it is '
      'underwater', () {
    // Readings logged off the depth samples' times: 15 s follows the
    // underwater sample at 10 s, 45 s follows the surface sample at 40 s.
    const offset = [
      TankPressurePoint(tankId: 'h', timestamp: 5, pressure: 260.0),
      TankPressurePoint(tankId: 'h', timestamp: 15, pressure: 245.0),
      TankPressurePoint(tankId: 'h', timestamp: 25, pressure: 230.0),
      TankPressurePoint(tankId: 'h', timestamp: 45, pressure: 250.0),
    ];
    expect(aveloSummaryOf(profile, offset)!.maxPressureBar, 245.0);
  });
}
