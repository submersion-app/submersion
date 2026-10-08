import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every MaterialApp here pins `locale: Locale('en')`. flutter_test forwards
/// the HOST machine's locale list rather than a fixed en_US, and the app ships
/// 11 locales, so an unpinned MaterialApp renders a translated UI on a
/// non-English machine and every English assertion in this file misses. CI
/// runners are en_US, so the failure would only ever show up on a
/// contributor's machine.

/// Minimal mock SettingsNotifier using noSuchMethod to avoid re-implementing
/// the full interface (~60 methods). Matches the pattern used in
/// localization_test.dart and other test files.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock CurrentDiverIdNotifier that does not access the database.
class _MockCurrentDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _MockCurrentDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

void main() {
  group('InsightsOverviewPage aggregate cards', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders total dives, total time, max depth, and sites', (
      tester,
    ) async {
      final fixture = DiveStatistics(
        totalDives: 42,
        totalTimeSeconds: 108000, // 30h 0m
        maxDepth: 38.5,
        avgMaxDepth: 18.2,
        avgTemperature: 24.0,
        totalSites: 7,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 730)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => fixture),
            filteredDiveStatisticsProvider.overrideWith((ref) async => fixture),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget); // total dives
      expect(find.textContaining('30h'), findsOneWidget); // total time
      expect(
        find.textContaining('7'),
        findsWidgets,
      ); // sites (may appear elsewhere)
    });
  });

  group('InsightsOverviewPage Personal Records', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders deepest and longest records', (tester) async {
      final stats = DiveStatistics(
        totalDives: 10,
        totalTimeSeconds: 18000,
        maxDepth: 35.0,
        avgMaxDepth: 20.0,
        totalSites: 3,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
      );
      final deepest = DiveRecord(
        diveId: 'd1',
        diveNumber: 5,
        dateTime: DateTime(2025, 1, 10),
        maxDepth: 35.0,
        bottomTime: const Duration(minutes: 40),
      );
      final longest = DiveRecord(
        diveId: 'd2',
        diveNumber: 3,
        dateTime: DateTime(2025, 2, 15),
        maxDepth: 20.0,
        bottomTime: const Duration(minutes: 60),
      );
      final records = DiveRecords(deepestDive: deepest, longestDive: longest);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith((ref) async => records),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Records'), findsOneWidget);
      expect(find.text('Deepest Dive'), findsOneWidget);
      expect(find.text('Longest Dive'), findsOneWidget);
    });

    testWidgets('collapses to First Dive when all records are the same dive', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 1,
        totalTimeSeconds: 2400,
        maxDepth: 15.0,
        avgMaxDepth: 15.0,
        totalSites: 1,
      );
      final singleDive = DiveRecord(
        diveId: 'only-dive',
        diveNumber: 1,
        dateTime: DateTime(2025, 6, 1),
        maxDepth: 15.0,
        bottomTime: const Duration(minutes: 40),
        waterTemp: 22.0,
      );
      // All four record slots point to the same dive.
      final records = DiveRecords(
        deepestDive: singleDive,
        longestDive: singleDive,
        coldestDive: singleDive,
        warmestDive: singleDive,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith((ref) async => records),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal Records'), findsOneWidget);
      expect(find.text('First Dive'), findsOneWidget);
      expect(find.text('Deepest Dive'), findsNothing);
      expect(find.text('Longest Dive'), findsNothing);
      expect(find.text('Coldest Dive'), findsNothing);
      expect(find.text('Warmest Dive'), findsNothing);
    });

    testWidgets('tapping a record navigates to dive detail', (tester) async {
      final stats = DiveStatistics(
        totalDives: 2,
        totalTimeSeconds: 6000,
        maxDepth: 20,
        avgMaxDepth: 18,
        totalSites: 1,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 60)),
      );
      final deepest = DiveRecord(
        diveId: 'dive-xyz',
        diveNumber: 2,
        dateTime: DateTime(2025, 3, 1),
        maxDepth: 20,
        bottomTime: const Duration(seconds: 3000),
      );
      final longest = DiveRecord(
        diveId: 'dive-abc',
        diveNumber: 1,
        dateTime: DateTime(2025, 2, 1),
        maxDepth: 16,
        bottomTime: const Duration(seconds: 3600),
      );
      final records = DiveRecords(deepestDive: deepest, longestDive: longest);

      String? navigatedTo;
      final router = GoRouter(
        initialLocation: '/insights/overview',
        routes: [
          GoRoute(
            path: '/insights/overview',
            builder: (ctx, s) => const InsightsOverviewPage(embedded: true),
          ),
          GoRoute(
            path: '/dives/:id',
            builder: (ctx, state) {
              navigatedTo = '/dives/${state.pathParameters['id']}';
              return const Scaffold(body: Text('Dive Detail'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith((ref) async => records),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deepest Dive'));
      await tester.pumpAndSettle();

      expect(navigatedTo, equals('/dives/dive-xyz'));
    });
  });

  group('InsightsOverviewPage Most Visited Sites', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders top sites from stats.topSites', (tester) async {
      final stats = DiveStatistics(
        totalDives: 20,
        totalTimeSeconds: 36000,
        maxDepth: 30.0,
        avgMaxDepth: 18.0,
        totalSites: 3,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
        topSites: [
          TopSiteStat(siteId: 'site-1', siteName: 'Blue Hole', diveCount: 10),
          TopSiteStat(siteId: 'site-2', siteName: 'Coral Garden', diveCount: 7),
          TopSiteStat(siteId: 'site-3', siteName: 'The Wall', diveCount: 3),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Most Visited Sites'), findsOneWidget);
      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.text('Coral Garden'), findsOneWidget);
      expect(find.text('The Wall'), findsOneWidget);
    });

    testWidgets('hides section when topSites is empty', (tester) async {
      final stats = DiveStatistics(
        totalDives: 5,
        totalTimeSeconds: 9000,
        maxDepth: 20.0,
        avgMaxDepth: 15.0,
        totalSites: 0,
        topSites: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Most Visited Sites'), findsNothing);
    });

    testWidgets('tapping a site navigates to site detail', (tester) async {
      final stats = DiveStatistics(
        totalDives: 10,
        totalTimeSeconds: 18000,
        maxDepth: 25.0,
        avgMaxDepth: 15.0,
        totalSites: 1,
        topSites: [
          TopSiteStat(
            siteId: 'site-abc',
            siteName: 'Mystery Cave',
            diveCount: 10,
          ),
        ],
      );

      String? navigatedTo;
      final router = GoRouter(
        initialLocation: '/insights/overview',
        routes: [
          GoRoute(
            path: '/insights/overview',
            builder: (ctx, s) => const InsightsOverviewPage(embedded: true),
          ),
          GoRoute(
            path: '/sites/:siteId',
            builder: (ctx, state) {
              navigatedTo = '/sites/${state.pathParameters['siteId']}';
              return const Scaffold(body: Text('Site Detail'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mystery Cave'));
      await tester.pumpAndSettle();

      expect(navigatedTo, equals('/sites/site-abc'));
    });
  });

  group('InsightsOverviewPage edge cases', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('zero dives shows empty state with action buttons', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 0,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );

      String? navigatedTo;
      final router = GoRouter(
        initialLocation: '/insights/overview',
        routes: [
          GoRoute(
            path: '/insights/overview',
            builder: (ctx, s) => const InsightsOverviewPage(embedded: true),
          ),
          GoRoute(
            path: '/dives/new',
            builder: (ctx, state) {
              navigatedTo = '/dives/new';
              return const Scaffold(body: Text('New Dive'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No dives logged yet'), findsOneWidget);
      expect(
        find.text('Tap the button below to log your first dive'),
        findsOneWidget,
      );
      expect(find.text('Log Your First Dive'), findsOneWidget);
      expect(find.text('Total Dives'), findsNothing);

      // The button opens the same add-dive sheet as the dive list empty state.
      await tester.tap(find.text('Log Your First Dive'));
      await tester.pumpAndSettle();
      expect(find.text('Log Dive Manually'), findsOneWidget);
      expect(find.text('Import from Computer'), findsOneWidget);
      expect(find.text('Scan Paper Log'), findsOneWidget);

      await tester.tap(find.text('Log Dive Manually'));
      await tester.pumpAndSettle();
      expect(navigatedTo, equals('/dives/new'));
    });

    testWidgets('tenure under 1 month hides Dives/Month and Dives/Year cards', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 3,
        totalTimeSeconds: 5400,
        maxDepth: 18.0,
        avgMaxDepth: 12.0,
        totalSites: 1,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 10)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Dives'), findsOneWidget);
      expect(find.text('Avg Dives / Month'), findsNothing);
      expect(find.text('Avg Dives / Year'), findsNothing);
      // This year's count has no tenure requirement.
      expect(find.text('Dives This Year'), findsOneWidget);
    });

    // Issue #2600: the per-year card is a lifetime average, and a diver read
    // "Dives / Year" as this year's total. The average says it is an average,
    // and the actual count for the current year sits beside it.
    testWidgets('labels the averages and shows this year\'s actual count', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 501,
        totalTimeSeconds: 5400,
        maxDepth: 18.0,
        avgMaxDepth: 12.0,
        totalSites: 1,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 1826)),
        divesThisYear: 124,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avg Dives / Month'), findsOneWidget);
      expect(find.text('Avg Dives / Year'), findsOneWidget);
      expect(find.text('Dives / Year'), findsNothing);
      expect(find.text('Dives This Year'), findsOneWidget);
      expect(find.text('124'), findsOneWidget);
    });
  });

  group('InsightsOverviewPage Distributions', () {
    late SharedPreferences prefs;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('renders depth and type pies when data is present', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 15,
        totalTimeSeconds: 27000,
        maxDepth: 30.0,
        avgMaxDepth: 18.0,
        totalSites: 2,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
        depthDistribution: [
          DepthRangeStat(
            label: '0-10m',
            minDepth: 0,
            maxDepth: 10,
            count: 5,
            totalDurationSeconds: 18000, // 5h 0m
          ),
          DepthRangeStat(
            label: '10-20m',
            minDepth: 10,
            maxDepth: 20,
            count: 7,
            totalDurationSeconds: 27000, // 7h 30m
          ),
          DepthRangeStat(
            label: '20-30m',
            minDepth: 20,
            maxDepth: 30,
            count: 3,
            totalDurationSeconds: 11700, // 3h 15m
          ),
        ],
      );

      final diveTypes = [
        DistributionSegment(
          label: 'Recreational',
          count: 10,
          percentage: 66.7,
          totalDurationSeconds: 36000, // 10h 0m
        ),
        DistributionSegment(
          label: 'Technical',
          count: 5,
          percentage: 33.3,
          totalDurationSeconds: 19800, // 5h 30m
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => diveTypes),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Distributions'), findsOneWidget);
      // Depth range legend labels should contain depth values.
      expect(find.textContaining('10'), findsWidgets);
      // Per-depth-bucket count + total dive time list (issue #641 follow-up).
      // The bucket label also appears once in the pie chart's own legend
      // above the list.
      expect(find.text('0-10m'), findsNWidgets(2));
      expect(find.text('5 dives • 5h 0m'), findsOneWidget);
      expect(find.text('10-20m'), findsNWidgets(2));
      expect(find.text('7 dives • 7h 30m'), findsOneWidget);
      expect(find.text('20-30m'), findsNWidgets(2));
      expect(find.text('3 dives • 3h 15m'), findsOneWidget);
      // Per-type count + total dive time list (issue #641). The type name
      // also appears once in the pie chart's own legend above the list.
      expect(find.text('Recreational'), findsNWidgets(2));
      expect(find.text('10 dives • 10h 0m'), findsOneWidget);
      expect(find.text('Technical'), findsNWidgets(2));
      expect(find.text('5 dives • 5h 30m'), findsOneWidget);
    });

    testWidgets(
      'colors each bar to match its pie slice and sizes it by count',
      (tester) async {
        final stats = DiveStatistics(
          totalDives: 15,
          totalTimeSeconds: 27000,
          maxDepth: 30.0,
          avgMaxDepth: 18.0,
          totalSites: 2,
          firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
          depthDistribution: [
            DepthRangeStat(
              label: '0-10m',
              minDepth: 0,
              maxDepth: 10,
              count: 5,
              totalDurationSeconds: 18000,
            ),
            DepthRangeStat(
              label: '10-20m',
              minDepth: 10,
              maxDepth: 20,
              count: 7,
              totalDurationSeconds: 27000,
            ),
            DepthRangeStat(
              label: '20-30m',
              minDepth: 20,
              maxDepth: 30,
              count: 3,
              totalDurationSeconds: 11700,
            ),
          ],
        );

        final diveTypes = [
          DistributionSegment(
            label: 'Recreational',
            count: 10,
            percentage: 66.7,
            totalDurationSeconds: 36000,
          ),
          DistributionSegment(
            label: 'Technical',
            count: 5,
            percentage: 33.3,
            totalDurationSeconds: 19800,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              diveStatisticsProvider.overrideWith((ref) async => stats),
              filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
              filteredDiveRecordsProvider.overrideWith(
                (ref) async => DiveRecords(),
              ),
              diveTypeDistributionProvider.overrideWith(
                (ref) async => diveTypes,
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
              settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
              currentDiverIdProvider.overrideWith(
                (ref) => _MockCurrentDiverIdNotifier(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('en'),
              home: InsightsOverviewPage(embedded: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pieCharts = tester
            .widgetList<PieChart>(find.byType(PieChart))
            .toList();
        final depthPieColors = pieCharts[0].data.sections
            .map((s) => s.color)
            .toList();
        final typePieColors = pieCharts[1].data.sections
            .map((s) => s.color)
            .toList();

        Color fillColor(Key key) {
          final container = tester.widget<Container>(find.byKey(key));
          return (container.decoration as BoxDecoration).color!;
        }

        expect(
          fillColor(const ValueKey('depth-bar-fill-0')),
          depthPieColors[0],
        );
        expect(
          fillColor(const ValueKey('depth-bar-fill-1')),
          depthPieColors[1],
        );
        expect(
          fillColor(const ValueKey('depth-bar-fill-2')),
          depthPieColors[2],
        );
        expect(fillColor(const ValueKey('type-bar-fill-0')), typePieColors[0]);
        expect(fillColor(const ValueKey('type-bar-fill-1')), typePieColors[1]);

        // 10-20m (count 7) is the largest depth bucket, so its bar is wider
        // than the 0-10m (5) and 20-30m (3) buckets either side of it.
        final width0 = tester
            .getSize(find.byKey(const ValueKey('depth-bar-fill-0')))
            .width;
        final width1 = tester
            .getSize(find.byKey(const ValueKey('depth-bar-fill-1')))
            .width;
        final width2 = tester
            .getSize(find.byKey(const ValueKey('depth-bar-fill-2')))
            .width;
        expect(width1, greaterThan(width0));
        expect(width0, greaterThan(width2));
      },
    );

    testWidgets('keeps a small bucket bar visible next to a much larger one', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 408,
        totalTimeSeconds: 1000000,
        maxDepth: 40.0,
        avgMaxDepth: 30.0,
        totalSites: 2,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
        depthDistribution: [
          DepthRangeStat(
            label: '0-10m',
            minDepth: 0,
            maxDepth: 10,
            count: 1,
            totalDurationSeconds: 3600,
          ),
          DepthRangeStat(
            label: '30-40m',
            minDepth: 30,
            maxDepth: 40,
            count: 407,
            totalDurationSeconds: 999999,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tinyWidth = tester
          .getSize(find.byKey(const ValueKey('depth-bar-fill-0')))
          .width;
      expect(tinyWidth, greaterThan(2.0));
    });

    testWidgets('does not overflow with very large counts and durations', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 12345,
        totalTimeSeconds: 999999999,
        maxDepth: 40.0,
        avgMaxDepth: 30.0,
        totalSites: 2,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
        depthDistribution: [
          DepthRangeStat(
            label: '0-10m',
            minDepth: 0,
            maxDepth: 10,
            count: 1,
            totalDurationSeconds: 3600,
          ),
          DepthRangeStat(
            label: '30-40m',
            minDepth: 30,
            maxDepth: 40,
            count: 12345,
            totalDurationSeconds: 999999999,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('caps the depth pie legend at 6 rows but lists every occupied '
        'bucket underneath (issue #641 follow-up: legend overflow)', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 8,
        totalTimeSeconds: 28800,
        maxDepth: 80.0,
        avgMaxDepth: 40.0,
        totalSites: 1,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 365)),
        depthDistribution: [
          for (var i = 0; i < 8; i++)
            DepthRangeStat(
              label: '${i * 10}-${(i + 1) * 10}m',
              minDepth: i * 10,
              maxDepth: (i + 1) * 10,
              count: 1,
              totalDurationSeconds: 3600,
            ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The 8th bucket (70-80m) only appears once: in the full list below
      // the chart, not in the space-limited inline legend.
      expect(find.text('70-80m'), findsOneWidget);
      // Every bucket's count + time is listed in full underneath the pies.
      expect(find.text('1 dive • 1h 0m'), findsNWidgets(8));
    });

    // Issue #3075: the pie legend and the stats list below it resolved a
    // custom dive type's name from no typesById, so it fell through to plain
    // slug capitalization instead of the diver's own name.
    testWidgets('shows the diver\'s own name for a custom dive type', (
      tester,
    ) async {
      final stats = DiveStatistics(
        totalDives: 3,
        totalTimeSeconds: 5400,
        maxDepth: 20.0,
        avgMaxDepth: 20.0,
        totalSites: 1,
        firstDiveDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      final diveTypes = [
        DistributionSegment(
          label: 'dpv',
          count: 3,
          percentage: 100,
          totalDurationSeconds: 5400,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => diveTypes),
            diveTypesProvider.overrideWith(
              (ref) async => [
                DiveTypeEntity(
                  id: 'dpv',
                  diverId: 'diver-1',
                  name: 'DPV',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                ),
              ],
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pie legend and stats list, same as the built-in-type case above.
      expect(find.text('DPV'), findsNWidgets(2));
      expect(find.text('Dpv'), findsNothing);
    });

    testWidgets('hides Distributions when totalDives is 0', (tester) async {
      final stats = DiveStatistics(
        totalDives: 0,
        totalTimeSeconds: 0,
        maxDepth: 0,
        avgMaxDepth: 0,
        totalSites: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveStatisticsProvider.overrideWith((ref) async => stats),
            filteredDiveRecordsProvider.overrideWith(
              (ref) async => DiveRecords(),
            ),
            diveTypeDistributionProvider.overrideWith((ref) async => []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => _MockCurrentDiverIdNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: InsightsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Distributions'), findsNothing);
    });
  });
}
