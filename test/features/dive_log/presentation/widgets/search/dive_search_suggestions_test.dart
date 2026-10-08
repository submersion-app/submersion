import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_suggestions.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';

import '../../../../../helpers/test_app.dart';

/// What the empty dive search field offers (#2773, spec 4.1 state 2).
void main() {
  late List<String> hints;
  late List<RecentQuery> recentsTapped;

  List<dynamic> overridesFor({
    List<RecentQuery> recents = const [],
    bool askEnabled = true,
    bool imperial = false,
    List<String> buddyNames = const [],
  }) => [
    savedQueryLoadsProvider(
      'dives',
    ).overrideWith((ref) async => const <SavedQueryLoad>[]),
    recentQueriesProvider.overrideWith((ref) async => recents),
    exploreEnabledProvider.overrideWithValue(askEnabled),
    allBuddiesProvider.overrideWith(
      (ref) async => [
        for (final (i, n) in buddyNames.indexed)
          Buddy(
            id: 'b$i',
            name: n,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
      ],
    ),
    queryUnitPrefsProvider.overrideWithValue(
      imperial
          ? const UnitPrefs(
              depth: DepthUnit.feet,
              temperature: TemperatureUnit.fahrenheit,
              pressure: PressureUnit.psi,
              weight: WeightUnit.pounds,
              volume: VolumeUnit.cubicFeet,
            )
          : kMetricPrefs,
    ),
  ];

  Widget suggestions() => DiveSearchSuggestions(
    onSaved: (_) {},
    onRecent: recentsTapped.add,
    onHint: hints.add,
    printQuery: (node) => switch (node) {
      TextNode(:final words) => words.join(' '),
      _ => '$node',
    },
  );

  Future<void> pumpSuggestions(
    WidgetTester tester, {
    List<RecentQuery> recents = const [],
    bool askEnabled = true,
    bool imperial = false,
    List<String> buddyNames = const [],
  }) async {
    hints = [];
    recentsTapped = [];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overridesFor(
          recents: recents,
          askEnabled: askEnabled,
          imperial: imperial,
          buddyNames: buddyNames,
        ),
        child: SingleChildScrollView(child: suggestions()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists saved searches, recents with their kind, and hints', (
    tester,
  ) async {
    await pumpSuggestions(
      tester,
      recents: [
        RecentQuery(
          sentence: 'manta',
          locale: 'en',
          parsed: null,
          kind: RecentQueryKind.typed,
          node: TextNode(['manta']),
          lastUsedAt: DateTime(2026, 10, 2),
        ),
        RecentQuery(
          sentence: 'turtles in Bonaire',
          locale: 'en',
          parsed: const ParsedQuery(subject: ParsedSubject.dives),
          lastUsedAt: DateTime(2026, 10, 1),
        ),
      ],
      askEnabled: true,
    );
    expect(find.text('Recent'), findsOneWidget);
    expect(find.byTooltip('Typed search'), findsOneWidget);
    expect(find.byTooltip('Asked question'), findsOneWidget);
    expect(find.text('depth > 30m'), findsOneWidget);
    expect(find.text('or ask a question'), findsOneWidget);
    await tester.tap(find.text('depth > 30m'));
    expect(hints, ['depth > 30m']);
    // "manta" is also a hint chip: tap the recent row.
    await tester.tap(find.widgetWithText(ListTile, 'manta'));
    expect(recentsTapped.single.sentence, 'manta');
  });

  // Review Focus 2.
  testWidgets('hints follow the diver units', (tester) async {
    await pumpSuggestions(tester, imperial: true);
    expect(find.text('depth > 100ft'), findsOneWidget);
  });

  testWidgets('asked recents hide where Ask cannot answer', (tester) async {
    await pumpSuggestions(
      tester,
      recents: [
        RecentQuery(
          sentence: 'turtles in Bonaire',
          locale: 'en',
          parsed: const ParsedQuery(subject: ParsedSubject.dives),
          lastUsedAt: DateTime(2026, 10, 1),
        ),
      ],
      askEnabled: false,
    );
    expect(find.text('turtles in Bonaire'), findsNothing);
    expect(find.text('or ask a question'), findsNothing);
  });

  testWidgets('the buddy hint uses a real buddy, or is left out', (
    tester,
  ) async {
    await pumpSuggestions(tester, buddyNames: ['Ana Lee']);
    expect(find.text('buddy = "Ana Lee"'), findsOneWidget);
  });

  testWidgets('Manage opens the saved queries page', (tester) async {
    hints = [];
    recentsTapped = [];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              Scaffold(body: SingleChildScrollView(child: suggestions())),
        ),
        GoRoute(
          path: '/saved-queries',
          builder: (context, state) => const Text('saved queries page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: overridesFor(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kDiveSearchManageSavedKey));
    await tester.pumpAndSettle();
    expect(find.text('saved queries page'), findsOneWidget);
  });
}
