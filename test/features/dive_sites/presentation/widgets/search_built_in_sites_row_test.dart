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
Widget _app({bool demoMode = false, bool withRows = true}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Column(
              children: [
                EntitySearchHeader(
                  subject: withRows ? _subject : QuerySubject.buddies,
                  root: withRows ? siteQueryEntity : buddyQueryEntity,
                  query: ref.watch(_query),
                  onChanged: (q) => ref.read(_query.notifier).state = q,
                  alwaysShown: true,
                  extraRows: withRows ? sitesSearchExtraRows : null,
                ),
                const Expanded(child: Text('the list')),
              ],
            ),
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
  group('isPlainWordsQuery', () {
    test('words alone', () {
      expect(isPlainWordsQuery(TextNode(['thistlegorm'])), isTrue);
      expect(isPlainWordsQuery(TextNode(['blue', 'hole'])), isTrue);
      expect(
        isPlainWordsQuery(
          AndNode([
            TextNode(['blue']),
            TextNode(['hole']),
          ]),
        ),
        isTrue,
      );
    });

    test('not a condition, a choice, a negation or nothing', () {
      expect(isPlainWordsQuery(null), isFalse);
      expect(
        isPlainWordsQuery(
          OrNode([
            TextNode(['blue']),
            TextNode(['hole']),
          ]),
        ),
        isFalse,
      );
      expect(isPlainWordsQuery(NotNode(TextNode(['blue']))), isFalse);
      expect(isPlainWordsQuery(AndNode(const [])), isFalse);
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
