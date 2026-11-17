import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';
import 'package:submersion/features/planner/domain/services/scr_flow_check.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_issue_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// A CMF loop with no valid steady state (issue #4660): the flow is at or
/// below VO2, or carries less O2 than the diver uses. Either way the loop
/// model would fall back to breathing the supply, so the plan must say so.
const _ean50 = GasMix(o2: 50);
const _ean32 = GasMix(o2: 32);
const _ean21 = GasMix(o2: 21);

DiveTank _tank(String id, GasMix gas, {TankRole role = TankRole.diluent}) =>
    DiveTank(id: id, volume: 7, startPressure: 200, gasMix: gas, role: role);

PlanSegment _hold(
  String id,
  String tankId,
  GasMix gas, {
  int order = 0,
  domain.PlanMode? mode,
}) => PlanSegment.hold(
  id: id,
  depth: 18,
  durationMinutes: 20,
  tankId: tankId,
  gasMix: gas,
  order: order,
).copyWith(diveModeOverride: mode);

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.scr,
  required List<DiveTank> tanks,
  required List<PlanSegment> segments,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Flow check',
  gfLow: 40,
  gfHigh: 80,
  mode: mode,
  tanks: tanks,
  segments: segments,
  createdAt: DateTime(2026, 11, 17),
  updatedAt: DateTime(2026, 11, 17),
);

PlanEngineConfig _config(double rate, double vo2) =>
    PlanEngineConfig(scrInjectionRateLpm: rate, scrVo2Lpm: vo2);

void main() {
  test('flow at or below VO2 raises the issue', () {
    final plan = _plan(
      tanks: [_tank('t1', _ean50)],
      segments: [_hold('s1', 't1', _ean50)],
    );
    final issues = scrFlowIssues(plan, _config(1.3, 1.3)).toList();
    expect(issues, hasLength(1));
    final issue = issues.single;
    expect(issue.type, PlanIssueType.scrFlowTooLow);
    expect(issue.severity, PlanIssueSeverity.critical);
    expect(issue.tankId, 't1');
    expect(issue.value, 1.3);
    // EAN50 needs VO2 / FO2 = 2.6 L/min before the loop carries any O2.
    expect(issue.threshold, closeTo(2.6, 1e-9));
  });

  test('flow too lean for the supply raises it', () {
    final plan = _plan(
      tanks: [_tank('t1', _ean32)],
      segments: [_hold('s1', 't1', _ean32)],
    );
    final issue = scrFlowIssues(plan, _config(4.0, 1.3)).single;
    expect(issue.value, 4.0);
    expect(issue.gasMix, _ean32);
    expect(issue.threshold, closeTo(1.3 / 0.32, 1e-9));
  });

  test('a sustainable flow raises nothing', () {
    final plan = _plan(
      tanks: [_tank('t1', _ean50)],
      segments: [_hold('s1', 't1', _ean50)],
    );
    expect(scrFlowIssues(plan, _config(12.0, 1.3)), isEmpty);
  });

  test('one issue per supply tank', () {
    final plan = _plan(
      tanks: [_tank('t1', _ean32)],
      segments: [
        _hold('s1', 't1', _ean32),
        _hold('s2', 't1', _ean32, order: 1),
      ],
    );
    expect(scrFlowIssues(plan, _config(4.0, 1.3)), hasLength(1));
  });

  test('an OC bailout segment is not checked', () {
    final plan = _plan(
      tanks: [
        _tank('t1', _ean50),
        _tank('bo', _ean21, role: TankRole.bailout),
      ],
      segments: [
        _hold('s1', 't1', _ean50),
        _hold('s2', 'bo', _ean21, order: 1, mode: domain.PlanMode.oc),
      ],
    );
    expect(scrFlowIssues(plan, _config(4.0, 1.3)), isEmpty);
  });

  test('the grouped row shows the supply that needs the most flow', () {
    final plan = _plan(
      tanks: [_tank('t1', _ean50), _tank('t2', _ean32)],
      segments: [
        _hold('s1', 't1', _ean50),
        _hold('s2', 't2', _ean32, order: 1),
      ],
    );
    final issues = scrFlowIssues(plan, _config(2.0, 1.3)).toList();
    expect(issues, hasLength(2));
    final grouped = groupPlanIssues(issues).single;
    expect(grouped.count, 2);
    // EAN32 needs more than 4.06 L/min; EAN50 only more than 2.6.
    expect(grouped.issue.threshold, closeTo(1.3 / 0.32, 1e-9));
    expect(grouped.issue.tankId, 't2');
  });

  test('a non-SCR plan raises nothing', () {
    for (final mode in [
      domain.PlanMode.oc,
      domain.PlanMode.ccr,
      domain.PlanMode.pscr,
    ]) {
      final plan = _plan(
        mode: mode,
        tanks: [_tank('t1', _ean32)],
        segments: [_hold('s1', 't1', _ean32)],
      );
      expect(scrFlowIssues(plan, _config(1.0, 1.3)), isEmpty, reason: '$mode');
    }
  });

  test('the engine reports it as a critical issue for the plan own flow', () {
    final plan = _plan(
      tanks: [_tank('t1', _ean32)],
      segments: [_hold('s1', 't1', _ean32)],
    ).copyWith(scrInjectionRate: 4.0);
    final outcome = const PlanEngine().compute(plan);
    final flow = [
      for (final i in outcome.issues)
        if (i.type == PlanIssueType.scrFlowTooLow) i,
    ];
    expect(flow, hasLength(1));
    expect(flow.single.severity, PlanIssueSeverity.critical);
    expect(flow.single.value, 4.0);
  });

  group('message', () {
    const issue = PlanIssue(
      type: PlanIssueType.scrFlowTooLow,
      severity: PlanIssueSeverity.critical,
      message: 'raw',
      tankId: 't1',
      gasMix: _ean32,
      value: 4.0,
      threshold: 1.3 / 0.32,
    );

    Future<String> render(WidgetTester tester, AppSettings settings) async {
      late String message;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
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

    testWidgets('names the rate and the flow the supply needs', (tester) async {
      expect(
        await render(tester, const AppSettings()),
        'An injection rate of 4.00 L/min cannot sustain the loop at this VO₂: '
        'EAN32 needs more than 4.06 L/min.',
      );
    });

    testWidgets('follows the diver volume unit, finely enough to tell the '
        'rate from the flow needed', (tester) async {
      // At RMV precision both 4.0 and 4.06 L/min read 0.14 cuft/min, and
      // the warning would contradict itself.
      final text = await render(
        tester,
        const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      );
      expect(text, contains('rate of 0.141 cuft/min'));
      expect(text, contains('more than 0.143 cuft/min'));
      expect(text, isNot(contains('L/min')));
    });
  });
}
