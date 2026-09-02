import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_calculators_list_content.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_list_content.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// The master pane of the Gas Calculators split view, and the whole page on a
/// narrow window. It replaces a six-tab TabBar, so the six calculators all
/// have to be reachable from it, in a stable order.
void main() {
  late List<Object> base;

  setUp(() async {
    base = await getBaseOverrides();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(overrides: base.cast(), child: child));
    await tester.pump();
  }

  List<String> renderedIds(WidgetTester tester) => tester
      .widgetList<PlanningTile>(find.byType(PlanningTile))
      .map((tile) => tile.tool.id)
      .toList();

  testWidgets('lists every calculator in display order', (tester) async {
    await pump(tester, const GasCalculatorsListContent());

    expect(renderedIds(tester), kGasCalculatorIds);
  });

  testWidgets('carries the safety disclaimer', (tester) async {
    await pump(tester, const GasCalculatorsListContent());

    expect(find.textContaining('for planning purposes only'), findsOneWidget);
  });

  testWidgets('as a page it has its own app bar and reset action', (
    tester,
  ) async {
    await pump(tester, const GasCalculatorsListContent());

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(PlanningToolPane), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.refresh),
      ),
      findsOneWidget,
    );
  });

  // In split view the pane beside it uses the compact PlanningToolPane header.
  // An AppBar here would be 56px against that header's 40 and the two halves
  // would stop lining up.
  testWidgets('as a master pane it uses the compact header', (tester) async {
    await pump(tester, const GasCalculatorsListContent(showAppBar: false));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(PlanningToolPane), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PlanningToolPane),
        matching: find.text('Gas Calculators'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('highlights the selected calculator', (tester) async {
    await pump(
      tester,
      GasCalculatorsListContent(
        showAppBar: false,
        selectedId: 'rock-bottom',
        onToolSelected: (_) {},
      ),
    );

    final selected = tester
        .widgetList<PlanningTile>(find.byType(PlanningTile))
        .where((tile) => tile.selected)
        .map((tile) => tile.tool.id)
        .toList();

    expect(selected, ['rock-bottom']);
  });

  testWidgets('tapping a calculator selects it rather than navigating', (
    tester,
  ) async {
    final taps = <String?>[];
    await pump(
      tester,
      GasCalculatorsListContent(showAppBar: false, onToolSelected: taps.add),
    );

    await tester.tap(find.text('Best Mix'));
    await tester.pump();

    expect(taps, ['best-mix']);
  });

  // Reset is a property of all six calculators at once, which is why it lives
  // on the list and not on any one calculator.
  testWidgets('reset returns every calculator to its default', (tester) async {
    await pump(tester, const GasCalculatorsListContent());

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GasCalculatorsListContent)),
    );
    container.read(modO2Provider.notifier).state = 50.0;
    container.read(bestMixDepthProvider.notifier).state = 90.0;

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(container.read(modO2Provider), 32.0);
    expect(container.read(bestMixDepthProvider), 30.0);
  });
}
