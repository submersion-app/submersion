import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
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
}
