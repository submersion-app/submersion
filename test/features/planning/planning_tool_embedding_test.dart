import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/deco_calculator/presentation/pages/deco_calculator_page.dart';
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

    await pump(tester, const SurfaceIntervalToolPage(embedded: true));
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  // Gas Calculators is no longer in the table above: it has no embedded form
  // at all. It is a full-page push with a split view of its own, so its
  // chrome contract lives in gas_calculators_page_test.dart instead.

  // A pushed split view needs a back affordance the nav rail does not supply,
  // and it has to sit in the same compact header the detail pane uses, or the
  // two halves stop lining up.
  group('PlanningToolPane leading', () {
    testWidgets('renders a leading widget ahead of the title', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: PlanningToolPane(
            leading: BackButton(),
            title: 'Gas Calculators',
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(BackButton), findsOneWidget);
      final backX = tester.getCenter(find.byType(BackButton)).dx;
      final titleX = tester.getCenter(find.text('Gas Calculators')).dx;
      expect(backX, lessThan(titleX));
    });

    testWidgets('omitting it leaves the header unchanged', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: PlanningToolPane(
            title: 'Gas Calculators',
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Gas Calculators'), findsOneWidget);
    });
  });
}
