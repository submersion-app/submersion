import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart'
    show SeriesDiveResult;
import 'package:submersion/features/planner/presentation/providers/planned_log_entry.dart';

/// A planned semi-closed dive written to the log keeps the loop flow it was
/// planned with (issue #4660): the plan's own values, or the diver's.
const _ean50 = GasMix(o2: 50);
const _config = PlanEngineConfig();

DivePlanState _state(
  domain.PlanMode mode, {
  double? scrInjectionRate,
  double? scrVo2,
  double? pscrVo2,
}) => DivePlanState(
  id: 'p1',
  name: 'Ray dive',
  mode: mode,
  scrInjectionRate: scrInjectionRate,
  scrVo2: scrVo2,
  pscrVo2: pscrVo2,
  tanks: const [
    DiveTank(
      id: 't1',
      volume: 7,
      startPressure: 200,
      gasMix: _ean50,
      role: TankRole.diluent,
    ),
  ],
  segments: [
    PlanSegment.hold(
      id: 's1',
      depth: 15,
      durationMinutes: 30,
      tankId: 't1',
      gasMix: _ean50,
    ),
  ],
  startDateTime: DateTime.utc(2026, 11, 17, 9),
  createdAt: DateTime(2026, 11, 17),
  updatedAt: DateTime(2026, 11, 17),
);

PlannedLogEntry _entry(DivePlanState state) => PlannedLogEntry.of(
  SeriesDiveResult(
    state: state,
    outcome: const PlanEngine(
      config: _config,
    ).compute(divePlanFromState(state)),
  ),
  name: state.name,
  config: _config,
);

void main() {
  test('an SCR plan logs CMF with its own rate and VO2', () {
    final state = _state(
      domain.PlanMode.scr,
      scrInjectionRate: 7.5,
      scrVo2: 2.0,
    );
    final dive = _entry(state).newDive(state, null);
    expect(dive.scrType, ScrType.cmf);
    expect(dive.scrInjectionRate, 7.5);
    expect(dive.assumedVo2, 2.0);
  });

  test('an SCR plan with nothing entered logs the diver defaults', () {
    final state = _state(domain.PlanMode.scr);
    final dive = _entry(state).newDive(state, null);
    expect(dive.scrInjectionRate, 12.0);
    expect(dive.assumedVo2, 1.3);
  });

  test('a pSCR plan logs passive addition and its VO2, no rate', () {
    final state = _state(domain.PlanMode.pscr);
    final dive = _entry(state).newDive(state, null);
    expect(dive.scrType, ScrType.pascr);
    expect(dive.scrInjectionRate, isNull);
    expect(dive.assumedVo2, 0.72);
  });

  test('an SCR plan with no cylinder flagged diluent logs its loop supply', () {
    // The engine breathes a loop leg's gas as the supply whatever the flag;
    // without it the log has a rate and nothing to inject it from.
    final flagged = _state(domain.PlanMode.scr);
    final state = flagged.copyWith(
      tanks: [flagged.tanks.single.copyWith(role: TankRole.backGas)],
    );
    final dive = _entry(state).newDive(state, null);
    expect(dive.scrType, ScrType.cmf);
    expect(dive.diluentGas, _ean50);
  });

  test('an open-circuit plan logs no loop values', () {
    final state = _state(domain.PlanMode.oc);
    final dive = _entry(state).newDive(state, null);
    expect(dive.scrType, isNull);
    expect(dive.scrInjectionRate, isNull);
    expect(dive.assumedVo2, isNull);
  });

  test('an update rewrites the loop values and clears them off a loop', () {
    final scr = _state(domain.PlanMode.scr, scrVo2: 2.0);
    final logged = _entry(scr).newDive(scr, null);

    final now = _state(domain.PlanMode.scr, scrVo2: 1.5);
    expect(_entry(now).update(logged, now, null).assumedVo2, 1.5);

    final oc = _state(domain.PlanMode.oc);
    final cleared = _entry(oc).update(logged, oc, null);
    expect(cleared.scrType, isNull);
    expect(cleared.scrInjectionRate, isNull);
    expect(cleared.assumedVo2, isNull);
  });

  test('the log is behind once the plan VO2 changes', () {
    final scr = _state(domain.PlanMode.scr, scrVo2: 2.0);
    final entry = _entry(scr);
    final logged = entry.newDive(scr, null);
    expect(entry.matches(logged, entry.profile, scr, null), isTrue);
    expect(
      entry.matches(logged.copyWith(assumedVo2: 1.0), entry.profile, scr, null),
      isFalse,
    );
  });
}
