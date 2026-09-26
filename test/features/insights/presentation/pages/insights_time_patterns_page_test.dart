import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/pages/insights_time_patterns_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/semantics_finders.dart';

typedef _SurfaceInterval = ({
  double? avgMinutes,
  double? minMinutes,
  double? maxMinutes,
});

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Future<List<({int dayOfWeek, int count})>> Function() days,
    required Future<List<DistributionSegment>> Function() timesOfDay,
    required Future<List<({int month, int count})>> Function() months,
    required Future<_SurfaceInterval> Function() surfaceInterval,
    bool embedded = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          divesByDayOfWeekProvider.overrideWith((ref) => days()),
          divesByTimeOfDayProvider.overrideWith((ref) => timesOfDay()),
          divesBySeasonProvider.overrideWith((ref) => months()),
          surfaceIntervalStatsProvider.overrideWith((ref) => surfaceInterval()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: embedded
              ? const Scaffold(body: InsightsTimePatternsPage(embedded: true))
              : const InsightsTimePatternsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('describes each chart and formats the surface intervals', (
    tester,
  ) async {
    await pumpPage(
      tester,
      days: () async => const [
        (dayOfWeek: 6, count: 4),
        (dayOfWeek: 0, count: 2),
      ],
      timesOfDay: () async => [
        DistributionSegment(label: 'Morning', count: 3, percentage: 75),
        DistributionSegment(label: 'Night', count: 1, percentage: 25),
      ],
      months: () async => const [(month: 7, count: 5)],
      surfaceInterval: () async =>
          (avgMinutes: 95.0, minMinutes: 40.0, maxMinutes: 180.0),
    );

    // Missing days and months are filled with zero and left out of the
    // screen-reader summary, which lists days in calendar order.
    expect(
      findSemanticsLabelled('Bar chart. Dives by day of week. Sun: 2, Sat: 4'),
      findsOneWidget,
    );
    expect(
      findSemanticsLabelled('Bar chart. Dives by month. Jul: 5'),
      findsOneWidget,
    );
    // Stored bucket keys become localized display labels.
    expect(
      findSemanticsLabelled(
        'Pie chart. Dives by time of day. Morning: 75%, Night: 25%',
      ),
      findsOneWidget,
    );
    // Under an hour reads in minutes; an hour or more reads as h and m.
    expect(find.text('1h 35m'), findsOneWidget);
    expect(find.text('40 min'), findsOneWidget);
    expect(find.text('3h 0m'), findsOneWidget);
  });

  testWidgets('shows each empty state when there is nothing to chart', (
    tester,
  ) async {
    await pumpPage(
      tester,
      days: () async => const [],
      timesOfDay: () async => const [],
      months: () async => const [],
      surfaceInterval: () async =>
          (avgMinutes: null, minMinutes: null, maxMinutes: null),
    );

    expect(find.text('No data available'), findsNWidgets(2));
    expect(find.text('No surface interval data available'), findsOneWidget);
  });

  testWidgets('shows a per-section error when a query fails', (tester) async {
    await pumpPage(
      tester,
      days: () async => throw Exception('day of week'),
      timesOfDay: () async => throw Exception('time of day'),
      months: () async => throw Exception('season'),
      surfaceInterval: () async => throw Exception('surface interval'),
    );

    expect(find.text('Failed to load day of week data'), findsOneWidget);
    expect(find.text('Failed to load time of day data'), findsOneWidget);
    expect(find.text('Failed to load seasonal data'), findsOneWidget);
    expect(find.text('Failed to load surface interval data'), findsOneWidget);
  });

  testWidgets('the full page has its own app bar', (tester) async {
    await pumpPage(
      tester,
      days: () async => const [],
      timesOfDay: () async => const [],
      months: () async => const [],
      surfaceInterval: () async =>
          (avgMinutes: null, minMinutes: null, maxMinutes: null),
      embedded: false,
    );

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Time Patterns'),
      ),
      findsOneWidget,
    );
  });
}
