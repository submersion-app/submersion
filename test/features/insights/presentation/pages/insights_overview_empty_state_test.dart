import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/domain/logbook_dive_counts.dart';
import 'package:submersion/features/insights/presentation/pages/insights_overview_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _onboardingTitle = 'No dives logged yet';
const _onboardingAction = 'Log Your First Dive';
const _noMatchTitle = 'No dives match your filters';
const _clearFilters = 'Clear Filters';
const _allExcludedTitle = 'All your dives are excluded from statistics';

final _zero = DiveStatistics(
  totalDives: 0,
  totalTimeSeconds: 0,
  maxDepth: 0,
  avgMaxDepth: 0,
  totalSites: 0,
);

final _activeFilter = DiveFilterState(startDate: DateTime.utc(2030));

Future<void> _pump(
  WidgetTester tester, {
  required Object counts,
  DiveFilterState? filter,
  int excluded = 0,
  Diver? diver,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        filteredDiveStatisticsProvider.overrideWith((ref) async => _zero),
        currentDiverProvider.overrideWith((ref) async => diver),
        insightsFilterProvider.overrideWith(
          (ref) => filter ?? const DiveFilterState(),
        ),
        excludedDiveCountProvider.overrideWith((ref) async => excluded),
        logbookDiveCountsProvider.overrideWith((ref) {
          return switch (counts) {
            final LogbookDiveCounts value => Future.value(value),
            final Future<LogbookDiveCounts> pending => pending,
            final Object error => Future.error(error),
          };
        }),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: InsightsOverviewPage(embedded: true)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('a filter matching none of the logged dives', () {
    testWidgets('says so instead of offering a first dive', (tester) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 12, counted: 12),
        filter: _activeFilter,
      );

      expect(find.text(_noMatchTitle), findsOneWidget);
      expect(find.text(_onboardingTitle), findsNothing);
      expect(find.text(_onboardingAction), findsNothing);
    });

    testWidgets('can be cleared from the empty state', (tester) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 12, counted: 12),
        filter: _activeFilter,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InsightsOverviewPage)),
      );

      await tester.tap(find.text(_clearFilters));
      await tester.pump();

      expect(container.read(insightsFilterProvider).hasActiveFilters, isFalse);
    });

    testWidgets('still names dives the diver excluded', (tester) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 12, counted: 9),
        filter: _activeFilter,
        excluded: 3,
      );

      expect(find.text(_noMatchTitle), findsOneWidget);
      expect(find.text('3 dives excluded from statistics'), findsOneWidget);
    });

    testWidgets('hides the footnote when nothing is excluded', (tester) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 12, counted: 12),
        filter: _activeFilter,
      );

      expect(find.byKey(const Key('insights-excluded-footnote')), findsNothing);
    });

    testWidgets('leaves prior experience out of the decision', (tester) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 12, counted: 12),
        filter: _activeFilter,
        diver: Diver(
          id: 'd1',
          name: 'A',
          priorDiveCount: 1200,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      expect(find.text(_noMatchTitle), findsOneWidget);
      expect(find.text(_onboardingTitle), findsNothing);
    });
  });

  group('a logbook with every dive excluded', () {
    testWidgets('explains the exclusion with its count', (tester) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 3, counted: 0),
        excluded: 3,
      );

      expect(find.text(_allExcludedTitle), findsOneWidget);
      expect(find.text('3 dives excluded from statistics'), findsOneWidget);
      expect(find.text(_onboardingTitle), findsNothing);
      expect(find.text(_onboardingAction), findsNothing);
    });

    testWidgets('outranks an active filter, which clearing cannot fix', (
      tester,
    ) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 3, counted: 0),
        filter: _activeFilter,
        excluded: 3,
      );

      expect(find.text(_allExcludedTitle), findsOneWidget);
      expect(find.text(_noMatchTitle), findsNothing);
      expect(find.text(_clearFilters), findsNothing);
    });
  });

  group('a logbook with no logged dives', () {
    testWidgets('keeps the first-dive onboarding', (tester) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 0, counted: 0),
      );

      expect(find.text(_onboardingTitle), findsOneWidget);
      expect(find.text(_onboardingAction), findsOneWidget);
      expect(find.text(_noMatchTitle), findsNothing);
      expect(find.text(_allExcludedTitle), findsNothing);
    });

    testWidgets('keeps it under a filter, which has nothing to match', (
      tester,
    ) async {
      await _pump(
        tester,
        counts: const LogbookDiveCounts(logged: 0, counted: 0),
        filter: _activeFilter,
      );

      expect(find.text(_onboardingTitle), findsOneWidget);
      expect(find.text(_noMatchTitle), findsNothing);
    });
  });

  group('while the logbook counts are unknown', () {
    testWidgets('loading shows a loader, never the onboarding', (tester) async {
      final pending = Completer<LogbookDiveCounts>();
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            filteredDiveStatisticsProvider.overrideWith((ref) async => _zero),
            currentDiverProvider.overrideWith((ref) async => null),
            logbookDiveCountsProvider.overrideWith((ref) => pending.future),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: InsightsOverviewPage(embedded: true)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_onboardingTitle), findsNothing);

      pending.complete(const LogbookDiveCounts(logged: 0, counted: 0));
      await tester.pumpAndSettle();
      expect(find.text(_onboardingTitle), findsOneWidget);
    });

    testWidgets('an error offers a retry, never the onboarding', (
      tester,
    ) async {
      await _pump(tester, counts: StateError('database unavailable'));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text(_onboardingTitle), findsNothing);
    });
  });
}
