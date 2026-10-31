import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/services/plan_slate_pdf_service.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/chart_mode_toggle.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_result_status.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/planner_results.dart';
import '../../helpers/test_app.dart';

const _gapMessage =
    'No bailout gas reaches 30m: the deepest MOD carried is 21m. Carry a gas '
    'usable at that depth; more of the same gas will not help.';

const _ean50 = DiveTank(
  id: 'bo',
  volume: 11.1,
  startPressure: 207,
  gasMix: GasMix(o2: 50),
  role: TankRole.bailout,
);

const _ean32 = DiveTank(
  id: 'bo',
  volume: 11.1,
  startPressure: 207,
  gasMix: GasMix(o2: 32),
  role: TankRole.bailout,
);

const _air = GasMix(o2: 21);

/// A 30 m CCR dive, which EAN50 alone cannot bail out of and EAN32 can.
domain.DivePlan _plan(DiveTank bailout) => domain.DivePlan(
  id: 'gap',
  name: 'Gap',
  mode: domain.PlanMode.ccr,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  gfLow: 30,
  gfHigh: 70,
  tanks: [
    const DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.diluent,
    ),
    bailout,
  ],
  segments: [
    PlanSegment.travel(
      id: 'down',
      fromDepth: 0,
      targetDepth: 30,
      ratePerMinute: 18,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 30,
      durationMinutes: 25,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

/// Mounts [child] on [_plan] carrying [bailout], results inline.
Future<ProviderContainer> _mount(
  WidgetTester tester,
  Widget child, {
  required DiveTank bailout,
  ChartDisplayMode mode = ChartDisplayMode.ccr,
}) async {
  // Tall enough that the sheet builds its Warnings as well as its Bailout.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...plannerResultsInline(),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: SizedBox(width: 500, height: 2400, child: child),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byWidget(child)),
  );
  loadPlan(container, _plan(bailout));
  container.read(chartDisplayModeProvider.notifier).state = mode;
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('the results sheet', () {
    late PlanResultsSheet sheet;

    setUp(() {
      sheet = PlanResultsSheet(controller: ScrollController());
    });

    testWidgets('a gas gap replaces every sized figure with the error', (
      tester,
    ) async {
      await _mount(tester, sheet, bailout: _ean50);

      // Once in the Bailout section, once in Warnings.
      expect(find.text(_gapMessage), findsNWidgets(2));
      expect(find.textContaining('Required'), findsNothing);
      expect(find.textContaining('Available'), findsNothing);
      expect(find.textContaining('Bailout TTS'), findsNothing);
      expect(find.text('Schedule from the worst case'), findsNothing);
      expect(
        find.text('Bailout gas insufficient for the worst case'),
        findsNothing,
      );
    });

    testWidgets('a covered plan keeps its figures and has no error', (
      tester,
    ) async {
      await _mount(tester, sheet, bailout: _ean32);

      expect(find.text(_gapMessage), findsNothing);
      expect(find.textContaining('Required'), findsOneWidget);
      expect(find.text('Schedule from the worst case'), findsOneWidget);
    });
  });

  group('the chart', () {
    testWidgets('a gas gap hides the Bailout chip', (tester) async {
      await _mount(tester, const ChartModeToggle(), bailout: _ean50);

      expect(find.text('Bailout'), findsNothing);
    });

    testWidgets('a covered plan keeps the Bailout chip', (tester) async {
      await _mount(tester, const ChartModeToggle(), bailout: _ean32);

      expect(find.text('Bailout'), findsOneWidget);
    });

    testWidgets('already in Bailout view, a gas gap draws no ascent and says '
        'why on the chart', (tester) async {
      final container = await _mount(
        tester,
        const PlanChartBailoutStatus(),
        bailout: _ean50,
        mode: ChartDisplayMode.bailout,
      );

      container.listen(planChartBailoutProvider, (_, _) {});
      expect(container.read(planChartBailoutProvider).picture, isNull);
      expect(find.text(_gapMessage), findsOneWidget);
    });

    testWidgets('the whole sentence fits on a phone chart', (tester) async {
      await _mount(
        tester,
        const Center(
          child: SizedBox(width: 370, height: 220, child: PlanProfileChart()),
        ),
        bailout: _ean50,
        mode: ChartDisplayMode.bailout,
      );

      expect(find.text(_gapMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('outside Bailout view the chart says nothing about the gap', (
      tester,
    ) async {
      await _mount(tester, const PlanChartBailoutStatus(), bailout: _ean50);

      expect(find.text(_gapMessage), findsNothing);
    });
  });

  group('the slate', () {
    final labels = PlanSlateLabels(
      runtimeTable: '',
      gasPlan: '',
      contingencies: '',
      lostGasLabel: (gas) => gas,
      rangeTable: '',
      bailout: '',
      duration: '',
      depth: '',
      runtime: '',
      gas: '',
      turnAt: '',
      minGas: '',
      noTurnRule: '',
      noStartPressure: '',
      noVolume: '',
      base: '',
      minutes: (value) => '$value min',
      maxPrefix: '',
      noEligibleBailoutGas: (depth, mod) => 'No gas: $depth, MOD $mod',
    );

    String line(DiveTank bailout) => planSlateBailoutLine(
      const BailoutSolver().solve(_plan(bailout))!,
      const UnitFormatter(AppSettings()),
      labels,
    );

    test('prints the gap in place of an invalid ascent', () {
      expect(line(_ean50), 'No gas: 30m, MOD 21m');
    });

    test('a covered plan keeps its TTS and litres', () {
      expect(line(_ean32), startsWith('TTS'));
    });
  });
}
