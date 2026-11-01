import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/query/presentation/providers/entity_search_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/widgets/entity_search_action.dart';
import 'package:submersion/features/query/presentation/widgets/entity_search_header.dart';
import 'package:submersion/features/query/presentation/widgets/search_everywhere_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _query = StateProvider<QueryNode?>((ref) => null);
const _subject = QuerySubject.buddies;
final _field = entitySearchFieldKey(_subject);

/// The list's search icon by key: once the row is open, the field wears a
/// search icon of its own.
final _action = ValueKey('entity-search-action-${_subject.name}');

/// A list whose whole filter is [_query], with its search icon in the app
/// bar and the header over its body, which reads [marker].
Widget _listPage(String marker, {bool alwaysShown = false}) => Consumer(
  builder: (context, ref, _) => Scaffold(
    appBar: AppBar(
      actions: [
        EntitySearchAction(
          subject: _subject,
          active: ref.watch(_query) != null,
        ),
      ],
    ),
    body: Column(
      children: [
        EntitySearchHeader(
          subject: _subject,
          root: buddyQueryEntity,
          query: ref.watch(_query),
          onChanged: (q) => ref.read(_query.notifier).state = q,
          alwaysShown: alwaysShown,
        ),
        Expanded(child: Text(marker)),
      ],
    ),
  ),
);

/// The header over a list whose whole filter is [_query], with the list's
/// search icon above it, a `/search` page to land on, and a second list of
/// the same subject at `/second` to push over it.
Widget _app({bool alwaysShown = false}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            _listPage('the list', alwaysShown: alwaysShown),
      ),
      GoRoute(
        path: '/second',
        builder: (context, state) => _listPage('the second list'),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const Scaffold(body: Text('page /search')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
      queryUnitPrefsProvider.overrideWithValue(kMetricPrefs),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.text('the list')));

void main() {
  testWidgets('hidden until the search icon opens it, with the caret in it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(_field), findsNothing);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(_field));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('a list pushed over another of the same subject gets the caret', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // See all pushes a second Trips list over the Trips nav page: both
    // headers hear the focus request, and the covered one must leave it.
    GoRouter.of(tester.element(find.text('the list'))).push('/second');
    await tester.pumpAndSettle();
    expect(find.text('the second list'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(_field));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('the icon hiding an idle row drops its text', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    // Nothing a buddy reads, so the list has no query and the row is idle.
    await tester.enterText(find.byKey(_field), 'depth >');
    await tester.pump();
    expect(find.byKey(kSearchEverywhereRowKey), findsOneWidget);

    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(find.byKey(_field), findsNothing);
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(find.byKey(_field), findsOneWidget);
    expect(find.byKey(kSearchEverywhereRowKey), findsNothing);
  });

  testWidgets('the icon hiding a row cancels the write it was waiting on', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_field), 'robin');
    await tester.pump();

    // Hidden inside the debounce: the row must not come back filtered. The
    // frame that hides it comes first, as it does in the app; pump(duration)
    // would fire the timer before building it.
    await tester.tap(find.byKey(_action));
    await tester.pump();
    await tester.pump(kEntitySearchDebounce);
    await tester.pumpAndSettle();
    expect(_container(tester).read(_query), isNull);
    expect(find.byKey(_field), findsNothing);
  });

  testWidgets('writes the list\'s query once typing rests', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_field), 'robin');
    await tester.pump();
    expect(_container(tester).read(_query), isNull);
    await tester.pump(kEntitySearchDebounce);
    expect(_container(tester).read(_query), TextNode(['robin']));
  });

  testWidgets('reads the list\'s own query language', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(_field), 'favorite = true');
    await tester.pump(kEntitySearchDebounce);
    expect(_container(tester).read(_query), isA<ConditionNode>());
  });

  testWidgets('stays up while the list has a query, and closes clear it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_field), 'robin');
    await tester.pump(kEntitySearchDebounce);
    // Focus elsewhere: the row stays, since the list is filtered.
    await tester.tap(find.text('the list'));
    await tester.pumpAndSettle();
    expect(find.byKey(_field), findsOneWidget);

    await tester.tap(find.byKey(entitySearchCloseKey(_subject)));
    await tester.pumpAndSettle();
    expect(_container(tester).read(_query), isNull);
    expect(find.byKey(_field), findsNothing);
  });

  testWidgets('Esc closes and clears', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_field), 'robin');
    await tester.pump(kEntitySearchDebounce);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_container(tester).read(_query), isNull);
    expect(find.byKey(_field), findsNothing);
  });

  testWidgets('a query set from outside reprints the field', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    _container(tester).read(_query.notifier).state = TextNode(['ann']);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(_field));
    expect(field.controller!.text, 'ann');
  });

  testWidgets('a query set from outside after Close shows in the field', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_field), 'robin');
    await tester.pump(kEntitySearchDebounce);
    await tester.tap(find.byKey(entitySearchCloseKey(_subject)));
    await tester.pumpAndSettle();
    expect(find.byKey(_field), findsNothing);

    // The filter sheet, or global search's See all, sets the list's query:
    // the row comes back with that query in it, not Close's empty text.
    _container(tester).read(_query.notifier).state = TextNode(['ann']);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(_field)).controller!.text,
      'ann',
    );
  });

  testWidgets('always shown where the page asks, Close then clears only', (
    tester,
  ) async {
    await tester.pumpWidget(_app(alwaysShown: true));
    await tester.pumpAndSettle();
    expect(find.byKey(_field), findsOneWidget);

    await tester.enterText(find.byKey(_field), 'robin');
    await tester.pump(kEntitySearchDebounce);
    await tester.tap(find.byKey(entitySearchCloseKey(_subject)));
    await tester.pumpAndSettle();
    expect(_container(tester).read(_query), isNull);
    expect(find.byKey(_field), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(_field)).controller!.text, '');
  });

  group('Search everything', () {
    testWidgets('offers the typed text while the field is focused', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.byKey(kSearchEverywhereRowKey), findsNothing);

      await tester.enterText(find.byKey(_field), 'wreck');
      await tester.pump();
      expect(find.text('Search everything for "wreck"'), findsOneWidget);
    });

    testWidgets('offers text this list cannot read', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(_field), 'expires < 2027');
      await tester.pump();
      expect(
        find.text('Search everything for "expires < 2027"'),
        findsOneWidget,
      );
    });

    testWidgets('opens global search with the text', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_field), 'wreck');
      await tester.pump();
      final container = _container(tester);

      await tester.tap(find.byKey(kSearchEverywhereRowKey));
      await tester.pumpAndSettle();
      expect(find.text('page /search'), findsOneWidget);
      expect(container.read(globalSearchRequestProvider)?.text, 'wreck');
    });
  });
}
