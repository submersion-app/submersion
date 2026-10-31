import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/plan_issue_grouping.dart';
import 'package:submersion/features/planner/presentation/chart/plan_issue_marker_layer.dart';
import 'package:submersion/features/planner/presentation/chart/plan_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_issue_marker_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// A marker tapped on the chart brings its warnings into view in the
/// results panel when they are scrolled out of it (#3738).

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _section = Key('planWarningsSection');

void main() {
  Future<ProviderContainer> seed(
    WidgetTester tester, {
    required double paneHeight,
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: Column(
          children: [
            const SizedBox(width: 500, height: 280, child: PlanProfileChart()),
            SizedBox(
              width: 500,
              height: paneHeight,
              child: PlanResultsSheet(controller: ScrollController()),
            ),
          ],
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanProfileChart)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 45, bottomTimeMinutes: 25);
    await tester.pumpAndSettle();
    return container;
  }

  List<PlacedIssueMarker> placed(WidgetTester tester) =>
      (tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('planChartIssueMarkers')),
                  )
                  .painter
              as PlanIssueMarkerPainter)
          .placed;

  // The last marker sits on the bottom waypoint, which wins the tap.
  Future<PlacedIssueMarker> tapMarker(WidgetTester tester) async {
    final marker = placed(tester).first;
    final origin = tester.getTopLeft(find.byType(PlanProfileChart));
    await tester.tapAt(origin + marker.glyph.center);
    await tester.pumpAndSettle();
    return marker;
  }

  Rect pane(WidgetTester tester) =>
      tester.getRect(find.byType(PlanResultsSheet));

  Finder row(PlanIssueKey key) =>
      find.byKey(ValueKey('planIssueRow-${key.$1.name}-${key.$2.name}'));

  double scrollOffset(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(PlanResultsSheet),
          matching: find.byType(Scrollable),
        ),
      )
      .position
      .pixels;

  bool within(Rect outer, Rect inner) =>
      inner.top >= outer.top - 0.5 && inner.bottom <= outer.bottom + 0.5;

  testWidgets('a marker tapped brings the whole warnings list into view', (
    tester,
  ) async {
    await seed(tester, paneHeight: 300);
    expect(
      within(pane(tester), tester.getRect(find.byKey(_section))),
      isFalse,
      reason: 'the deco schedule pushes the warnings out of the panel',
    );

    await tapMarker(tester);

    expect(within(pane(tester), tester.getRect(find.byKey(_section))), isTrue);
  });

  testWidgets('when the list cannot fit, just enough to show the picked row', (
    tester,
  ) async {
    await seed(tester, paneHeight: 120);
    final section = tester.getRect(find.byKey(_section));
    expect(section.height, greaterThan(120));

    final marker = await tapMarker(tester);

    final picked = tester.getRect(row(marker.marker.keys.first));
    expect(within(pane(tester), picked), isTrue);
    // No further than needed: the row sits at the bottom of the panel.
    expect(picked.bottom, closeTo(pane(tester).bottom, 1));
  });

  testWidgets('warnings already in view stay where they are', (tester) async {
    await seed(tester, paneHeight: 300);
    final scrollable = find.descendant(
      of: find.byType(PlanResultsSheet),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final before = scrollOffset(tester);

    await tapMarker(tester);

    expect(scrollOffset(tester), before);
  });

  testWidgets('a row picked in the list does not move the list', (
    tester,
  ) async {
    final container = await seed(tester, paneHeight: 300);
    final marker = placed(tester).first;
    container.read(highlightedPlanIssuesProvider.notifier).state =
        marker.marker.keys;
    await tester.pumpAndSettle();

    expect(scrollOffset(tester), 0);
  });

  testWidgets('letting go of a marker does not move the list', (tester) async {
    await seed(tester, paneHeight: 300);
    await tapMarker(tester);
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(PlanResultsSheet),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    position.jumpTo(0);
    await tester.pumpAndSettle();

    await tapMarker(tester);

    expect(scrollOffset(tester), 0);
  });
}
