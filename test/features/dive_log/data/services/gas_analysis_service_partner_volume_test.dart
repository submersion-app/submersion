import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #3109: a cylinder with no volume of its own borrows its matched
/// partner's on the Cylinders card, as the dive overview's RMV does.
void main() {
  const service = GasAnalysisService();

  List<CylinderSacResult> cylinders(List<DiveTank> tanks) {
    // 40 minutes at 20 m, one sample every 10 seconds.
    final profile = [
      for (var t = 0; t <= 40 * 60; t += 10)
        DiveProfilePoint(timestamp: t, depth: 20),
    ];
    final dive = Dive(
      id: 'd',
      dateTime: DateTime(2026, 1, 1),
      runtime: const Duration(minutes: 40),
      avgDepth: 20,
      // A recorded usage per cylinder, as sidemount downloads carry, so
      // every cylinder gets a window without gas switches.
      tanks: [
        for (final t in tanks)
          t.copyWith(usageDuration: const Duration(minutes: 40)),
      ],
    );
    return [
      for (final c in service.calculateCylinderSac(
        dive: dive,
        profile: profile,
      ))
        (volume: c.tankVolume, rmv: c.rmv),
    ];
  }

  test('an unsized sidemount cylinder borrows its partner volume', () {
    final results = cylinders(const [
      DiveTank(
        id: 'l',
        role: TankRole.sidemountLeft,
        volume: 11.1,
        startPressure: 200,
        endPressure: 80,
      ),
      DiveTank(
        id: 'r',
        role: TankRole.sidemountRight,
        startPressure: 200,
        endPressure: 80,
      ),
    ]);
    expect(results[1].volume, 11.1);
    expect(results[1].rmv, closeTo(results[0].rmv!, 1e-9));
  });

  test('an unsized stage stays unsized', () {
    final results = cylinders(const [
      DiveTank(id: 'b', volume: 12, startPressure: 200, endPressure: 80),
      DiveTank(
        id: 's',
        role: TankRole.stage,
        startPressure: 200,
        endPressure: 80,
      ),
    ]);
    expect(results[1].volume, isNull);
    expect(results[1].rmv, isNull);
  });
}

typedef CylinderSacResult = ({double? volume, double? rmv});
