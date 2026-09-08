import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
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
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: 60.0,
        tankId: 'back',
        gasMix: _backGas,
        order: 0,
        ratePerMinute: 18.0,
      ),
      PlanSegment.hold(
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
    // A travel gas breathed down to 30 m, then back gas to 60 m. Losing the
    // travel gas must remap its segment onto back gas rather than leave the
    // contingency breathing a cylinder that is not there.
    //
    // This used to be written with the bottom segment breathing the EAN50
    // deco bottle, which is no longer expressible: the cylinder the deepest
    // leg breathes *is* the back gas by derivation, so that fixture asserted
    // a contradiction.
    const travel = DiveTank(
      id: 'travel',
      volume: 11.1,
      startPressure: 200,
      gasMix: GasMix(o2: 32),
      isTravelGas: true,
    );
    final plan = domain.DivePlan(
      id: 'plan-x',
      name: 'Travel gas on the descent',
      gfLow: 50,
      gfHigh: 80,
      tanks: const [_backTank, travel],
      segments: [
        PlanSegment.travel(
          id: 'seg-1',
          fromDepth: 0,
          targetDepth: 30.0,
          tankId: 'travel',
          gasMix: const GasMix(o2: 32),
          order: 0,
          ratePerMinute: 18.0,
        ),
        PlanSegment.travel(
          id: 'seg-2',
          fromDepth: 30.0,
          targetDepth: 60.0,
          tankId: 'back',
          gasMix: _backGas,
          order: 1,
          ratePerMinute: 18.0,
        ),
        PlanSegment.hold(
          id: 'seg-3',
          depth: 60.0,
          durationMinutes: 20,
          tankId: 'back',
          gasMix: _backGas,
          order: 2,
        ),
      ],
      createdAt: DateTime(2026, 7, 5),
      updatedAt: DateTime(2026, 7, 5),
    );

    final lost = service.lostGasFor(plan, 'travel');
    expect(lost, isNotNull);
    expect(
      lost!.plan.segments.every((seg) => seg.tankId == 'back'),
      isTrue,
      reason: 'the segment on the lost travel gas should fall back to back gas',
    );
    // 32% at 30 m is fine, but the point is that nothing still breathes a
    // cylinder the diver no longer has.
    expect(lost.plan.tanks.map((t) => t.id), ['back']);
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

  test('every carried cylinder except the back gas is losable', () {
    // Roles are derived now, so a cylinder cannot be declared "pony" to
    // exempt it: a 32% bottle carried alongside an 18/45 bottom mix is a
    // deco/stage bottle by the numbers, and losing it is worth planning for.
    // This is a deliberate widening - the old declared-role version returned
    // no contingency at all here.
    const pony = DiveTank(
      id: 'pony',
      volume: 3.0,
      startPressure: 200,
      gasMix: GasMix(o2: 32),
    );
    final plan = _plan(tanks: const [_backTank, pony]);

    expect(service.lostGas(plan).map((l) => l.tank.id), ['pony']);
  });

  test('the cylinder the bottom breathes is never offered as lost', () {
    // It is the back gas by derivation, and it is the fallback everything
    // else remaps onto, so losing it is not a contingency this models.
    final plan = _plan(tanks: const [_backTank, _ean50]);

    expect(service.lostGasFor(plan, 'back'), isNull);
    expect(
      service.lostGas(plan).map((l) => l.tank.id),
      isNot(contains('back')),
    );
  });

  test('a plan always has a back gas to fall back onto', () {
    // This used to cover an "all-travel/deco loadout" with no back gas at
    // all. Derivation makes that unreachable: whichever cylinder the deepest
    // leg breathes is the back gas, so the fallback search always finds one
    // and the old orElse-first-remaining path is now defensive only.
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
        PlanSegment.travel(
          id: 'seg-1',
          fromDepth: 0,
          targetDepth: 30.0,
          tankId: 'ean50',
          gasMix: const GasMix(o2: 50),
          order: 0,
          ratePerMinute: 18.0,
        ),
        PlanSegment.hold(
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

    // The deepest leg breathes ean50, so ean50 is the back gas and is not
    // itself losable; the pony is.
    expect(service.lostGasFor(plan, 'ean50'), isNull);
    final lost = service.lostGasFor(plan, 'pony');
    expect(lost, isNotNull);
    expect(lost!.plan.segments.every((s) => s.tankId == 'ean50'), isTrue);
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
