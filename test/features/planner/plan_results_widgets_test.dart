import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
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

void main() {
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
