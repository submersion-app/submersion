import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_issue_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';

const _air = GasMix(o2: 21);
const _hypoxic = GasMix(o2: 10, he: 70);

const _diluent = DiveTank(
  id: 'dil',
  gasMix: _air,
  role: TankRole.diluent,
  volume: 3,
  startPressure: 200,
);
const _loopO2 = DiveTank(
  id: 'loopO2',
  gasMix: GasMix(o2: 100),
  role: TankRole.oxygenSupply,
  volume: 3,
  startPressure: 200,
);
const _tx1070 = DiveTank(
  id: 'tx',
  gasMix: _hypoxic,
  role: TankRole.bailout,
  volume: 11,
  startPressure: 200,
);

DiveTank _ean50({double? modMeters}) => DiveTank(
  id: 'ean50',
  gasMix: const GasMix(o2: 50),
  role: TankRole.bailout,
  volume: 7,
  startPressure: 200,
  decoSwitchDepth: modMeters,
);

domain.DivePlan _plan({
  List<DiveTank> bailouts = const [_tx1070],
  domain.PlanMode mode = domain.PlanMode.ccr,
  double depth = 20,
}) => domain.DivePlan(
  id: 'p',
  name: 'Hypoxic bailout',
  mode: mode,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  gfLow: 30,
  gfHigh: 70,
  problemSolvingMinutes: 0,
  tanks: [_diluent, _loopO2, ...bailouts],
  segments: [
    PlanSegment.travel(
      id: 'down',
      fromDepth: 0,
      targetDepth: depth,
      ratePerMinute: 18,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: 5,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

Iterable<PlanIssue> _warnings(PlanOutcome outcome) =>
    outcome.issues.where((i) => i.type == PlanIssueType.bailoutGasHypoxic);

void main() {
  const engine = PlanEngine(config: PlanEngineConfig(gasModel: GasModel.ideal));

  group('PlanEngine bailoutGasHypoxic (issue #4008)', () {
    test('warns when the only bailout gas cannot reach the surface, without '
        'blocking a plan that never breathes it', () {
      final outcome = engine.compute(_plan());

      final issue = _warnings(outcome).single;
      expect(issue.severity, PlanIssueSeverity.alert);
      expect(issue.atDepth, 0);
      expect(issue.value, closeTo(0.09373, 0.0001));
      expect(issue.threshold, 0.16);
      // A bailout that may never happen has no moment on the dive's clock.
      expect(issue.atRuntime, isNull);

      expect(outcome.isDiveable, isTrue);
      expect(
        outcome.issues.where((i) => i.type == PlanIssueType.hypoxicGas),
        isEmpty,
      );
    });

    test('a richer gas carried for the shallows clears it', () {
      final outcome = engine.compute(_plan(bailouts: [_tx1070, _ean50()]));

      expect(_warnings(outcome), isEmpty);
    });

    test('a richer gas that joins too shallow is reported on arrival', () {
      final outcome = engine.compute(
        _plan(bailouts: [_tx1070, _ean50(modMeters: 3)]),
      );

      final issue = _warnings(outcome).single;
      expect(issue.atDepth, 3);
      expect(issue.value, lessThan(0.16));
    });

    test('a dive shallower than the gas works reports its deepest point', () {
      final outcome = engine.compute(_plan(depth: 5));

      final issue = _warnings(outcome).single;
      expect(issue.atDepth, 5);
      expect(issue.value, lessThan(0.16));
    });

    test('covers a semi-closed plan too', () {
      final outcome = engine.compute(_plan(mode: domain.PlanMode.scr));

      expect(_warnings(outcome), hasLength(1));
    });

    test('an open-circuit plan has no bailout to judge', () {
      final outcome = engine.compute(_plan(mode: domain.PlanMode.oc));

      expect(_warnings(outcome), isEmpty);
    });

    test('a plan with no bailout gas has nothing to judge', () {
      final outcome = engine.compute(_plan(bailouts: const []));

      expect(_warnings(outcome), isEmpty);
    });
  });

  group('planIssueMessage for a hypoxic bailout gas', () {
    const issue = PlanIssue(
      type: PlanIssueType.bailoutGasHypoxic,
      severity: PlanIssueSeverity.alert,
      message: 'Bailout gas is hypoxic at 0 m (ppO2 0.09 bar)',
      atDepth: 3,
      value: 0.124,
      threshold: 0.16,
    );

    Future<String> render(
      WidgetTester tester,
      Locale locale,
      AppSettings settings,
    ) async {
      late String message;
      await tester.pumpWidget(
        testApp(
          locale: locale,
          child: Builder(
            builder: (context) {
              message = planIssueMessage(
                context,
                issue,
                UnitFormatter(settings),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return message;
    }

    testWidgets('puts the depth and ppO2 in their own places', (tester) async {
      expect(
        await render(tester, const Locale('en'), const AppSettings()),
        'Bailout gas is hypoxic at 3m (ppO₂ 0.12 bar). '
        'Carry a gas breathable to the surface.',
      );
    });

    testWidgets('follows the diver\'s depth unit', (tester) async {
      expect(
        await render(
          tester,
          const Locale('en'),
          const AppSettings(depthUnit: DepthUnit.feet),
        ),
        contains('10ft'),
      );
    });

    testWidgets('is translated', (tester) async {
      expect(
        await render(tester, const Locale('de'), const AppSettings()),
        'Bailout-Gas ist hypoxisch bei 3m (ppO₂ 0.12 bar). '
        'Führe ein Gas mit, das bis zur Oberfläche atembar ist.',
      );
    });
  });
}
