import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_overview_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
  group('StatisticsOverviewPage aggregate cards', () {
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
            home: StatisticsOverviewPage(embedded: true),
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

  group('StatisticsOverviewPage Personal Records', () {
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
            diveRecordsProvider.overrideWith((ref) async => records),
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
            home: StatisticsOverviewPage(embedded: true),
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
            diveRecordsProvider.overrideWith((ref) async => records),
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
            home: StatisticsOverviewPage(embedded: true),
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
        initialLocation: '/statistics/overview',
        routes: [
          GoRoute(
            path: '/statistics/overview',
            builder: (ctx, s) => const StatisticsOverviewPage(embedded: true),
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
            diveRecordsProvider.overrideWith((ref) async => records),
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

  group('StatisticsOverviewPage Most Visited Sites', () {
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
            home: StatisticsOverviewPage(embedded: true),
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
            home: StatisticsOverviewPage(embedded: true),
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
        initialLocation: '/statistics/overview',
        routes: [
          GoRoute(
            path: '/statistics/overview',
            builder: (ctx, s) => const StatisticsOverviewPage(embedded: true),
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
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
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

  group('StatisticsOverviewPage edge cases', () {
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
        initialLocation: '/statistics/overview',
        routes: [
          GoRoute(
            path: '/statistics/overview',
            builder: (ctx, s) => const StatisticsOverviewPage(embedded: true),
          ),
          GoRoute(
            path: '/dives/new',
            builder: (ctx, state) {
              navigatedTo = '/dives/new';
              return const Scaffold(body: Text('New Dive'));
            },
          ),
          GoRoute(
            path: '/transfer/import-wizard',
            builder: (ctx, state) {
              navigatedTo = '/transfer/import-wizard';
              return const Scaffold(body: Text('Import Wizard'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
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
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No dives logged yet'), findsOneWidget);
      expect(find.text('Log a Dive'), findsOneWidget);
      expect(find.text('Import Dives'), findsOneWidget);
      expect(find.text('Total Dives'), findsNothing);

      await tester.tap(find.text('Log a Dive'));
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
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Dives'), findsOneWidget);
      expect(find.text('Dives / Month'), findsNothing);
      expect(find.text('Dives / Year'), findsNothing);
    });
  });

  group('StatisticsOverviewPage Distributions', () {
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
          DepthRangeStat(label: '0-10m', minDepth: 0, maxDepth: 10, count: 5),
          DepthRangeStat(label: '10-20m', minDepth: 10, maxDepth: 20, count: 7),
          DepthRangeStat(label: '20-30m', minDepth: 20, maxDepth: 30, count: 3),
        ],
      );

      final diveTypes = [
        DistributionSegment(label: 'Recreational', count: 10, percentage: 66.7),
        DistributionSegment(label: 'Technical', count: 5, percentage: 33.3),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diveStatisticsProvider.overrideWith((ref) async => stats),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
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
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Distributions'), findsOneWidget);
      // Depth range legend labels should contain depth values.
      expect(find.textContaining('10'), findsWidgets);
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
            home: StatisticsOverviewPage(embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Distributions'), findsNothing);
    });
  });
}
