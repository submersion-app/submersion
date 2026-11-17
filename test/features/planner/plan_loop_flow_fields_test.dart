import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

import '../../helpers/test_database.dart';

/// A plan's own SCR injection rate, SCR VO2 and pSCR VO2 (issue #4660):
/// surface L/min, null meaning "follow the diver's Settings default". Each
/// layer that carries a plan field must carry these, and keep null as null.
const _ean50 = GasMix(o2: 50);

domain.DivePlan _plan({
  double? scrInjectionRate,
  double? scrVo2,
  double? pscrVo2,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Ray plan',
  mode: domain.PlanMode.scr,
  gfLow: 40,
  gfHigh: 80,
  scrInjectionRate: scrInjectionRate,
  scrVo2: scrVo2,
  pscrVo2: pscrVo2,
  tanks: const [
    DiveTank(id: 'tank-1', volume: 7, startPressure: 200, gasMix: _ean50),
  ],
  segments: [
    PlanSegment.hold(
      id: 'seg-1',
      depth: 18,
      durationMinutes: 40,
      tankId: 'tank-1',
      gasMix: _ean50,
    ),
  ],
  createdAt: DateTime(2026, 11, 17),
  updatedAt: DateTime(2026, 11, 17),
);

void main() {
  group('DivePlan', () {
    test('copyWith sets and clears each loop flow field on its own', () {
      final set = _plan().copyWith(scrInjectionRate: 7.5, scrVo2: 2.0);
      expect(set.scrInjectionRate, 7.5);
      expect(set.scrVo2, 2.0);
      expect(set.pscrVo2, isNull);

      final cleared = set.copyWith(clearScrVo2: true, pscrVo2: 0.9);
      expect(cleared.scrInjectionRate, 7.5);
      expect(cleared.scrVo2, isNull);
      expect(cleared.pscrVo2, 0.9);

      expect(
        cleared.copyWith(clearScrInjectionRate: true, clearPscrVo2: true),
        _plan(),
      );
    });

    test('two plans differing only in a loop flow field are not equal', () {
      expect(_plan(scrVo2: 2.0), isNot(_plan()));
      expect(_plan(pscrVo2: 0.9), isNot(_plan()));
      expect(_plan(scrInjectionRate: 7.5), isNot(_plan()));
    });
  });

  group('state mapper', () {
    test('round-trips the loop flow fields through the editor state', () {
      final plan = _plan(scrInjectionRate: 7.5, scrVo2: 2.0, pscrVo2: 0.9);
      final state = stateFromDivePlan(plan);
      expect(state.scrInjectionRate, 7.5);
      expect(state.scrVo2, 2.0);
      expect(state.pscrVo2, 0.9);

      final restored = divePlanFromState(state, existing: plan);
      expect(restored.scrInjectionRate, 7.5);
      expect(restored.scrVo2, 2.0);
      expect(restored.pscrVo2, 0.9);
    });

    test('a field cleared in the editor clears the stored plan', () {
      final plan = _plan(scrInjectionRate: 7.5, scrVo2: 2.0, pscrVo2: 0.9);
      final state = stateFromDivePlan(
        plan,
      ).copyWith(clearScrVo2: true, clearPscrVo2: true);
      final restored = divePlanFromState(state, existing: plan);
      expect(restored.scrInjectionRate, 7.5);
      expect(restored.scrVo2, isNull);
      expect(restored.pscrVo2, isNull);
    });
  });

  group('plan file codec', () {
    test('keeps entered loop flow values', () {
      final restored = subplanFromJson(
        planToSubplanJson(
          _plan(scrInjectionRate: 7.5, scrVo2: 2.0, pscrVo2: 0.9),
        ),
      );
      expect(restored.scrInjectionRate, 7.5);
      expect(restored.scrVo2, 2.0);
      expect(restored.pscrVo2, 0.9);
    });

    test('drops a non-positive loop flow from a file', () {
      final json =
          jsonDecode(
                planToSubplanJson(
                  _plan(scrInjectionRate: 7.5, scrVo2: 2.0, pscrVo2: 0.9),
                ),
              )
              as Map<String, dynamic>;
      final plan = json['plan'] as Map<String, dynamic>;
      plan['scrVo2'] = -1;
      plan['pscrVo2'] = 0;
      final restored = subplanFromJson(jsonEncode(json));
      expect(restored.scrInjectionRate, 7.5);
      expect(restored.scrVo2, isNull);
      expect(restored.pscrVo2, isNull);
    });

    test('drops a non-positive bottom RMV from a file, which the pSCR loop '
        'divides by', () {
      // Zero would give an infinite O2 drop, a negative one a loop richer
      // than its own supply; the plan then follows the diver's RMV.
      for (final bad in [0, -15]) {
        final json =
            jsonDecode(planToSubplanJson(_plan())) as Map<String, dynamic>;
        (json['plan'] as Map<String, dynamic>)['sacBottom'] = bad;
        expect(subplanFromJson(jsonEncode(json)).sacBottom, isNull);
      }
    });

    test('keeps unset loop flow values unset', () {
      final restored = subplanFromJson(planToSubplanJson(_plan()));
      expect(restored.scrInjectionRate, isNull);
      expect(restored.scrVo2, isNull);
      expect(restored.pscrVo2, isNull);
    });
  });

  group('repository', () {
    late DivePlanRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DivePlanRepository();
    });

    tearDown(tearDownTestDatabase);

    test('saves and loads entered loop flow values', () async {
      await repository.savePlan(
        _plan(scrInjectionRate: 7.5, scrVo2: 2.0, pscrVo2: 0.9),
      );
      final loaded = await repository.getPlan('plan-1');
      expect(loaded!.scrInjectionRate, 7.5);
      expect(loaded.scrVo2, 2.0);
      expect(loaded.pscrVo2, 0.9);
    });

    test('a plan following the diver keeps null on reload', () async {
      await repository.savePlan(_plan());
      final loaded = await repository.getPlan('plan-1');
      expect(loaded!.scrInjectionRate, isNull);
      expect(loaded.scrVo2, isNull);
      expect(loaded.pscrVo2, isNull);
    });
  });

  test('DivePlanState defaults the loop flow fields to unset', () {
    final state = DivePlanState(
      id: 'p1',
      name: 'Fresh',
      segments: const [],
      tanks: const [],
      createdAt: DateTime(2026, 11, 17),
      updatedAt: DateTime(2026, 11, 17),
    );
    expect(state.scrInjectionRate, isNull);
    expect(state.scrVo2, isNull);
    expect(state.pscrVo2, isNull);
  });
}
