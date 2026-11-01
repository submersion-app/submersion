import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/planner_results.dart';
import '../../helpers/test_app.dart';

const _air = GasMix();

/// A CCR plan whose bailout owes an oxygen stop at 6 m. The loop's own stops
/// never take a break, so the only break on the sheet is the bailout's.
domain.DivePlan _plan({AirBreakPolicy? airBreaks}) => domain.DivePlan(
  id: 'plan-1',
  name: 'bailout air breaks',
  mode: domain.PlanMode.ccr,
  gfLow: 30,
  gfHigh: 70,
  lastStopDepth: 6,
  airBreaks: airBreaks,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tanks: const [
    DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.diluent,
    ),
    DiveTank(
      id: 'loop-o2',
      volume: 3,
      startPressure: 200,
      gasMix: GasMix(o2: 100),
      role: TankRole.oxygenSupply,
    ),
    DiveTank(
      id: 'back',
      volume: 40,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.bailout,
    ),
    DiveTank(
      id: 'o2',
      volume: 11,
      startPressure: 200,
      gasMix: GasMix(o2: 100),
      role: TankRole.bailout,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: 45,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 45,
      durationMinutes: 40,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

Future<void> _mount(WidgetTester tester, domain.DivePlan plan) async {
  // Tall enough that the sheet builds the whole Bailout section, and wide
  // enough for the test font's square glyphs on the Required line.
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final sheet = PlanResultsSheet(controller: ScrollController());
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...plannerResultsInline(),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: SizedBox(width: 1000, height: 3200, child: sheet),
    ),
  );
  loadPlan(
    ProviderScope.containerOf(tester.element(find.byWidget(sheet))),
    plan,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bailout table shows a stop line\'s air break', (
    tester,
  ) async {
    await _mount(tester, _plan(airBreaks: const AirBreakPolicy()));

    expect(find.text('Schedule from the worst case'), findsOneWidget);
    expect(find.textContaining('(+6′)'), findsOneWidget);
  });

  testWidgets('the bailout table shows no break without a policy', (
    tester,
  ) async {
    await _mount(tester, _plan());

    expect(find.text('Schedule from the worst case'), findsOneWidget);
    expect(find.textContaining('(+'), findsNothing);
  });
}
