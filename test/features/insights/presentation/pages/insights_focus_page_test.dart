import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/pages/insights_focus_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  final rmv = [
    for (var i = 0; i < 12; i++)
      TrendDataPoint(
        date: DateTime.utc(2025, 1, i + 1),
        value: 12.0 + i,
        diveId: 'd$i',
      ),
  ];
  final rows = [
    for (var i = 0; i < 12; i++)
      FocusFactorRow(
        diveId: 'd$i',
        dateTime: DateTime.utc(2025, 1, i + 1),
        siteName: 'Site $i',
        maxDepth: 10.0 + i,
        durationMinutes: 45,
      ),
  ];

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    List<TrendDataPoint>? series,
    FocusSelection selection = const FocusSelection(),
    List<String>? pushed,
  }) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: InsightsFocusPage(embedded: true)),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) {
            pushed?.add(state.pathParameters['id']!);
            return const Scaffold(body: Text('dive page'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          focusSelectionProvider.overrideWith((ref) => selection),
          for (final m in FocusMetric.values)
            focusMetricSeriesProvider(m).overrideWith(
              (ref) async => m == FocusMetric.rmv ? (series ?? rmv) : const [],
            ),
          focusFactorRowsProvider.overrideWith((ref) async => rows),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return ProviderScope.containerOf(
      tester.element(find.byType(InsightsFocusPage)),
    );
  }

  testWidgets('best 10 lists ten dives in rank order with a summary', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('10 of 12 dives'), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-dive-d0')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-dive-d10')), findsNothing);
    expect(find.byType(DiveTrendChart), findsOneWidget);
  });

  testWidgets('N beyond the data says all are shown', (tester) async {
    await pump(tester, selection: const FocusSelection(count: 20));
    expect(
      find.text('Only 12 dives have this value, so all of them are shown'),
      findsOneWidget,
    );
  });

  testWidgets('a threshold with no match shows the range', (tester) async {
    await pump(
      tester,
      selection: const FocusSelection(mode: FocusMode.above, threshold: 500),
    );
    expect(find.textContaining('No dives above'), findsOneWidget);
    expect(find.textContaining('Your dives range from'), findsOneWidget);
  });

  testWidgets('a threshold mode with no value asks for one', (tester) async {
    await pump(tester, selection: const FocusSelection(mode: FocusMode.above));
    expect(
      find.text('Enter a value to see the dives above or below it'),
      findsOneWidget,
    );
  });

  testWidgets('no dives with the metric shows the empty state', (tester) async {
    await pump(tester, series: const []);
    expect(find.text('No dives have this value yet'), findsOneWidget);
  });

  testWidgets('tapping a row opens that dive', (tester) async {
    final pushed = <String>[];
    await pump(tester, pushed: pushed);
    await tester.ensureVisible(find.byKey(const ValueKey('focus-dive-d1')));
    await tester.tap(find.byKey(const ValueKey('focus-dive-d1')));
    await tester.pumpAndSettle();
    expect(pushed, ['d1']);
  });

  testWidgets('changing N keeps the results up instead of flashing a spinner', (
    tester,
  ) async {
    await pump(tester);
    final chart = tester.state(find.byType(DiveTrendChart));
    await tester.tap(find.byKey(const ValueKey('focus-count-5')));
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('5 of 12 dives'), findsOneWidget);
    // Same State object: the chart was updated, not torn down, so a zoom the
    // diver set survives.
    expect(tester.state(find.byType(DiveTrendChart)), same(chart));
  });

  testWidgets('the chart draws the group in the accent and the rest muted', (
    tester,
  ) async {
    await pump(tester);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    final scheme = Theme.of(
      tester.element(find.byType(DiveTrendChart)),
    ).colorScheme;
    expect(chart.pointColor, scheme.outlineVariant);
    expect(chart.secondarySeries.single.color, scheme.primary);
    expect(chart.points, hasLength(2));
    expect(chart.secondarySeries.single.points, hasLength(10));
  });

  testWidgets('asking for exactly every dive shows the normal summary', (
    tester,
  ) async {
    await pump(tester, selection: const FocusSelection(count: 12));
    expect(find.textContaining('12 of 12 dives'), findsOneWidget);
    expect(find.textContaining('so all of them are shown'), findsNothing);
  });
}
