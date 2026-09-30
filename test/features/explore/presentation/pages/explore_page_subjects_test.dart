import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/pages/explore_page.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_subject_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Explore phase 3 on the page: a sentence about buddies shows the subject
/// chip, the buddies' own tiles, a result count and a handoff to their list.
class _Engine implements NlEngine {
  _Engine(this.json);
  final String json;
  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;
  @override
  Future<void> prepare() async {}
  @override
  Stream<double> download() => const Stream.empty();
  @override
  Future<String> compile(String sentence, {required String localeTag}) async =>
      json;
}

void main() {
  final t = DateTime(2026, 1, 1);
  final ana = ExploreSubjectRow(
    id: 'b1',
    name: 'Ana',
    dives: 3,
    item: BuddyWithDiveCount(
      buddy: Buddy(id: 'b1', name: 'Ana', createdAt: t, updatedAt: t),
      diveCount: 3,
    ),
  );

  String parse(String body) =>
      '{"schemaVersion":$kQuerySchemaVersion,"subject":"buddies",$body,'
      '"mentions":[],"unplaced":[]}';

  Future<ProviderContainer> pump(WidgetTester tester, String json) async {
    final router = GoRouter(
      initialLocation: '/dives/explore',
      routes: [
        GoRoute(path: '/dives/explore', builder: (_, _) => const ExplorePage()),
        GoRoute(path: '/buddies', builder: (_, _) => const Text('buddy list')),
        GoRoute(
          path: '/buddies/:id',
          builder: (_, s) => Text('buddy ${s.pathParameters['id']}'),
        ),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...base,
          nlEngineProvider.overrideWithValue(_Engine(json)),
          explorePlatformSupportedProvider.overrideWithValue(true),
          localeProvider.overrideWithValue('en'),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          recentQueryRecorderProvider.overrideWithValue((s, l, p) async {}),
          recentQueriesProvider.overrideWith((ref) async => const []),
          exploreSubjectCountsProvider.overrideWith((ref) async => const {}),
          exploreSubjectRowsProvider.overrideWithValue(AsyncValue.data([ana])),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ExplorePage)));
  }

  Future<void> ask(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('explore-sentence')),
      'my favourite buddies',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('a buddies answer: subject chip, rows, count and handoff', (
    tester,
  ) async {
    final c = await pump(
      tester,
      parse(
        '"clauses":[{"field":"favorite","op":"eq","value":true,'
        '"text":"favourite"}],"time":null',
      ),
    );
    await ask(tester);

    expect(find.byKey(const ValueKey('explore-subject-chip')), findsOneWidget);
    expect(find.text('Buddies'), findsWidgets);
    expect(find.text('1 result'), findsOneWidget);
    // A buddies answer is not headed as dives.
    expect(find.text('Matching dives'), findsNothing);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.byKey(const ValueKey('explore-row-b1')), findsOneWidget);
    expect(find.text('Open in dive list'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('explore-handoff-list')));
    await tester.pumpAndSettle();
    expect(c.read(buddyQueryProvider), isNotNull);
    expect(find.text('buddy list'), findsOneWidget);
  });

  testWidgets('a period under buddies is a chip about the dives', (
    tester,
  ) async {
    await pump(tester, parse('"clauses":[],"time":{"text":"this year"}'));
    await ask(tester);
    expect(find.textContaining('Dives: '), findsOneWidget);
    expect(find.text('Dives per buddy'), findsOneWidget);
  });

  testWidgets('a subject alone offers no handoff', (tester) async {
    await pump(tester, parse('"clauses":[],"time":null'));
    await ask(tester);
    expect(find.byKey(const ValueKey('explore-handoff-list')), findsNothing);
    expect(find.byKey(const ValueKey('explore-row-b1')), findsOneWidget);
  });

  testWidgets('a row opens its detail page', (tester) async {
    await pump(tester, parse('"clauses":[],"time":null'));
    await ask(tester);
    await tester.tap(find.byKey(const ValueKey('explore-row-b1')));
    await tester.pumpAndSettle();
    expect(find.text('buddy b1'), findsOneWidget);
  });
}
