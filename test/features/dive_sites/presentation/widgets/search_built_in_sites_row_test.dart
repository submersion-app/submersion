import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/search_built_in_sites_row.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/entity_search_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/widgets/entity_search_header.dart';
import 'package:submersion/features/query/presentation/widgets/search_everywhere_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _subject = QuerySubject.sites;
final _field = entitySearchFieldKey(_subject);
final _query = StateProvider<QueryNode?>((ref) => null);

/// The Sites search header as the Sites list builds it, over a router that
/// can land on the Import page's location. [withRows] false is a list that
/// passes no rows of its own.
Widget _app({
  bool demoMode = false,
  bool withRows = true,
  bool alwaysShown = true,
  void Function(WidgetRef ref)? onRef,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              onRef?.call(ref);
              return Column(
                children: [
                  EntitySearchHeader(
                    subject: withRows ? _subject : QuerySubject.buddies,
                    root: withRows ? siteQueryEntity : buddyQueryEntity,
                    query: ref.watch(_query),
                    onChanged: (q) => ref.read(_query.notifier).state = q,
                    alwaysShown: alwaysShown,
                    extraRows: withRows ? sitesSearchExtraRows : null,
                  ),
                  const Expanded(child: Text('the list')),
                ],
              );
            },
          ),
        ),
      ),
      GoRoute(
        path: '/sites/import',
        builder: (context, state) => Scaffold(
          body: Text('import page q=${state.uri.queryParameters['q']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
      queryUnitPrefsProvider.overrideWithValue(kMetricPrefs),
      demoModeActiveProvider.overrideWithValue(demoMode),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _type(WidgetTester tester, String text, {Key? field}) async {
  final target = find.byKey(field ?? _field);
  await tester.tap(target);
  await tester.pump();
  await tester.enterText(target, text);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('plainSearchWords', () {
    test('words alone, as one search', () {
      expect(plainSearchWords(TextNode(['thistlegorm'])), 'thistlegorm');
      expect(plainSearchWords(TextNode(['blue', 'hole'])), 'blue hole');
      expect(
        plainSearchWords(
          AndNode([
            TextNode(['blue']),
            TextNode(['hole']),
          ]),
        ),
        'blue hole',
      );
    });

    test('a quoted phrase is its words, without the quotes', () {
      // The parser hands a phrase over as one word with a space in it.
      expect(plainSearchWords(TextNode(['blue hole'])), 'blue hole');
    });

    test('not a condition, a choice, a negation or nothing', () {
      expect(plainSearchWords(null), isNull);
      expect(
        plainSearchWords(
          OrNode([
            TextNode(['blue']),
            TextNode(['hole']),
          ]),
        ),
        isNull,
      );
      expect(plainSearchWords(NotNode(TextNode(['blue']))), isNull);
      expect(plainSearchWords(AndNode(const [])), isNull);
      expect(plainSearchWords(TextNode(const [' '])), isNull);
    });
  });

  testWidgets('typing plain words offers to search built-in sites for '
      'them, beneath Search everything', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(kSearchBuiltInSitesRowKey), findsNothing);

    await _type(tester, 'thistlegorm');

    expect(
      find.text('Search built-in sites for "thistlegorm"'),
      findsOneWidget,
    );
    final everything = tester.getTopLeft(find.byKey(kSearchEverywhereRowKey));
    final builtIn = tester.getTopLeft(find.byKey(kSearchBuiltInSitesRowKey));
    expect(builtIn.dy, greaterThan(everything.dy));
  });

  testWidgets('several words are offered as typed', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _type(tester, 'blue hole');

    expect(find.text('Search built-in sites for "blue hole"'), findsOneWidget);
  });

  testWidgets('tapping it opens the Import page with the search', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _type(tester, ' thistlegorm ');

    await tester.tap(find.byKey(kSearchBuiltInSitesRowKey));
    await tester.pumpAndSettle();

    expect(find.text('import page q=thistlegorm'), findsOneWidget);
  });

  testWidgets('a field condition is not offered: the catalogue search '
      'would not understand it', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _type(tester, 'maxDepth > 20');

    expect(find.byKey(kSearchBuiltInSitesRowKey), findsNothing);
    // Search everything still takes it.
    expect(find.byKey(kSearchEverywhereRowKey), findsOneWidget);
  });

  testWidgets('text that does not parse yet is not offered, though the '
      'words before it were', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _type(tester, 'wreck');
    expect(find.byKey(kSearchBuiltInSitesRowKey), findsOneWidget);

    // Half typed: the last clean tree is still the plain word.
    await _type(tester, 'wreck maxDepth >');

    expect(find.byKey(kSearchBuiltInSitesRowKey), findsNothing);
  });

  testWidgets('not offered in demo mode, where the Import page is sealed', (
    tester,
  ) async {
    await tester.pumpWidget(_app(demoMode: true));
    await tester.pumpAndSettle();

    await _type(tester, 'thistlegorm');

    expect(find.byKey(kSearchBuiltInSitesRowKey), findsNothing);
    expect(find.byKey(kSearchEverywhereRowKey), findsOneWidget);
  });

  testWidgets('a quoted phrase is searched for without its quotes, which '
      'the catalogue search would take for part of a word', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _type(tester, '"blue hole"');

    expect(find.text('Search built-in sites for "blue hole"'), findsOneWidget);

    await tester.tap(find.byKey(kSearchBuiltInSitesRowKey));
    await tester.pumpAndSettle();

    expect(find.text('import page q=blue hole'), findsOneWidget);
  });

  testWidgets('text that did not parse when the row was hidden does not '
      'keep the offer away afterwards', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(_app(alwaysShown: false, onRef: (r) => ref = r));
    await tester.pumpAndSettle();
    final open = entitySearchOpenProvider(_subject);
    ref.read(open.notifier).state = true;
    await tester.pumpAndSettle();
    await _type(tester, 'wreck maxDepth >');
    expect(find.byKey(kSearchBuiltInSitesRowKey), findsNothing);

    // Hidden by the list's search icon, text and all, and opened again:
    // a new field, which parses from the start and never says so.
    ref.read(open.notifier).state = false;
    await tester.pumpAndSettle();
    ref.read(open.notifier).state = true;
    await tester.pumpAndSettle();
    await _type(tester, 'wreck');

    expect(find.byKey(kSearchBuiltInSitesRowKey), findsOneWidget);
  });

  testWidgets('text that does not parse is not offered after a query was '
      'set from outside, whatever the field last said', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(_app(onRef: (r) => ref = r));
    await tester.pumpAndSettle();
    await _type(tester, 'maxDepth >');
    expect(find.byKey(kSearchBuiltInSitesRowKey), findsNothing);

    // A saved search applied, or a filter chip removed: the field is
    // rewritten in place and tells the header nothing.
    ref.read(_query.notifier).state = TextNode(['wreck']);
    await tester.pumpAndSettle();

    await _type(tester, 'wreck maxDepth >');

    expect(find.byKey(kSearchBuiltInSitesRowKey), findsNothing);
    expect(find.byKey(kSearchEverywhereRowKey), findsOneWidget);
  });

  testWidgets('a list that passes no rows of its own shows only Search '
      'everything', (tester) async {
    await tester.pumpWidget(_app(withRows: false));
    await tester.pumpAndSettle();

    await _type(
      tester,
      'thistlegorm',
      field: entitySearchFieldKey(QuerySubject.buddies),
    );

    expect(find.byKey(kSearchEverywhereRowKey), findsOneWidget);
    expect(find.byKey(kSearchBuiltInSitesRowKey), findsNothing);
  });
}
