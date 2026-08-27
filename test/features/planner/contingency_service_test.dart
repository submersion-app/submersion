import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _backGas = GasMix(o2: 18, he: 45);
const _backTank = DiveTank(
  id: 'back',
  volume: 24,
  startPressure: 232,
  gasMix: _backGas,
);
const _ean50 = DiveTank(
  id: 'ean50',
  volume: 11.1,
  startPressure: 207,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.oc,
  List<DiveTank> tanks = const [_backTank, _ean50],
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Contingency test',
    mode: mode,
    gfLow: 50,
    gfHigh: 80,
    deviationDepthDelta: 5.0,
    deviationTimeMinutes: 5,
    tanks: tanks,
    segments: [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: 60.0,
        tankId: 'back',
        gasMix: _backGas,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: 60.0,
        durationMinutes: 25,
        tankId: 'back',
        gasMix: _backGas,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  const service = ContingencyService();
  const engine = PlanEngine();

  test('deviations produce deeper, longer, and combined variants', () {
    final base = engine.compute(_plan());
    final deviations = service.deviations(_plan());

    expect(deviations.map((d) => d.key), ['deeper', 'longer', 'both']);
    final deeper = deviations[0];
    final longer = deviations[1];
    final both = deviations[2];

    expect(deeper.outcome.maxDepth, closeTo(65.0, 0.01));
    expect(deeper.outcome.totalDecoSeconds, greaterThan(base.totalDecoSeconds));
    expect(longer.outcome.maxDepth, closeTo(60.0, 0.01));
    expect(longer.outcome.totalDecoSeconds, greaterThan(base.totalDecoSeconds));
    expect(
      both.outcome.totalDecoSeconds,
      greaterThan(deeper.outcome.totalDecoSeconds),
    );
    expect(
      both.outcome.totalDecoSeconds,
      greaterThan(longer.outcome.totalDecoSeconds),
    );
  });

  test('lost EAN50 lengthens deco and removes the gas from the stops', () {
    final base = engine.compute(_plan());
    final lost = service.lostGas(_plan());

    expect(lost, hasLength(1));
    expect(lost.single.tank.id, 'ean50');
    final outcome = lost.single.outcome;
    expect(outcome.totalDecoSeconds, greaterThan(base.totalDecoSeconds));
    for (final stop in outcome.stops.where((s) => s.depthMeters <= 22.0)) {
      expect(stop.gasFO2, isNot(closeTo(0.50, 0.01)));
    }
  });

  test('CCR plans yield no lost-gas outcomes', () {
    expect(service.lostGas(_plan(mode: domain.PlanMode.ccr)), isEmpty);
  });

  test('deviationFor runs a single named variant', () {
    final deeper = service.deviationFor(_plan(), 'deeper');
    expect(deeper, isNotNull);
    expect(deeper!.key, 'deeper');
    expect(deeper.outcome.maxDepth, closeTo(65.0, 0.01));
    expect(service.deviationFor(_plan(), 'longer')!.key, 'longer');
    // Empty plan yields nothing to vary.
    final empty = domain.DivePlan(
      id: 'e',
      name: 'e',
      gfLow: 50,
      gfHigh: 80,
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );
    expect(service.deviationFor(empty, 'deeper'), isNull);
  });

  test('losing a gas remaps user segments that breathed it onto back gas', () {
    // A (contrived) plan whose bottom segment breathes the EAN50 deco tank.
    // Losing EAN50 must remap that segment to back gas, so the contingency
    // does not keep breathing 50% at 60 m (which would be ppO2-critical).
    final plan = domain.DivePlan(
      id: 'plan-x',
      name: 'Segment on deco gas',
      gfLow: 50,
      gfHigh: 80,
      tanks: const [_backTank, _ean50],
      segments: [
        PlanSegment.descent(
          id: 'seg-1',
          targetDepth: 60.0,
          tankId: 'back',
          gasMix: _backGas,
          order: 0,
        ),
        PlanSegment.bottom(
          id: 'seg-2',
          depth: 60.0,
          durationMinutes: 20,
          tankId: 'ean50',
          gasMix: const GasMix(o2: 50),
          order: 1,
        ),
      ],
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );

    final lost = service.lostGas(plan);
    expect(lost, hasLength(1));
    final outcome = lost.single.outcome;
    // Back gas (18/45) at 60 m is safe; EAN50 at 60 m would be ppO2-critical.
    expect(
      outcome.issues.map((i) => i.type),
      isNot(contains(PlanIssueType.ppO2Critical)),
      reason: 'remapped segment should breathe back gas, not the lost EAN50',
    );
  });

  test('a travel-flagged tank gets a lost-gas outcome regardless of role', () {
    // A pony bottle isn't deco/stage, so it wouldn't normally qualify -- but
    // flagging it as travel gas (breathed on the descent) makes losing it a
    // contingency worth planning for too.
    const pony = DiveTank(
      id: 'pony',
      volume: 3.0,
      startPressure: 200,
      gasMix: GasMix(o2: 32),
      role: TankRole.pony,
      isTravelGas: true,
    );
    final plan = _plan(tanks: const [_backTank, _ean50, pony]);

    final lost = service.lostGas(plan);
    expect(lost.map((l) => l.tank.id), containsAll(['ean50', 'pony']));
  });

  test('a non-deco/stage tank without the travel flag is never lost', () {
    const pony = DiveTank(
      id: 'pony',
      volume: 3.0,
      startPressure: 200,
      gasMix: GasMix(o2: 32),
      role: TankRole.pony,
    );
    final plan = _plan(tanks: const [_backTank, pony]);

    expect(service.lostGas(plan), isEmpty);
  });

  test('falls back to the first remaining tank when none is back gas', () {
    // Both carried cylinders are lost-gas-eligible and neither is back gas
    // (an all-travel/deco loadout); losing one must still remap onto
    // whatever is left rather than finding no fallback at all.
    const pony = DiveTank(
      id: 'pony',
      volume: 3.0,
      startPressure: 200,
      gasMix: GasMix(o2: 32),
      role: TankRole.pony,
      isTravelGas: true,
    );
    final plan = domain.DivePlan(
      id: 'plan-no-backgas',
      name: 'No back gas',
      gfLow: 50,
      gfHigh: 80,
      tanks: const [_ean50, pony],
      segments: [
        PlanSegment.descent(
          id: 'seg-1',
          targetDepth: 30.0,
          tankId: 'ean50',
          gasMix: const GasMix(o2: 50),
          order: 0,
        ),
        PlanSegment.bottom(
          id: 'seg-2',
          depth: 30.0,
          durationMinutes: 20,
          tankId: 'ean50',
          gasMix: const GasMix(o2: 50),
          order: 1,
        ),
      ],
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );

    final lost = service.lostGasFor(plan, 'ean50');
    expect(lost, isNotNull);
    expect(lost!.plan.segments.every((s) => s.tankId == 'pony'), isTrue);
  });

  test('losing the only cylinder yields no lost-gas outcome', () {
    final plan = _plan(tanks: const [_ean50]);
    expect(service.lostGas(plan), isEmpty);
  });

  test('no segments yields no deviations', () {
    final empty = domain.DivePlan(
      id: 'p',
      name: 'empty',
      gfLow: 50,
      gfHigh: 80,
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );
    expect(service.deviations(empty), isEmpty);
  });
}
