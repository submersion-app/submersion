import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/query/data/query_name_index.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The search page hosts the query editor above its sections and applies
/// through copyWith, so axes it does not edit survive (#2365).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<ProviderContainer> pumpPage(
    WidgetTester tester,
    DiveFilterState seed, {
    String? section,
    List<Override> extraOverrides = const [],
  }) async {
    late ProviderContainer container;
    final router = GoRouter(
      initialLocation: section == null
          ? '/dives/search'
          : '/dives/search?section=$section',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, _) {
            container = ProviderScope.containerOf(context);
            return const Scaffold(body: Text('dive list'));
          },
          routes: [
            GoRoute(
              path: 'search',
              builder: (context, state) {
                container = ProviderScope.containerOf(context);
                return DiveSearchPage(
                  initialSection: state.uri.queryParameters['section'],
                );
              },
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          diveFilterProvider.overrideWith((ref) => seed),
          queryNameIndexProvider.overrideWith(
            (ref) async => const QueryNameIndex({
              QuerySubject.sites: [RefValue('s1', 'Salt Pier')],
            }),
          ),
          ...extraOverrides,
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder queryField() => find.byType(TextField).first;
  Finder searchButton() => find.ancestor(
    of: find.text('Search'),
    matching: find.bySubtype<FilledButton>(),
  );

  testWidgets('a typed query is applied and a computer id is kept', (
    tester,
  ) async {
    final container = await pumpPage(
      tester,
      const DiveFilterState(computerId: 'dc-1', excludedFromStatsOnly: true),
      section: 'query',
    );
    await tester.enterText(queryField(), 'depth > 30');
    await tester.pump();
    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    final applied = container.read(diveFilterProvider);
    expect(
      applied.query,
      ConditionNode(
        FieldPath(['depth']),
        QueryOp.gt,
        const NumberValue(30, null),
      ),
    );
    expect(applied.computerId, 'dc-1');
    expect(applied.excludedFromStatsOnly, isTrue);
  });

  testWidgets(
    'an existing query expands the section and prints into the field',
    (tester) async {
      await pumpPage(
        tester,
        DiveFilterState(
          query: ConditionNode(
            FieldPath(['site']),
            QueryOp.eq,
            const RefValue('s1', 'Salt Pier'),
          ),
        ),
      );
      expect(
        tester.widget<TextField>(queryField()).controller!.text,
        'site = "Salt Pier"',
      );
    },
  );

  testWidgets('Clear All clears the query too', (tester) async {
    final container = await pumpPage(
      tester,
      DiveFilterState(
        query: ConditionNode(
          FieldPath(['depth']),
          QueryOp.gt,
          const NumberValue(30, null),
        ),
      ),
    );
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await tester.tap(searchButton());
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider).query, isNull);
  });

  testWidgets('a saved chip applies its tree into the editor', (tester) async {
    final depth = ConditionNode(
      FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(30, null),
    );
    final container = await pumpPage(
      tester,
      const DiveFilterState(),
      section: 'query',
      extraOverrides: [
        savedQueryLoadsProvider('dives').overrideWith(
          (ref) async => [
            SavedQueryLoad(
              SavedQuery(
                id: 'a',
                subject: 'dives',
                name: 'Deep',
                queryJson: '{}',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
              node: depth,
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Deep'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(queryField()).controller!.text,
      'depth > 30',
    );
    await tester.tap(searchButton());
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider).query, depth);
  });
}
