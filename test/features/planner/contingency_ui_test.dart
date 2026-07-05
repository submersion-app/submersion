import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/contingency_settings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_canvas_chart.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
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

List<dynamic> _overrides() => [
  settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
];

void main() {
  testWidgets('selecting a deviation ghosts a second profile line', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        child: const SizedBox(
          width: 500,
          height: 400,
          child: Column(
            children: [
              Expanded(child: PlanCanvasChart()),
              ContingencyChips(),
            ],
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanCanvasChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();

    LineChart chart() => tester.widget<LineChart>(find.byType(LineChart));
    final baseBars = chart().data.lineBarsData.length;

    await tester.tap(find.text('+5m'));
    await tester.pumpAndSettle();

    expect(container.read(selectedDeviationProvider), 'deeper');
    expect(chart().data.lineBarsData.length, baseBars + 1);

    // Back to base clears the ghost.
    await tester.tap(find.text('Base'));
    await tester.pumpAndSettle();
    expect(chart().data.lineBarsData.length, baseBars);
  });

  testWidgets('sheet lists deviation tables and turn pressure', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        child: SizedBox(
          width: 520,
          height: 900,
          child: PlanResultsSheet(controller: ScrollController()),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanResultsSheet)),
    );
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    notifier.updateContingencies(turnRule: domain.TurnPressureRule.thirds);
    await tester.pumpAndSettle();

    expect(find.textContaining('turn @'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('CONTINGENCIES'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CONTINGENCIES'), findsOneWidget);

    // The deviation tables are collapsed by default (they cost extra engine
    // runs); expand the section before the sub-tables render. Assert on the
    // depth-deviation label '+5m', which is unique to the contingency section
    // (the always-visible range table uses +3m/+6m columns).
    expect(find.text('+5m'), findsNothing);
    expect(container.read(contingenciesExpandedProvider), isFalse);
    await tester.tap(find.text('CONTINGENCIES'));
    await tester.pumpAndSettle();
    expect(container.read(contingenciesExpandedProvider), isTrue);

    await tester.scrollUntilVisible(
      find.text('+5m'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('+5m'), findsOneWidget);
  });

  testWidgets('settings section edits deltas, turn rule, and custom fraction', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: _overrides(),
        child: const SizedBox(
          width: 500,
          child: SingleChildScrollView(child: ContingencySettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContingencySettingsSection)),
    );

    final fields = find.byType(TextFormField);
    // Depth delta and time delta fields (fraction appears only for custom).
    await tester.enterText(fields.at(0), '8');
    await tester.enterText(fields.at(1), '12');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).deviationDepthDelta, 8.0);
    expect(container.read(divePlanNotifierProvider).deviationTimeMinutes, 12);

    // Pick a turn-pressure rule from the dropdown.
    await tester.tap(
      find.byType(DropdownButtonFormField<domain.TurnPressureRule?>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thirds').last);
    await tester.pumpAndSettle();
    expect(
      container.read(divePlanNotifierProvider).turnPressureRule,
      domain.TurnPressureRule.thirds,
    );

    // Custom exposes a fraction field.
    await tester.tap(
      find.byType(DropdownButtonFormField<domain.TurnPressureRule?>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    final fractionField = find.byType(TextFormField).last;
    await tester.enterText(fractionField, '0.4');
    await tester.pumpAndSettle();
    expect(container.read(divePlanNotifierProvider).turnPressureFraction, 0.4);
  });
}
