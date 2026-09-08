import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(Widget child) => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  child: SizedBox(width: 500, height: 600, child: child),
);

Future<void> _seedDecoPlan(WidgetTester tester, Finder anchor) async {
  final container = ProviderScope.containerOf(tester.element(anchor));
  container
      .read(divePlanNotifierProvider.notifier)
      .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
  await tester.pumpAndSettle();
}

/// A hand-built outcome: a descent, a level leg and an ascent straight to
/// the surface with no stops, so the table has lines but no deco.
PlanOutcome _noDecoOutcome({int airBreakSeconds = 0}) {
  PlanScheduleRow row(
    PlanScheduleRowKind kind,
    double depth,
    int duration,
    int runtime, {
    int airBreak = 0,
  }) => PlanScheduleRow(
    kind: kind,
    depthMeters: depth,
    durationSeconds: duration,
    runtimeSeconds: runtime,
    gasFO2: 0.32,
    gasFHe: 0,
    airBreakSeconds: airBreak,
  );
  return PlanOutcome(
    runtimeSeconds: 1620,
    maxDepth: 18,
    ndlAtBottom: 600,
    ttsAtBottom: 120,
    stops: const [],
    schedule: [
      row(PlanScheduleRowKind.descent, 18, 240, 240),
      row(PlanScheduleRowKind.level, 18, 1200, 1440, airBreak: airBreakSeconds),
      row(PlanScheduleRowKind.ascent, 0, 180, 1620),
    ],
    segmentOutcomes: const [],
    tankUsages: const [],
    cnsEnd: 5,
    otuTotal: 10,
    issues: const [],
    endTissue: const BuhlmannState(compartments: []),
    tissueTimeline: const [],
    ceilingTrace: const [],
  );
}

Widget _outcomeHarness(PlanOutcome outcome) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    activePlanOutcomeProvider.overrideWithValue(outcome),
  ],
  child: SizedBox(
    width: 500,
    height: 600,
    child: PlanResultsSheet(controller: ScrollController()),
  ),
);

void main() {
  testWidgets('runtime table says no deco above the rows when there are '
      'lines but no stops', (tester) async {
    await tester.pumpWidget(_outcomeHarness(_noDecoOutcome()));
    await tester.pumpAndSettle();

    expect(find.text('No decompression required'), findsOneWidget);
    // The table still prints: header plus the three authored lines.
    expect(find.text('Depth'), findsOneWidget);
    expect(find.text('↘'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.text('↗'), findsOneWidget);
    expect(find.text('−'), findsNothing);
    // Whole minutes: 4, 20 and 3 add up to the 27-minute runtime. The first
    // line's duration and runtime are the same number, so it prints twice.
    expect(find.text('4′'), findsNWidgets(2));
    expect(find.text('20′'), findsOneWidget);
    expect(find.text('24′'), findsOneWidget);
    expect(find.text('3′'), findsOneWidget);
    expect(find.text('27′'), findsOneWidget);
    expect(find.textContaining('(+'), findsNothing);
  });

  testWidgets('a line with an air break shows the break minutes after its '
      'duration', (tester) async {
    await tester.pumpWidget(
      _outcomeHarness(_noDecoOutcome(airBreakSeconds: 290)),
    );
    await tester.pumpAndSettle();

    // 290 s rounds up to a whole 5-minute break.
    expect(find.text("20′ (+5′)"), findsOneWidget);
    expect(find.textContaining('(+'), findsOneWidget);
  });

  testWidgets('PlanStatusChips shows a TTS chip and a tappable issues chip', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));

    expect(find.text('TTS'), findsOneWidget);
    expect(find.textContaining('issue'), findsOneWidget);
  });

  testWidgets('PlanResultsSheet renders runtime table, gas, and issues', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(PlanResultsSheet(controller: ScrollController())),
    );
    await _seedDecoPlan(tester, find.byType(PlanResultsSheet));

    // Runtime table header(s) — the contingency mini-tables repeat it.
    expect(find.text('Depth'), findsWidgets);
    expect(find.text('Duration'), findsWidgets);
    // The table reads like a slate: the authored descent and bottom, then
    // a travel leg and a stop per computed stop, marked by direction.
    expect(find.text('↘'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.text('↗'), findsWidgets);
    expect(find.text('−'), findsWidgets);
    // Gas section rendered a per-tank consumption bar.
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    // Air at 45 m trips the critical gas-density issue (issues sit below
    // the contingency tables — scroll the unique section header into the
    // lazy viewport, then nudge so the issue rows build).
    await tester.scrollUntilVisible(
      find.text('WARNINGS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.textContaining('g/L'), findsWidgets);
  });

  testWidgets(
    'PlanResultsSheet disables its own scrolling and keeps the shared '
    'controller when shrinkWrap is set',
    (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        _harness(PlanResultsSheet(controller: controller, shrinkWrap: true)),
      );
      await _seedDecoPlan(tester, find.byType(PlanResultsSheet));

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.shrinkWrap, isTrue);
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());
      expect(listView.controller, same(controller));
    },
  );

  testWidgets('ContingencyPreviewChip renders nothing without a selection', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));

    expect(find.byType(ContingencyPreviewChip), findsOneWidget);
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('ContingencyPreviewChip previews a deviation and clears on tap', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanStatusChips)),
    );
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));

    container.read(selectedDeviationProvider.notifier).state = 'deeper';
    await tester.pumpAndSettle();
    expect(find.textContaining('Previewing: +5m'), findsOneWidget);

    container.read(selectedDeviationProvider.notifier).state = 'longer';
    await tester.pumpAndSettle();
    expect(find.textContaining("Previewing: +5′"), findsOneWidget);

    container.read(selectedDeviationProvider.notifier).state = 'both';
    await tester.pumpAndSettle();
    expect(find.textContaining("Previewing: +5m +5′"), findsOneWidget);

    await tester.tap(find.byType(ContingencyPreviewChip));
    await tester.pumpAndSettle();

    expect(container.read(selectedDeviationProvider), isNull);
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('ContingencyPreviewChip previews a lost-gas tank and clears both '
      'selections on tap', (tester) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanStatusChips)),
    );
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));
    container
        .read(divePlanNotifierProvider.notifier)
        .addTank(
          const DiveTank(
            id: 'deco',
            volume: 11.1,
            startPressure: 200,
            gasMix: GasMix(o2: 50),
            role: TankRole.deco,
          ),
        );
    await tester.pumpAndSettle();

    container.read(selectedLostGasTankIdProvider.notifier).state = 'deco';
    await tester.pumpAndSettle();

    expect(find.textContaining('Previewing: Lost EAN50'), findsOneWidget);

    await tester.tap(find.byType(ContingencyPreviewChip));
    await tester.pumpAndSettle();

    expect(container.read(selectedLostGasTankIdProvider), isNull);
    expect(container.read(selectedDeviationProvider), isNull);
    expect(find.textContaining('Previewing'), findsNothing);
  });

  testWidgets('ContingencyPreviewChip hides when the selected tank is gone', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(PlanStatusChips(onIssuesTap: () {})));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanStatusChips)),
    );
    await _seedDecoPlan(tester, find.byType(PlanStatusChips));

    // A selection whose tank the plan never carried stands in for one that
    // went stale (tank removed, role changed, travel-gas flag cleared): the
    // id lingers but no contingency is computed, so the headline stats fall
    // back to the live plan. The chip must not claim a preview that is not
    // in effect.
    container.read(selectedLostGasTankIdProvider.notifier).state = 'removed';
    await tester.pumpAndSettle();

    expect(container.read(selectedContingencyProvider), isNull);
    expect(find.textContaining('Previewing'), findsNothing);
    expect(
      container.read(activePlanOutcomeProvider),
      same(container.read(planOutcomeProvider)),
    );
  });
}
