import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/time_of_day_bucket.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/pages/insights_focus_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_dive_list.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_sentence.dart';
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
        timeOfDay: TimeOfDayBucket.night,
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
    List<Override> extraOverrides = const [],
    double? defaultThreshold = 16,
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
          focusThresholdDefaultProvider.overrideWith(
            (ref) async => defaultThreshold,
          ),
          ...extraOverrides,
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

  Finder scrollable() => find.byType(Scrollable).first;
  double y(WidgetTester tester, Finder f) => tester.getTopLeft(f.first).dy;

  testWidgets(
    'the page reads top to bottom: intro, sentence, summary, standouts, '
    'chart, comparison, dives',
    (tester) async {
      await pump(tester);
      expect(
        find.text('See what a group of your dives has in common.'),
        findsOneWidget,
      );
      expect(find.byType(FocusSentence), findsOneWidget);
      expect(find.textContaining('10 of 12 dives. Average'), findsOneWidget);
      expect(
        y(tester, find.byType(FocusSentence)),
        lessThan(y(tester, find.text('What stands out'))),
      );
      expect(
        y(tester, find.text('What stands out')),
        lessThan(y(tester, find.text('RMV over time'))),
      );
      await tester.scrollUntilVisible(
        find.text('The dives'),
        300,
        scrollable: scrollable(),
      );
      expect(
        y(tester, find.text('Full comparison')),
        lessThan(y(tester, find.text('The dives'))),
      );
    },
  );

  testWidgets('the dive list previews five rows and Show all expands it', (
    tester,
  ) async {
    await pump(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('focus-list-show-all')),
      300,
      scrollable: scrollable(),
    );
    expect(find.text('Show all 10 dives'), findsOneWidget);
    final list = tester.widget<FocusDiveList>(
      find.byType(FocusDiveList, skipOffstage: false),
    );
    expect(list.members, hasLength(5));
    expect(list.ranked, isTrue);
    await tester.tap(find.byKey(const ValueKey('focus-list-show-all')));
    await tester.pump();
    expect(find.byKey(const ValueKey('focus-list-show-all')), findsNothing);
    expect(
      tester
          .widget<FocusDiveList>(
            find.byType(FocusDiveList, skipOffstage: false),
          )
          .members,
      hasLength(10),
    );
  });

  testWidgets('a group of five has no Show all; a new selection folds again', (
    tester,
  ) async {
    final c = await pump(tester, selection: const FocusSelection(count: 5));
    expect(
      find.byKey(const ValueKey('focus-list-show-all'), skipOffstage: false),
      findsNothing,
    );
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      count: 6,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Show all 6 dives', skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'the chart names the metric, shows a legend and bigger group dots',
    (tester) async {
      await pump(tester);
      expect(find.text('RMV over time'), findsOneWidget);
      expect(find.byKey(const ValueKey('focus-legend')), findsOneWidget);
      expect(find.text('In the group'), findsOneWidget);
      expect(find.text('Other dives'), findsOneWidget);
      final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
      final scheme = Theme.of(
        tester.element(find.byType(DiveTrendChart)),
      ).colorScheme;
      expect(chart.pointColor, scheme.outlineVariant);
      expect(chart.secondarySeries.single.color, scheme.primary);
      expect(chart.secondarySeries.single.pointRadius, 4.4);
      expect(chart.points, hasLength(2));
      expect(chart.secondarySeries.single.points, hasLength(10));
      expect(chart.referenceLine, isNull);
    },
  );

  testWidgets('a threshold draws a labelled reference line', (tester) async {
    await pump(
      tester,
      selection: const FocusSelection(mode: FocusMode.above, threshold: 15),
    );
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.referenceLine!.value, 15);
    expect(chart.referenceLine!.label, '15.0 L/min');
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

  testWidgets('a below threshold with no match shows the range', (
    tester,
  ) async {
    await pump(
      tester,
      selection: const FocusSelection(mode: FocusMode.below, threshold: 1),
    );
    expect(find.textContaining('No dives below'), findsOneWidget);
  });

  testWidgets('a failed group load shows the error state', (tester) async {
    await pump(
      tester,
      extraOverrides: [
        focusGroupProvider.overrideWith((ref) async => throw StateError('x')),
      ],
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Failed to load dive focus'), findsOneWidget);
  });

  testWidgets('a failed factor report says so in both factor cards', (
    tester,
  ) async {
    await pump(
      tester,
      extraOverrides: [
        focusFactorReportProvider.overrideWith(
          (ref) async => throw StateError('x'),
        ),
      ],
    );
    expect(
      find.text('Failed to load dive focus', skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.byType(DiveTrendChart, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a threshold mode with no value and no mean asks for one', (
    tester,
  ) async {
    await pump(
      tester,
      selection: const FocusSelection(mode: FocusMode.above),
      defaultThreshold: null,
    );
    expect(
      find.text('Enter a value to see the dives above or below it'),
      findsOneWidget,
    );
  });

  testWidgets('no dives with the metric shows the empty state', (tester) async {
    await pump(tester, series: const []);
    expect(find.text('No dives have this value yet'), findsOneWidget);
    expect(find.byType(FocusSentence), findsOneWidget);
  });

  testWidgets('tapping a row opens that dive', (tester) async {
    final pushed = <String>[];
    await pump(tester, pushed: pushed);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('focus-dive-d1')),
      200,
      scrollable: scrollable(),
    );
    await tester.tap(find.byKey(const ValueKey('focus-dive-d1')));
    await tester.pumpAndSettle();
    expect(pushed, ['d1']);
  });

  testWidgets('changing N keeps the results up instead of flashing a spinner', (
    tester,
  ) async {
    final c = await pump(tester);
    final chart = tester.state(find.byType(DiveTrendChart));
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      count: 5,
    );
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

  testWidgets('a huge group builds only the rows on screen (#3013)', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 1000; i++)
        TrendDataPoint(
          date: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
          value: 12.0 + i % 10,
          diveId: 'd$i',
        ),
    ];
    await pump(
      tester,
      series: many,
      selection: const FocusSelection(mode: FocusMode.above, threshold: 0),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('focus-list-show-all')),
      2000,
      scrollable: scrollable(),
      maxScrolls: 200,
    );
    await tester.tap(find.byKey(const ValueKey('focus-list-show-all')));
    await tester.pump();
    final builtRows = find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> && key.value.startsWith('focus-dive-');
    }, skipOffstage: false);
    expect(builtRows, findsWidgets);
    expect(builtRows.evaluate().length, lessThan(100));
  });

  testWidgets('asking for exactly every dive shows the normal summary', (
    tester,
  ) async {
    await pump(tester, selection: const FocusSelection(count: 12));
    expect(find.textContaining('12 of 12 dives'), findsOneWidget);
    expect(find.textContaining('so all of them are shown'), findsNothing);
  });
}
