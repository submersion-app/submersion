import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_blender_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_calculators_summary_widget.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/gas_consumption_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mnd_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/mod_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/rock_bottom_calculator.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// Each calculator id has to resolve to its own widget in both chrome forms:
/// bare in the detail pane, and inside a Scaffold when pushed as a page on a
/// narrow window. The ids come from the URL, so a gap in the switch would
/// silently strand a deep link on the summary.
void main() {
  late List<Object> base;

  setUp(() async {
    base = await getBaseOverrides();
  });

  /// Wide enough that no calculator is squeezed. Pane width is Task 9's
  /// subject, not this file's.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(overrides: base.cast(), child: child));
    await tester.pump();
  }

  final widgetForId = <String, Type>{
    'mod': ModCalculator,
    'best-mix': BestMixCalculator,
    'consumption': GasConsumptionCalculator,
    'rock-bottom': RockBottomCalculator,
    'mnd': MndCalculator,
    'blender': GasBlenderCalculator,
  };

  test('the id list and the widget switch cover the same calculators', () {
    expect(kGasCalculatorIds.toSet(), widgetForId.keys.toSet());
  });

  testWidgets('the tool list is in the documented order', (tester) async {
    late List<String> ids;
    await pump(
      tester,
      Builder(
        builder: (context) {
          ids = gasCalculatorToolsOf(context).map((t) => t.id).toList();
          return const SizedBox.shrink();
        },
      ),
    );

    expect(ids, kGasCalculatorIds);
  });

  for (final entry in widgetForId.entries) {
    testWidgets('${entry.key} renders in the pane without an app bar', (
      tester,
    ) async {
      await pump(
        tester,
        GasCalculatorDetailPage(toolId: entry.key, embedded: true),
      );

      expect(find.byType(entry.value), findsOneWidget);
      expect(find.byType(PlanningToolPane), findsOneWidget);
      // MasterDetailScaffold already supplies a Scaffold; a second AppBar
      // here would stack two headers in the detail pane.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('${entry.key} keeps its own app bar as a full page', (
      tester,
    ) async {
      await pump(tester, GasCalculatorDetailPage(toolId: entry.key));

      expect(find.byType(entry.value), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(PlanningToolPane), findsNothing);
    });
  }

  // MasterDetailScaffold reserves 400px for the detail pane
  // (_kDetailPaneReservedWidth), so that is the narrowest a calculator ever
  // renders in split view. The five simple calculators are single-column
  // forms and gain height in the pane; the blender has a wider layout and is
  // the one that could lose by the move off the full-width tabbed page.
  for (final id in kGasCalculatorIds) {
    testWidgets('$id fits the narrowest detail pane', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testApp(
          overrides: base.cast(),
          child: GasCalculatorDetailPage(toolId: id, embedded: true),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unknown id falls back to the summary', (tester) async {
    await pump(
      tester,
      const GasCalculatorDetailPage(toolId: 'not-a-calculator', embedded: true),
    );

    expect(find.byType(GasCalculatorsSummaryWidget), findsOneWidget);
    expect(find.byType(PlanningToolPane), findsNothing);
  });
}
