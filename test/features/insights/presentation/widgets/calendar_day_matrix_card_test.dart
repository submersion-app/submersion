import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/domain/calendar_day_matrix.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/calendar_day_matrix_card.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/semantics_finders.dart';
import '../../../../helpers/test_app.dart';

/// Issue #3127: the Time patterns calendar days card.
void main() {
  CalendarDayMatrix matrix(List<(int, int, int)> cells) =>
      CalendarDayMatrix.fromCounts([
        for (final (month, day, count) in cells)
          (month: month, day: day, count: count),
      ]);

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Future<CalendarDayMatrix> Function() data, {
    DiveFilterState insightsFilter = const DiveFilterState(),
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/insights',
      routes: [
        GoRoute(
          path: '/insights',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: CalendarDayMatrixCard()),
          ),
        ),
        GoRoute(path: '/dives', builder: (_, _) => const Text('dive list')),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...base,
          insightsFilterProvider.overrideWith((ref) => insightsFilter),
          divesByCalendarDayProvider.overrideWith((ref) => data()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(CalendarDayMatrixCard)),
    );
  }

  testWidgets('the headline names coverage and the busiest values', (
    tester,
  ) async {
    await pump(tester, () async => matrix([(5, 6, 14), (8, 6, 3), (2, 29, 1)]));

    expect(find.text('3 of 366 calendar days (0.8%)'), findsOneWidget);
    expect(find.text('Busiest month: May'), findsOneWidget);
    expect(find.text('Busiest day of month: 6'), findsOneWidget);
  });

  testWidgets('ties name every busiest month and day', (tester) async {
    await pump(tester, () async => matrix([(5, 1, 4), (8, 2, 4)]));

    expect(find.text('Busiest month: May, Aug'), findsOneWidget);
    expect(find.text('Busiest day of month: 1, 2'), findsOneWidget);
  });

  testWidgets('cells read as their date and count; non-dates are silent', (
    tester,
  ) async {
    await pump(tester, () async => matrix([(5, 6, 14)]));

    expect(findSemanticsLabelled('May 6, 14 dives'), findsOneWidget);
    expect(findSemanticsLabelled('May 7, no dives'), findsOneWidget);
    expect(findSemanticsLabelled('February 29, no dives'), findsOneWidget);
    // 30 February would format as 1 March; it must not be a cell at all.
    expect(findSemanticsLabelled('March 1, no dives'), findsOneWidget);
    // 30 and 31 February; 31 April, June, September and November.
    expect(find.text('×'), findsNWidgets(6));
  });

  testWidgets('totals read with what they total', (tester) async {
    await pump(tester, () async => matrix([(5, 6, 14), (5, 7, 2)]));

    expect(findSemanticsLabelled('May, 16 dives in total'), findsOneWidget);
    expect(findSemanticsLabelled('Day 6, 14 dives in total'), findsOneWidget);
    expect(findSemanticsLabelled('Total, 16 dives in total'), findsOneWidget);
  });

  testWidgets('tapping a cell opens that date under the Insights filter', (
    tester,
  ) async {
    final container = await pump(
      tester,
      () async => matrix([(5, 6, 14)]),
      insightsFilter: const DiveFilterState(minDepth: 18),
    );

    await tester.tap(findSemanticsLabelled('May 6, 14 dives'));
    await tester.pumpAndSettle();

    expect(find.text('dive list'), findsOneWidget);
    final filter = container.read(diveFilterProvider);
    expect(filter.minDepth, 18);
    expect(
      filter.query,
      AndNode([
        ConditionNode(
          FieldPath(const ['month']),
          QueryOp.eq,
          const NumberValue(5, null),
        ),
        ConditionNode(
          FieldPath(const ['day']),
          QueryOp.eq,
          const NumberValue(6, null),
        ),
      ]),
    );
  });

  testWidgets('a phone scrolls the days sideways under fixed month labels', (
    tester,
  ) async {
    await pump(
      tester,
      () async => matrix([(5, 31, 120), (8, 1, 1128)]),
      size: const Size(360, 900),
    );

    // Three- and four-digit counts fit without an overflow.
    expect(tester.takeException(), isNull);
    final dayHeader = find.text('31').first;
    expect(tester.getRect(dayHeader).left, greaterThan(360));
    final janBefore = tester.getRect(find.text('Jan'));

    // Drag from a header that starts on screen.
    await tester.drag(find.text('3').first, const Offset(-2000, 0));
    await tester.pumpAndSettle();

    expect(tester.getRect(dayHeader).right, lessThanOrEqualTo(360));
    expect(tester.getRect(find.text('Jan')), janBefore);
  });

  testWidgets('a wide window fits the whole year without scrolling', (
    tester,
  ) async {
    await pump(tester, () async => matrix([(12, 31, 3)]));

    expect(
      tester.getRect(find.text('31').first).right,
      lessThanOrEqualTo(1200),
    );
  });

  testWidgets('no dives shows the empty state', (tester) async {
    await pump(tester, () async => CalendarDayMatrix.fromCounts(const []));

    expect(find.text('No dives to place on the calendar yet'), findsOneWidget);
  });

  testWidgets('a failed load shows the error state', (tester) async {
    await pump(tester, () async => throw StateError('boom'));

    expect(find.text('Failed to load calendar days'), findsOneWidget);
  });

  group('cell colours', () {
    for (final brightness in Brightness.values) {
      test('zero is neutral, counts deepen, dark fills use onPrimary '
          '(${brightness.name})', () {
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        );

        final zero = calendarCellFill(scheme, 0, 15);
        final one = calendarCellFill(scheme, 1, 15);
        final max = calendarCellFill(scheme, 15, 15);

        expect(zero, isNot(one));
        expect(one, isNot(max));
        expect(max, scheme.primary);
        expect(calendarCellText(scheme, 15, 15), scheme.onPrimary);
        expect(calendarCellText(scheme, 1, 15), isNot(scheme.onPrimary));
      });

      test('a date with one dive stands clear of an empty date '
          '(${brightness.name})', () {
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        );
        double distance(Color a, Color b) {
          final dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b;
          return dr * dr + dg * dg + db * db;
        }

        // Squared RGB distance; 0.0225 is a 0.15 step on the unit cube.
        expect(
          distance(
            calendarCellFill(scheme, 0, 15),
            calendarCellFill(scheme, 1, 15),
          ),
          greaterThan(0.0225),
        );
      });
    }
  });
}
