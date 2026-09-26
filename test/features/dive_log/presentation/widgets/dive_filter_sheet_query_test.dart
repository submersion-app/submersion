import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The quick sheet neither shows nor edits the advanced query; applying it
/// must keep the query (and every other axis it does not edit) rather than
/// replace the whole state (#2365).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final query = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30, null),
  );

  Future<
    ({
      ProviderContainer container,
      StateProvider<DiveFilterState> filter,
      List<String> pushed,
    })
  >
  pumpSheet(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
  }) async {
    final filter = StateProvider<DiveFilterState>(
      (ref) => DiveFilterState(
        query: query,
        tripId: 'trip-1',
        decoOnly: true,
        favoritesOnly: true,
      ),
    );
    final overrides = await getBaseOverrides();
    late ProviderContainer container;
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        DiveFilterSheet(ref: ref, filterProvider: filter),
                  ),
                  child: const Text('Open filter'),
                );
              },
            ),
          ),
        ),
        GoRoute(
          path: '/dives/search',
          builder: (context, state) {
            pushed.add(state.uri.toString());
            return const Scaffold(body: Text('search page'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides, ...extraOverrides].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open filter'));
    await tester.pumpAndSettle();
    return (container: container, filter: filter, pushed: pushed);
  }

  testWidgets('Apply keeps an advanced query it does not edit', (tester) async {
    final s = await pumpSheet(tester);
    // Turn favorites off in the sheet, the one axis this test edits. The
    // sheet's list is taller than the modal (see dive_filter_sheet_test).
    final scrollable = find.byType(Scrollable).first;
    final favorites = find.byKey(const Key('filter-favorites-only'));
    await tester.scrollUntilVisible(favorites, 50, scrollable: scrollable);
    await tester.ensureVisible(favorites);
    await tester.pumpAndSettle();
    await tester.tap(favorites);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();

    final applied = s.container.read(s.filter);
    expect(applied.query, query);
    expect(applied.tripId, 'trip-1');
    expect(applied.decoOnly, isTrue);
    expect(applied.favoritesOnly, isNull);
  });

  testWidgets('the Query row opens the search page on its query section', (
    tester,
  ) async {
    final s = await pumpSheet(tester);
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();
    expect(find.text('search page'), findsOneWidget);
    expect(s.pushed, ['/dives/search?section=query']);
  });

  testWidgets('a saved chip applies at once and keeps the sheet axes', (
    tester,
  ) async {
    final shallow = ConditionNode(
      FieldPath(['depth']),
      QueryOp.lt,
      const NumberValue(10, null),
    );
    final s = await pumpSheet(
      tester,
      extraOverrides: [
        savedQueryLoadsProvider('dives').overrideWith(
          (ref) async => [
            SavedQueryLoad(
              SavedQuery(
                id: 'a',
                subject: 'dives',
                name: 'Shallow',
                queryJson: '{}',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
              node: shallow,
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Shallow'));
    await tester.pumpAndSettle();
    final applied = s.container.read(s.filter);
    expect(applied.query, shallow);
    expect(applied.tripId, 'trip-1');
    expect(find.byType(DiveFilterSheet), findsNothing);
  });
}
