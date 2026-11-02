import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_bar.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_group_menu.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  final coldNode = ConditionNode(
    FieldPath(const ['waterTemp']),
    QueryOp.lte,
    const NumberValue(15, null),
  );
  final warmNode = ConditionNode(
    FieldPath(const ['waterTemp']),
    QueryOp.gte,
    const NumberValue(24, null),
  );

  SavedQueryLoad load(
    String name,
    QueryNode? node, {
    SavedQueryProblem? problem,
  }) => SavedQueryLoad(
    SavedQuery(
      id: name,
      subject: 'dives',
      name: name,
      queryJson: '{}',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    node: node,
    problem: problem,
  );

  Future<ProviderContainer> pumpBar(
    WidgetTester tester, {
    DiveFilterState filter = const DiveFilterState(),
    List<SavedQueryLoad> saved = const [],
    int count = 5,
    double width = 400,
    Future<void> Function(BuildContext, WidgetRef, QueryNode)? saver,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsFilterProvider.overrideWith((ref) => filter),
          filteredDiveStatisticsProvider.overrideWith(
            (ref) async => DiveStatistics(
              totalDives: count,
              totalTimeSeconds: 0,
              maxDepth: 0,
              avgMaxDepth: 0,
              totalSites: 0,
            ),
          ),
          savedQueryLoadsProvider('dives').overrideWith((ref) async => saved),
          if (saver != null)
            diveSearchSaverProvider.overrideWith((ref) => saver),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, child: const InsightsFilterBar()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(InsightsFilterBar)),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(kInsightsGroupMenuKey));
    await tester.pumpAndSettle();
  }

  group('the row', () {
    testWidgets('names All dives and the total while nothing is selected', (
      tester,
    ) async {
      await pumpBar(tester, count: 512);

      expect(find.text('All dives'), findsOneWidget);
      expect(find.text('512 dives'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('names the selected group, with its count and a clear', (
      tester,
    ) async {
      await pumpBar(
        tester,
        filter: DiveFilterState(query: coldNode),
        saved: [load('Cold water', coldNode)],
        count: 143,
      );

      expect(find.text('Cold water'), findsOneWidget);
      expect(find.text('143 dives'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('says Custom filter for a filter no group matches', (
      tester,
    ) async {
      await pumpBar(
        tester,
        filter: const DiveFilterState(favoritesOnly: true),
        saved: [load('Cold water', coldNode)],
      );

      expect(find.text('Custom filter'), findsOneWidget);
      expect(find.text('Cold water'), findsNothing);
    });

    testWidgets('tapping clear resets the Insights filter', (tester) async {
      final container = await pumpBar(
        tester,
        filter: const DiveFilterState(favoritesOnly: true),
      );
      expect(container.read(insightsFilterProvider).hasActiveFilters, true);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(container.read(insightsFilterProvider).hasActiveFilters, false);
    });

    testWidgets('the count keeps its width beside a short name', (
      tester,
    ) async {
      await pumpBar(
        tester,
        filter: DiveFilterState(query: coldNode),
        saved: [load('Cold', coldNode)],
        count: 1234,
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('1234 dives'),
      );
      expect(paragraph.didExceedMaxLines, false);
    });

    testWidgets('a long group name fits a narrow pane', (tester) async {
      await pumpBar(
        tester,
        filter: DiveFilterState(query: coldNode),
        saved: [load('A very long name for a saved group of dives', coldNode)],
        count: 1234,
        width: 240,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('1234 dives'), findsOneWidget);
    });
  });

  group('the menu', () {
    testWidgets('lists All dives, then every group in order', (tester) async {
      await pumpBar(
        tester,
        saved: [load('Cold water', coldNode), load('Warm water', warmNode)],
      );

      await openMenu(tester);

      expect(find.text('Cold water'), findsOneWidget);
      expect(find.text('Warm water'), findsOneWidget);
      final all = tester.getTopLeft(find.text('All dives').last);
      final cold = tester.getTopLeft(find.text('Cold water'));
      final warm = tester.getTopLeft(find.text('Warm water'));
      expect(all.dy, lessThan(cold.dy));
      expect(cold.dy, lessThan(warm.dy));
    });

    testWidgets('picking a group replaces the whole Insights filter', (
      tester,
    ) async {
      final container = await pumpBar(
        tester,
        filter: const DiveFilterState(favoritesOnly: true),
        saved: [load('Cold water', coldNode)],
      );

      await openMenu(tester);
      await tester.tap(find.text('Cold water'));
      await tester.pumpAndSettle();

      expect(
        container.read(insightsFilterProvider),
        DiveFilterState(query: coldNode),
      );
    });

    testWidgets('picking a group leaves the dive list filter alone', (
      tester,
    ) async {
      final container = await pumpBar(
        tester,
        saved: [load('Cold water', coldNode)],
      );

      await openMenu(tester);
      await tester.tap(find.text('Cold water'));
      await tester.pumpAndSettle();

      expect(container.read(diveFilterProvider), const DiveFilterState());
    });

    testWidgets('picking All dives clears the filter', (tester) async {
      final container = await pumpBar(
        tester,
        filter: DiveFilterState(query: coldNode),
        saved: [load('Cold water', coldNode)],
      );

      await openMenu(tester);
      await tester.tap(find.text('All dives'));
      await tester.pumpAndSettle();

      expect(container.read(insightsFilterProvider), const DiveFilterState());
    });

    testWidgets('a group with a deleted reference still applies, flagged', (
      tester,
    ) async {
      final container = await pumpBar(
        tester,
        saved: [
          load('Old tag', coldNode, problem: SavedQueryProblem.unresolvedRef),
        ],
      );

      await openMenu(tester);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      await tester.tap(find.text('Old tag'));
      await tester.pumpAndSettle();

      expect(
        container.read(insightsFilterProvider),
        DiveFilterState(query: coldNode),
      );
    });

    testWidgets('a selected group with a deleted reference stays flagged', (
      tester,
    ) async {
      await pumpBar(
        tester,
        filter: DiveFilterState(query: coldNode),
        saved: [
          load('Old tag', coldNode, problem: SavedQueryProblem.unresolvedRef),
        ],
      );

      await openMenu(tester);

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(
        find.byTooltip('"Old tag" refers to something that no longer exists'),
        findsOneWidget,
      );
    });

    testWidgets('an unreadable group explains itself and applies nothing', (
      tester,
    ) async {
      final container = await pumpBar(
        tester,
        saved: [
          load(
            'From a newer build',
            null,
            problem: SavedQueryProblem.unreadable,
          ),
        ],
      );

      await openMenu(tester);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await tester.tap(find.text('From a newer build'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(container.read(insightsFilterProvider), const DiveFilterState());
    });
  });

  group('Save current filter', () {
    PopupMenuItem<Object?> saveItem(WidgetTester tester) =>
        tester.widget<PopupMenuItem<Object?>>(
          find.ancestor(
            of: find.text('Save current filter...'),
            matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
          ),
        );

    testWidgets('is offered but disabled with no filter to save', (
      tester,
    ) async {
      await pumpBar(tester);

      await openMenu(tester);

      expect(saveItem(tester).enabled, false);
    });

    testWidgets('is disabled while a group is already selected', (
      tester,
    ) async {
      await pumpBar(
        tester,
        filter: DiveFilterState(query: coldNode),
        saved: [load('Cold water', coldNode)],
      );

      await openMenu(tester);

      expect(saveItem(tester).enabled, false);
    });

    testWidgets('is disabled for a filter that lowers to nothing', (
      tester,
    ) async {
      await pumpBar(tester, filter: DiveFilterState(query: AndNode(const [])));

      await openMenu(tester);

      expect(saveItem(tester).enabled, false);
    });

    testWidgets('saves a custom filter through the shared save flow', (
      tester,
    ) async {
      QueryNode? savedNode;
      await pumpBar(
        tester,
        filter: DiveFilterState(query: warmNode),
        saved: [load('Cold water', coldNode)],
        saver: (context, ref, node) async => savedNode = node,
      );

      await openMenu(tester);
      expect(saveItem(tester).enabled, true);
      await tester.tap(find.text('Save current filter...'));
      await tester.pumpAndSettle();

      expect(savedNode, warmNode);
    });
  });

  group('Manage saved queries', () {
    testWidgets('is hidden with nothing saved to manage', (tester) async {
      await pumpBar(tester);

      await openMenu(tester);

      expect(find.text('Manage saved queries'), findsNothing);
    });

    testWidgets('opens the saved queries page', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: InsightsFilterBar()),
          ),
          GoRoute(
            path: '/saved-queries',
            builder: (_, _) => const Text('saved queries page'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredDiveStatisticsProvider.overrideWith(
              (ref) async => DiveStatistics(
                totalDives: 5,
                totalTimeSeconds: 0,
                maxDepth: 0,
                avgMaxDepth: 0,
                totalSites: 0,
              ),
            ),
            savedQueryLoadsProvider(
              'dives',
            ).overrideWith((ref) async => [load('Cold water', coldNode)]),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.text('Manage saved queries'));
      await tester.pumpAndSettle();

      expect(find.text('saved queries page'), findsOneWidget);
    });
  });
}
