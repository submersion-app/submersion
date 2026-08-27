import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/deco_calculator/presentation/pages/deco_calculator_page.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculators_page.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_tool_pane.dart';
import 'package:submersion/features/safety/presentation/pages/no_fly_page.dart';
import 'package:submersion/features/safety/presentation/providers/flight_window_providers.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/pages/surface_interval_tool_page.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// Every planning tool has to render two ways: as a full page (mobile, and
/// desktop deep links) and bare inside the Planning detail pane. The pane
/// supplies no app bar, so a tool that keeps its own Scaffold there would
/// render a second, nested one; a tool that drops its actions there would be
/// less capable than the page it replaces.
///
/// These are deliberately shallow: they assert the chrome contract for each
/// tool, not the calculators themselves, which have their own tests.
void main() {
  late List<Object> base;

  setUp(() async {
    base = [
      ...await getBaseOverrides(),
      // The no-fly readout reaches a repository and a trip lookup; neither
      // exists in a widget test.
      noFlyStatusProvider.overrideWith((ref) async => null),
      activeTripFlightWindowProvider.overrideWith((ref) async => null),
    ];
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(testApp(overrides: base.cast(), child: child));
    await tester.pump();
  }

  /// Each tool, in both forms, with the title its chrome should show.
  final tools = <String, ({Widget embedded, Widget page, String title})>{
    'deco calculator': (
      embedded: const DecoCalculatorPage(embedded: true),
      page: const DecoCalculatorPage(),
      title: 'Deco Calculator',
    ),
    'gas calculators': (
      embedded: const GasCalculatorsPage(embedded: true),
      page: const GasCalculatorsPage(),
      title: 'Gas Calculators',
    ),
    'surface interval': (
      embedded: const SurfaceIntervalToolPage(embedded: true),
      page: const SurfaceIntervalToolPage(),
      title: 'Surface Interval',
    ),
    'no-fly': (
      embedded: const NoFlyPage(embedded: true),
      page: const NoFlyPage(),
      title: 'Flying after diving',
    ),
  };

  for (final entry in tools.entries) {
    group(entry.key, () {
      testWidgets('embedded renders pane chrome and no app bar', (
        tester,
      ) async {
        await pump(tester, entry.value.embedded);

        expect(find.byType(PlanningToolPane), findsOneWidget);
        // The pane already sits inside MasterDetailScaffold's Scaffold; a
        // second AppBar here would stack two headers in the detail pane.
        expect(find.byType(AppBar), findsNothing);
        expect(find.text(entry.value.title), findsOneWidget);
      });

      testWidgets('full page keeps its own app bar', (tester) async {
        await pump(tester, entry.value.page);

        expect(find.byType(PlanningToolPane), findsNothing);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text(entry.value.title), findsWidgets);
      });
    });
  }

  // The three tools carrying AppBar actions must keep them in the pane, or
  // the split view is strictly less capable than the full page.
  testWidgets('embedded tools keep their actions', (tester) async {
    await pump(tester, const DecoCalculatorPage(embedded: true));
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.edit_calendar), findsOneWidget);

    await pump(tester, const GasCalculatorsPage(embedded: true));
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await pump(tester, const SurfaceIntervalToolPage(embedded: true));
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  // Gas Calculators hangs its TabBar off AppBar.bottom, which the pane does
  // not have, so embedded it has to become an ordinary first row instead.
  testWidgets('gas calculators keeps its tabs when embedded', (tester) async {
    await pump(tester, const GasCalculatorsPage(embedded: true));

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
  });
}
