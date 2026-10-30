import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/calendar_day_matrix.dart';
import 'package:submersion/features/insights/presentation/pages/insights_time_patterns_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/semantics_finders.dart';

typedef _SurfaceInterval = ({
  double? avgMinutes,
  double? minMinutes,
  double? maxMinutes,
});

/// A distribution with [counts] dives per bucket key, in the given order.
TimeOfDayDistribution timeOfDay(
  Map<String, int> counts, {
  int divesWithoutLocation = 0,
}) {
  final total = counts.values.fold<int>(0, (sum, count) => sum + count);
  return TimeOfDayDistribution(
    segments: [
      for (final entry in counts.entries)
        DistributionSegment(
          label: entry.key,
          count: entry.value,
          percentage: entry.value / total * 100,
        ),
    ],
    divesWithoutLocation: divesWithoutLocation,
  );
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    required Future<List<({int dayOfWeek, int count})>> Function() days,
    required Future<TimeOfDayDistribution> Function() timesOfDay,
    required Future<List<({int month, int count})>> Function() months,
    required Future<_SurfaceInterval> Function() surfaceInterval,
    bool embedded = true,
    Brightness brightness = Brightness.light,
    TimeFormat? timeFormat,
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
          divesByCalendarDayProvider.overrideWith(
            (ref) async => CalendarDayMatrix.fromCounts(const []),
          ),
          surfaceIntervalStatsProvider.overrideWith((ref) => surfaceInterval()),
          if (timeFormat != null)
            timeFormatProvider.overrideWithValue(timeFormat),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
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
      timesOfDay: () async => timeOfDay({'Morning': 3, 'Night': 1}),
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

  testWidgets('long surface intervals read in days and years', (tester) async {
    await pumpPage(
      tester,
      days: () async => const [(dayOfWeek: 6, count: 1)],
      timesOfDay: () async => timeOfDay({'Morning': 1}),
      months: () async => const [(month: 7, count: 1)],
      // 157h 42m and 400 days; the minimum sits just under an hour so the
      // rounded average must not read "60 min".
      surfaceInterval: () async =>
          (avgMinutes: 9462.0, minMinutes: 59.6, maxMinutes: 576000.0),
    );

    expect(find.text('6d 13h'), findsOneWidget);
    expect(find.text('1h 0m'), findsOneWidget);
    expect(find.text('1y 35d'), findsOneWidget);
  });

  testWidgets('shows each empty state when there is nothing to chart', (
    tester,
  ) async {
    await pumpPage(
      tester,
      days: () async => const [],
      timesOfDay: () async => TimeOfDayDistribution.empty,
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
      timesOfDay: () async => TimeOfDayDistribution.empty,
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

  group('time of day chart (issue #3340)', () {
    Future<void> pumpTimeOfDay(
      WidgetTester tester,
      TimeOfDayDistribution distribution, {
      Brightness brightness = Brightness.light,
      TimeFormat? timeFormat,
    }) {
      // The footnote formats its clock times with DateFormat, which reads
      // the process-wide Intl.defaultLocale, not MaterialApp.locale. Pin it
      // so the AM/PM text cannot depend on an earlier test, and restore it.
      final previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'en';
      addTearDown(() => Intl.defaultLocale = previousLocale);
      return pumpPage(
        tester,
        days: () async => const [],
        timesOfDay: () async => distribution,
        months: () async => const [],
        surfaceInterval: () async =>
            (avgMinutes: null, minMinutes: null, maxMinutes: null),
        brightness: brightness,
        timeFormat: timeFormat,
      );
    }

    List<PieChartSectionData> sections(WidgetTester tester) =>
        tester.widget<PieChart>(find.byType(PieChart)).data.sections;

    final allFive = timeOfDay({
      'Dawn': 1,
      'Morning': 1,
      'Afternoon': 1,
      'Dusk': 1,
      'Night': 1,
    });

    testWidgets('names all five buckets', (tester) async {
      await pumpTimeOfDay(tester, allFive);

      for (final label in ['Dawn', 'Morning', 'Afternoon', 'Dusk', 'Night']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.text('Dawn, morning, afternoon, dusk or night'),
        findsOneWidget,
      );
    });

    testWidgets('uses the light palette on a light theme', (tester) async {
      await pumpTimeOfDay(tester, allFive);

      expect(sections(tester).map((s) => s.color), const [
        Color(0xFFE67E7D),
        Color(0xFFF4B41A),
        Color(0xFF2E8BC0),
        Color(0xFF845EC2),
        Color(0xFF14213D),
      ]);
    });

    testWidgets('uses the dark palette on a dark theme', (tester) async {
      await pumpTimeOfDay(tester, allFive, brightness: Brightness.dark);

      expect(sections(tester).map((s) => s.color), const [
        Color(0xFFFF9A9E),
        Color(0xFFFFE066),
        Color(0xFF00D2FC),
        Color(0xFFD387FF),
        Color(0xFFA2B2C8),
      ]);
    });

    testWidgets('a bucket keeps its colour when earlier ones are empty', (
      tester,
    ) async {
      await pumpTimeOfDay(tester, timeOfDay({'Afternoon': 2, 'Night': 1}));

      expect(sections(tester).map((s) => s.color), const [
        Color(0xFF2E8BC0),
        Color(0xFF14213D),
      ]);
    });

    testWidgets('no footnote when every dive has a site location', (
      tester,
    ) async {
      await pumpTimeOfDay(tester, timeOfDay({'Morning': 2}));

      expect(find.textContaining('no site location'), findsNothing);
    });

    testWidgets('the footnote counts dives on the default times', (
      tester,
    ) async {
      await pumpTimeOfDay(
        tester,
        timeOfDay({'Morning': 20}, divesWithoutLocation: 12),
        timeFormat: TimeFormat.twelveHour,
      );

      expect(
        find.text(
          '12 dives have no site location and use default sunrise (6:00 AM) '
          'and sunset (6:00 PM) times',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the footnote follows the 24-hour setting', (tester) async {
      await pumpTimeOfDay(
        tester,
        timeOfDay({'Morning': 20}, divesWithoutLocation: 12),
        timeFormat: TimeFormat.twentyFourHour,
      );

      expect(
        find.text(
          '12 dives have no site location and use default sunrise (06:00) '
          'and sunset (18:00) times',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the footnote reads in the singular for one dive', (
      tester,
    ) async {
      await pumpTimeOfDay(
        tester,
        timeOfDay({'Morning': 20}, divesWithoutLocation: 1),
        timeFormat: TimeFormat.twentyFourHour,
      );

      expect(
        find.text(
          '1 dive has no site location and uses default sunrise (06:00) '
          'and sunset (18:00) times',
        ),
        findsOneWidget,
      );
    });
  });
}
