import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_summary_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_filter_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_summary_widget.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveSummaryWidget bottomTime coverage', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('displays longest dive using runtime when set', (tester) async {
      final dive = createTestDiveWithBottomTime(
        bottomTime: null,
        runtime: const Duration(minutes: 123),
        maxDepth: 25.0,
        waterTemp: 22.0,
      );
      await repository.createDive(dive);

      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveStatisticsProvider.overrideWith((ref) async {
              return repository.getStatistics();
            }),
            diveRecordsProvider.overrideWith((ref) async {
              return repository.getRecords();
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('123 min'), findsOneWidget);
    });

    testWidgets('displays longest dive using bottomTime when runtime is null', (
      tester,
    ) async {
      final dive = createTestDiveWithBottomTime(
        bottomTime: const Duration(minutes: 45),
        runtime: null,
        maxDepth: 25.0,
        waterTemp: 22.0,
      );
      await repository.createDive(dive);

      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveStatisticsProvider.overrideWith((ref) async {
              return repository.getStatistics();
            }),
            diveRecordsProvider.overrideWith((ref) async {
              return repository.getRecords();
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets('handles empty records', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveRepositoryProvider.overrideWithValue(repository),
            diveStatisticsProvider.overrideWith((ref) async {
              return repository.getStatistics();
            }),
            diveRecordsProvider.overrideWith((ref) async {
              return repository.getRecords();
            }),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render without crashing
      expect(find.byType(DiveSummaryWidget), findsOneWidget);
    });
  });

  group('DiveSummaryWidget career totals (#808)', () {
    Future<void> pumpWithDiver(WidgetTester tester, Diver? diver) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveStatisticsProvider.overrideWith(
              (ref) async => DiveStatistics(
                totalDives: 247,
                totalTimeSeconds: 669600, // 186h 0m
                maxDepth: 52.0,
                avgMaxDepth: 27.5,
                totalSites: 83,
              ),
            ),
            diveRecordsProvider.overrideWith((ref) async => DiveRecords()),
            currentDiverProvider.overrideWith((ref) async => diver),
          ].cast(),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('adds prior dives and time, with a breakdown', (tester) async {
      await pumpWithDiver(
        tester,
        Diver(
          id: '1',
          name: 'Eric Griffin',
          priorDiveCount: 125,
          priorDiveTimeSeconds: 360000, // 100h 0m
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      expect(find.text('372'), findsOneWidget);
      expect(find.text('286h 0m'), findsOneWidget);
      expect(find.text('247 logged + 125 prior'), findsOneWidget);
      expect(find.text('186h 0m logged + 100h 0m prior'), findsOneWidget);
    });

    testWidgets('shows logged totals alone without priors', (tester) async {
      await pumpWithDiver(
        tester,
        Diver(
          id: '1',
          name: 'Eric Griffin',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      expect(find.text('247'), findsOneWidget);
      expect(find.text('186h 0m'), findsOneWidget);
      expect(find.textContaining('prior'), findsNothing);
    });
  });

  group('DiveSummaryWidget under a dive list filter (#1078)', () {
    final diverWithPriors = Diver(
      id: '1',
      name: 'Eric Griffin',
      priorDiveCount: 125,
      priorDiveTimeSeconds: 360000, // 100h 0m
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    DiveRecords longestOf(String diveId, int minutes) => DiveRecords(
      longestDive: DiveRecord(
        diveId: diveId,
        dateTime: DateTime(2026, 3, 1),
        runtime: Duration(minutes: minutes),
      ),
    );

    Future<void> pump(
      WidgetTester tester,
      DiveFilterState filter, {
      Locale locale = const Locale('en'),
      Future<DiveStatistics> Function(DiveFilterState filter)? scopedStatsFor,
    }) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveFilterProvider.overrideWith((ref) => filter),
            diveStatisticsProvider.overrideWith(
              (ref) async => DiveStatistics(
                totalDives: 247,
                totalTimeSeconds: 669600, // 186h 0m
                maxDepth: 52.0,
                avgMaxDepth: 27.5,
                totalSites: 83,
              ),
            ),
            diveListScopedStatisticsProvider.overrideWith((ref) {
              final current = ref.watch(diveFilterProvider);
              return scopedStatsFor?.call(current) ??
                  Future.value(
                    DiveStatistics(
                      totalDives: 34,
                      totalTimeSeconds: 7200, // 2h 0m
                      maxDepth: 31.0,
                      avgMaxDepth: 22.0,
                      totalSites: 4,
                    ),
                  );
            }),
            diveRecordsProvider.overrideWith(
              (ref) async => longestOf('lifetime', 123),
            ),
            diveListScopedRecordsProvider.overrideWith(
              (ref) async => longestOf('filtered', 45),
            ),
            currentDiverProvider.overrideWith((ref) async => diverWithPriors),
          ].cast(),
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DiveSummaryWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const siteFilter = DiveFilterState(siteIds: ['site-a']);

    testWidgets('without a filter, shows career totals and no banner', (
      tester,
    ) async {
      await pump(tester, const DiveFilterState());

      expect(find.text('372'), findsOneWidget);
      expect(find.text('247 logged + 125 prior'), findsOneWidget);
      expect(find.text('123 min'), findsOneWidget);
      expect(find.textContaining('Filtered'), findsNothing);
      expect(find.text('Clear Filters'), findsNothing);
    });

    testWidgets('with a filter, totals cover the filtered dives only', (
      tester,
    ) async {
      await pump(tester, siteFilter);

      expect(find.text('34'), findsOneWidget);
      expect(find.text('2h 0m'), findsOneWidget);
      expect(
        find.textContaining('prior'),
        findsNothing,
        reason:
            'prior dives carry no site, trip or buddy, so no filter '
            'can match them',
      );
      expect(find.text('372'), findsNothing);
    });

    testWidgets('with a filter, records come from the filtered dives', (
      tester,
    ) async {
      await pump(tester, siteFilter);

      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('123 min'), findsNothing);
    });

    testWidgets('with a filter, a banner says how many dives it covers', (
      tester,
    ) async {
      await pump(tester, siteFilter);

      expect(
        find.text('Filtered: summarizing 34 of 247 dives'),
        findsOneWidget,
      );
    });

    testWidgets('the banner mirrors its insets in right-to-left locales', (
      tester,
    ) async {
      await pump(tester, siteFilter, locale: const Locale('he'));

      final banner = tester.getRect(find.byType(DiveSummaryFilterBanner));
      final icon = tester.getRect(find.byIcon(Icons.filter_list));
      expect(
        banner.right - icon.right,
        16,
        reason: 'the icon leads the row, so in RTL it takes the start inset',
      );
    });

    testWidgets('"All dives" with nothing typed counts as unfiltered', (
      tester,
    ) async {
      // The axes stay set but suspended (#2773), so the list shows every
      // dive; the summary must too.
      await pump(
        tester,
        const DiveFilterState(siteIds: ['site-a'], axesSuspended: true),
      );

      expect(find.textContaining('Filtered'), findsNothing);
      expect(find.text('372'), findsOneWidget);
      expect(find.text('247 logged + 125 prior'), findsOneWidget);
    });

    testWidgets('the banner keeps its counts while a filter edit reloads', (
      tester,
    ) async {
      final pending = Completer<DiveStatistics>();
      addTearDown(() {
        if (!pending.isCompleted) {
          pending.complete(
            DiveStatistics(
              totalDives: 0,
              totalTimeSeconds: 0,
              maxDepth: 0,
              avgMaxDepth: 0,
              totalSites: 0,
            ),
          );
        }
      });
      await pump(
        tester,
        siteFilter,
        scopedStatsFor: (filter) => filter == siteFilter
            ? Future.value(
                DiveStatistics(
                  totalDives: 34,
                  totalTimeSeconds: 7200,
                  maxDepth: 31.0,
                  avgMaxDepth: 22.0,
                  totalSites: 4,
                ),
              )
            : pending.future,
      );
      expect(
        find.text('Filtered: summarizing 34 of 247 dives'),
        findsOneWidget,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveSummaryWidget)),
      );
      container.read(diveFilterProvider.notifier).state = const DiveFilterState(
        siteIds: ['site-b'],
      );
      await tester.pump();

      expect(
        find.text('Filtered: summarizing 34 of 247 dives'),
        findsOneWidget,
        reason:
            'like the cards below it, the banner keeps the previous '
            'counts until the new query lands rather than blanking',
      );
    });

    testWidgets('Clear Filters clears the dive list filter', (tester) async {
      await pump(tester, siteFilter);

      await tester.tap(find.text('Clear Filters'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveSummaryWidget)),
      );
      expect(container.read(diveFilterProvider).hasActiveFilters, isFalse);
      expect(find.textContaining('Filtered'), findsNothing);
      expect(find.text('372'), findsOneWidget);
    });
  });
}
