import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_search_delegate.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

final _center = DiveCenter(
  id: 'dc1',
  name: 'Blue Hole Divers',
  city: 'Dahab',
  country: 'Egypt',
  rating: 4.5,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _bare = DiveCenter(
  id: 'dc2',
  name: 'Harbour Shop',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Opens the dive center list's search page the way its app bar does,
/// inside a router so a tapped result can navigate.
Future<void> _openSearch(
  WidgetTester tester,
  Future<List<DiveCenter>> Function(String query) search,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => ElevatedButton(
              onPressed: () => showSearch(
                context: context,
                delegate: DiveCenterSearchDelegate(ref),
              ),
              child: const Text('open search'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dive-centers/:id',
        builder: (context, state) =>
            Text('detail ${state.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    testAppRouter(
      router: router,
      locale: const Locale('en'),
      overrides: [
        ...await getBaseOverrides(),
        diveCenterSearchProvider.overrideWith((ref, q) => search(q)),
      ],
    ),
  );
  await tester.tap(find.text('open search'));
  await tester.pumpAndSettle();
}

/// The frame that sees the new query starts the DebouncedSearchResults
/// timer, so build it first and only then run the clock past the debounce.
Future<void> _pastDebounce(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await _pastDebounce(tester);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty query shows the search prompt', (tester) async {
    await _openSearch(tester, (_) async => [_center]);

    expect(find.text('Search dive centers'), findsOneWidget);
    expect(find.text('Blue Hole Divers'), findsNothing);
  });

  testWidgets('a query lists the matches, and a tap opens the detail', (
    tester,
  ) async {
    final queries = <String>[];
    await _openSearch(tester, (q) async {
      queries.add(q);
      return [_center, _bare];
    });
    await _type(tester, 'div');

    expect(queries, contains('div'));
    expect(find.text('Blue Hole Divers'), findsOneWidget);
    expect(find.text('Dahab, Egypt'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    // No location and no rating: no subtitle and no star.
    expect(find.text('Harbour Shop'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.tap(find.text('Blue Hole Divers'));
    await tester.pumpAndSettle();

    expect(find.text('detail dc1'), findsOneWidget);
  });

  testWidgets('a query with no matches says so', (tester) async {
    await _openSearch(tester, (_) async => []);
    await _type(tester, 'zzz');

    expect(find.text('No results for "zzz"'), findsOneWidget);
  });

  testWidgets('a failed search shows the error', (tester) async {
    await _openSearch(tester, (_) async => throw StateError('boom'));
    await _type(tester, 'div');

    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('submitting shows the same results', (tester) async {
    await _openSearch(tester, (_) async => [_center]);
    await tester.enterText(find.byType(TextField), 'div');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pastDebounce(tester);
    await tester.pumpAndSettle();

    expect(find.text('Blue Hole Divers'), findsOneWidget);
  });

  testWidgets('clear empties the query, and back closes the search', (
    tester,
  ) async {
    await _openSearch(tester, (_) async => [_center]);
    await _type(tester, 'div');

    await tester.tap(find.byTooltip('Clear search'));
    await _pastDebounce(tester);
    await tester.pumpAndSettle();
    expect(find.text('Search dive centers'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('open search'), findsOneWidget);
  });
}
