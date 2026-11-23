import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/contingency_service.dart';

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
const _o2 = DiveTank(
  id: 'o2',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 100),
  role: TankRole.deco,
);

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.oc,
  List<DiveTank> tanks = const [_backTank, _ean50, _o2],
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Combined contingency test',
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

  test('nothing selected yields no contingency', () {
    expect(service.contingencyFor(_plan()), isNull);
  });

  test('a single deviation matches its slate variant', () {
    final plan = _plan();
    final combined = service.contingencyFor(plan, deeper: true)!;
    final slate = service.deviationFor(plan, 'deeper')!;

    expect(combined.outcome.runtimeSeconds, slate.outcome.runtimeSeconds);
    expect(combined.outcome.maxDepth, closeTo(65.0, 0.01));
    expect(combined.lostTanks, isEmpty);
  });

  test('+depth and +time together match the slate "both" variant', () {
    final plan = _plan();
    final combined = service.contingencyFor(plan, deeper: true, longer: true)!;
    final both = service.deviationFor(plan, 'both')!;

    expect(combined.outcome.runtimeSeconds, both.outcome.runtimeSeconds);
    expect(combined.outcome.totalDecoSeconds, both.outcome.totalDecoSeconds);
  });

  test('a single lost tank matches its lost-gas schedule', () {
    final plan = _plan();
    final combined = service.contingencyFor(plan, lostTankIds: {'ean50'})!;
    final single = service.lostGasFor(plan, 'ean50')!;

    expect(combined.outcome.runtimeSeconds, single.outcome.runtimeSeconds);
    expect(combined.lostTanks.map((t) => t.id), ['ean50']);
  });

  test('two lost tanks drop both and cost more than either alone', () {
    final plan = _plan();
    final both = service.contingencyFor(plan, lostTankIds: {'ean50', 'o2'})!;
    final ean50Only = service.lostGasFor(plan, 'ean50')!;
    final o2Only = service.lostGasFor(plan, 'o2')!;

    expect(both.plan.tanks.map((t) => t.id), ['back']);
    expect(both.lostTanks.map((t) => t.id), ['ean50', 'o2']);
    expect(
      both.outcome.totalDecoSeconds,
      greaterThan(ean50Only.outcome.totalDecoSeconds),
    );
    expect(
      both.outcome.totalDecoSeconds,
      greaterThan(o2Only.outcome.totalDecoSeconds),
    );
  });

  test('a deviation and a lost tank apply together', () {
    final plan = _plan();
    final combined = service.contingencyFor(
      plan,
      deeper: true,
      longer: true,
      lostTankIds: {'ean50'},
    )!;
    final deviationOnly = service.deviationFor(plan, 'both')!;

    expect(combined.outcome.maxDepth, closeTo(65.0, 0.01));
    expect(combined.plan.tanks.map((t) => t.id), isNot(contains('ean50')));
    expect(
      combined.outcome.totalDecoSeconds,
      greaterThan(deviationOnly.outcome.totalDecoSeconds),
    );
  });

  test('ids that are not losable are ignored', () {
    final plan = _plan();
    // The back gas is never losable, and a removed tank lingers only as a
    // stale id.
    expect(service.contingencyFor(plan, lostTankIds: {'back'}), isNull);
    expect(service.contingencyFor(plan, lostTankIds: {'gone'}), isNull);

    final combined = service.contingencyFor(
      plan,
      lostTankIds: {'gone', 'ean50'},
    )!;
    expect(combined.lostTanks.map((t) => t.id), ['ean50']);
  });

  test('+time is ignored while the plan has no bottom to lengthen', () {
    final noBottom = _plan().copyWith(
      segments: [
        PlanSegment.travel(
          id: 'seg-1',
          fromDepth: 0,
          targetDepth: 40.0,
          tankId: 'back',
          gasMix: _backGas,
          order: 0,
          ratePerMinute: 18.0,
        ),
      ],
    );

    expect(service.contingencyFor(noBottom, longer: true), isNull);
    final deeper = service.contingencyFor(noBottom, deeper: true)!;
    final both = service.contingencyFor(noBottom, deeper: true, longer: true)!;
    expect(both.outcome.runtimeSeconds, deeper.outcome.runtimeSeconds);
  });

  for (final mode in [
    domain.PlanMode.ccr,
    domain.PlanMode.scr,
    domain.PlanMode.pscr,
  ]) {
    test('${mode.name} plans take deviations but no lost gases', () {
      // A loop's lost supply is the bailout solver's job, not a lost gas,
      // even for a cylinder flagged as travel gas.
      final loop = _plan(
        mode: mode,
        tanks: [_backTank, _ean50.copyWith(isTravelGas: true), _o2],
      );

      expect(service.contingencyFor(loop, lostTankIds: {'ean50'}), isNull);
      expect(service.lostGas(loop), isEmpty);
      expect(service.lostGasFor(loop, 'ean50'), isNull);
      final deeper = service.contingencyFor(
        loop,
        deeper: true,
        lostTankIds: {'ean50'},
      )!;
      expect(deeper.lostTanks, isEmpty);
      expect(deeper.plan.tanks.map((t) => t.id), contains('ean50'));
    });
  }

  test('lost gases that would leave nothing to breathe are ignored', () {
    // A travel-flagged back gas is losable too, so every cylinder can be
    // toggled lost; the deviation must survive that.
    final plan = _plan(
      tanks: [_backTank.copyWith(isTravelGas: true), _ean50, _o2],
    );
    final all = {'back', 'ean50', 'o2'};

    expect(service.contingencyFor(plan, lostTankIds: all), isNull);
    final deeper = service.contingencyFor(
      plan,
      deeper: true,
      lostTankIds: all,
    )!;
    expect(deeper.lostTanks, isEmpty);
    expect(deeper.outcome.maxDepth, closeTo(65.0, 0.01));
  });

  test('a plan without segments yields no contingency', () {
    final empty = _plan().copyWith(segments: const []);
    expect(
      service.contingencyFor(empty, deeper: true, lostTankIds: {'ean50'}),
      isNull,
    );
  });
}
