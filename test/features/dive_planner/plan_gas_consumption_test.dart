import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

void main() {
  test('remaining pressure accounts for compressibility', () {
    final service = PlanCalculatorService(gfLow: 50, gfHigh: 80);
    const gas = GasMix(o2: 21.0, he: 0.0);
    const tank = DiveTank(
      id: 'tank-1',
      volume: 11.1,
      workingPressure: 207.0,
      startPressure: 207.0,
      gasMix: gas,
    );
    final segments = [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: 30.0,
        tankId: 'tank-1',
        gasMix: gas,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: 30.0,
        durationMinutes: 25,
        tankId: 'tank-1',
        gasMix: gas,
        order: 1,
      ),
      PlanSegment.ascent(
        id: 'seg-3',
        fromDepth: 30.0,
        toDepth: 0.0,
        tankId: 'tank-1',
        gasMix: gas,
        order: 2,
      ),
    ];

    final result = service.calculatePlan(
      segments: segments,
      tanks: const [tank],
      sacRate: 16.0,
    );

    final consumption = result.gasConsumptions.first;
    final litersUsed = consumption.gasUsedLiters;
    expect(litersUsed, greaterThan(0));

    // Ideal-gas remaining: start minus liters/volume. Compressibility means
    // the same surface liters cost MORE bar at high pressure, so the real
    // remaining pressure must be LOWER than the ideal figure.
    final idealRemaining = 207.0 - litersUsed / 11.1;
    expect(consumption.remainingPressure, isNotNull);
    expect(consumption.remainingPressure!, lessThan(idealRemaining + 0.01));
    expect(consumption.remainingPressure!, greaterThan(0));
  });
}
