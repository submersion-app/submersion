import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_suggestions.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpHeader(
    WidgetTester tester, {
    DiveFilterState filter = const DiveFilterState(),
    bool open = true,
    List<DiveSummary> jump = const [],
    ValueChanged<DiveSummary>? onOpenDive,
    double? width,
    Future<List<DiveSummary>> Function(QueryNode query)? jumpFor,
    void Function(QueryNode node)? saveOverride,
    List<SavedQueryLoad> savedLoads = const [],
    RecentTypedRecorder? typedRecorder,
    List<RecentQuery> recents = const [],
    NameIndex? names,
    UnitPrefs? prefs,
    bool? askEnabled,
    DiveAskNotifier Function(Ref ref)? ask,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveFilterProvider.overrideWith((ref) => filter),
          diveSearchBarOpenProvider.overrideWith((ref) => open),
          queryNameIndexProvider.overrideWith(
            (ref) async => names ?? NameIndex.empty,
          ),
          diveJumpResultsProvider.overrideWith(
            (ref, q) => jumpFor != null ? jumpFor(q) : Future.value(jump),
          ),
          savedQueryLoadsProvider(
            'dives',
          ).overrideWith((ref) async => savedLoads),
          recentQueriesProvider.overrideWith((ref) async => recents),
          if (prefs != null) queryUnitPrefsProvider.overrideWithValue(prefs),
          if (askEnabled != null) ...[
            exploreEnabledProvider.overrideWithValue(askEnabled),
            exploreNameIndexProvider.overrideWith(
              (ref) async => names ?? NameIndex.empty,
            ),
          ],
          if (ask != null) diveAskProvider.overrideWith(ask),
          allBuddiesProvider.overrideWith((ref) async => const <Buddy>[]),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'ana'),
          recentTypedRecorderProvider.overrideWithValue(
            typedRecorder ?? (text, node, locale, diverId) async {},
          ),
          if (saveOverride != null)
            diveSearchSaverProvider.overrideWithValue(
              (context, ref, node) async => saveOverride(node),
            ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            final header = DiveSearchHeader(onOpenDive: onOpenDive ?? (_) {});
            if (width == null) return header;
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(width: width, child: header),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  DiveFilterState filterOf() => container.read(diveFilterProvider);

  TextField fieldOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(kDiveSearchFieldKey));

  testWidgets('hidden while closed and nothing is filtered', (tester) async {
    await pumpHeader(tester, open: false);
    expect(find.byKey(kDiveSearchFieldKey), findsNothing);
  });

  testWidgets('typing filters the list after the debounce', (tester) async {
    await pumpHeader(tester);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(const Duration(milliseconds: 100));
    expect(filterOf().query, isNull, reason: 'still inside the debounce');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
  });

  testWidgets('invalid text shows an error and keeps the last query', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(query: TextNode(['manta'])),
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'depth >');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
    expect(fieldOf(tester).decoration?.errorText, isNotNull);
  });

  testWidgets('an outside query change re-prints the field', (tester) async {
    await pumpHeader(tester);
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: TextNode(['wreck']),
    );
    await tester.pumpAndSettle();
    expect(fieldOf(tester).controller!.text, 'wreck');
  });

  // Review Focus 1.
  testWidgets('another write inside the debounce keeps both changes', (
    tester,
  ) async {
    await pumpHeader(tester, filter: const DiveFilterState(minDepth: 30));
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(const Duration(milliseconds: 100));
    container.read(diveFilterProvider.notifier).state = filterOf().copyWith(
      axesSuspended: true,
    );
    await tester.pump();
    expect(fieldOf(tester).controller!.text, 'manta', reason: 'not reverted');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
    expect(filterOf().axesSuspended, isTrue);
  });

  testWidgets('a focus request puts the caret in the field', (tester) async {
    await pumpHeader(tester);
    container.read(diveSearchFocusPendingProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(fieldOf(tester).focusNode!.hasFocus, isTrue);
    expect(container.read(diveSearchFocusPendingProvider), isFalse);
  });

  testWidgets('focusing the field opens the row', (tester) async {
    await pumpHeader(
      tester,
      open: false,
      filter: DiveFilterState(query: TextNode(['manta'])),
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    expect(container.read(diveSearchBarOpenProvider), isTrue);
  });

  testWidgets('the refine button badges the panel axis count', (tester) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(minDepth: 30, query: TextNode(['manta'])),
    );
    final badge = find.descendant(
      of: find.byKey(kDiveSearchRefineKey),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );
  });

  final jumpRows = <DiveSummary>[
    DiveSummary(
      id: 'd1',
      dateTime: DateTime(2026, 3, 1),
      sortTimestamp: 0,
      siteName: 'Manta Point',
    ),
  ];

  testWidgets('the jump list shows only while focused with a query', (
    tester,
  ) async {
    await pumpHeader(tester, jump: jumpRows);
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsNothing);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    // The jump list searches once typing rests, and its provider
    // resolves on the next frame.
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsOneWidget);
    expect(find.text('Jump to dive'), findsOneWidget);
  });

  // Copilot review: rows for the last valid query stayed under text that
  // no longer parses.
  testWidgets('the jump rows hide while the text does not parse', (
    tester,
  ) async {
    await pumpHeader(tester, jump: jumpRows);
    final jumpRow = find.byKey(const ValueKey('dive-jump-d1'));
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(jumpRow, findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta depth >');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(jumpRow, findsNothing);
    // Back to the same valid text: nothing new is committed, the rows
    // still return.
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(jumpRow, findsOneWidget);
  });

  // Copilot review: a failed jump query kept the previous query's rows.
  testWidgets('a failed jump query clears the earlier rows', (tester) async {
    await pumpHeader(
      tester,
      jumpFor: (q) async =>
          q == TextNode(['manta']) ? jumpRows : throw StateError('jump failed'),
    );
    final jumpRow = find.byKey(const ValueKey('dive-jump-d1'));
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(jumpRow, findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'ray');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(jumpRow, findsNothing);
  });

  testWidgets('tapping a jump row opens that dive', (tester) async {
    DiveSummary? opened;
    await pumpHeader(tester, jump: jumpRows, onOpenDive: (d) => opened = d);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    // The jump list searches once typing rests, and its provider
    // resolves on the next frame.
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dive-jump-d1')));
    await tester.pump();
    expect(opened?.id, 'd1');
  });

  // Review Focus 2: a mouse press outside a desktop field unfocuses it.
  testWidgets('a desktop mouse click on a jump row still opens it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    DiveSummary? opened;
    await pumpHeader(tester, jump: jumpRows, onOpenDive: (d) => opened = d);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    // The jump list searches once typing rests, and its provider
    // resolves on the next frame.
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    // A real click spans frames: the press could unfocus the field and
    // rebuild without the rows before the release lands.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('dive-jump-d1'))),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(opened?.id, 'd1');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the scope toggle shows only with panel axes', (tester) async {
    await pumpHeader(tester, filter: DiveFilterState(query: TextNode(['a'])));
    expect(find.byKey(const ValueKey('dive-search-scope')), findsNothing);
  });

  testWidgets('All dives suspends the axes; Within filters restores them', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(minDepth: 30, query: TextNode(['manta'])),
    );
    await tester.tap(find.text('All dives'));
    await tester.pumpAndSettle();
    expect(filterOf().axesSuspended, isTrue);
    expect(filterOf().minDepth, 30);
    await tester.tap(find.text('Within filters'));
    await tester.pumpAndSettle();
    expect(filterOf().axesSuspended, isFalse);
  });

  testWidgets('Open in Insights hands over the effective search', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/dives',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return DiveSearchHeader(onOpenDive: (_) {});
              },
            ),
          ),
        ),
        GoRoute(
          path: '/insights',
          builder: (_, _) => const Text('Insights page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    final q = TextNode(['manta']);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveFilterProvider.overrideWith(
            (ref) =>
                DiveFilterState(minDepth: 30, query: q, axesSuspended: true),
          ),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith((ref, _) async => const []),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kDiveSearchInsightsKey));
    await tester.pumpAndSettle();
    expect(find.text('Insights page'), findsOneWidget);
    expect(container.read(insightsFilterProvider), DiveFilterState(query: q));
  });

  testWidgets('Clear all empties the search', (tester) async {
    await pumpHeader(tester, filter: const DiveFilterState(minDepth: 30));
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(filterOf(), const DiveFilterState());
  });

  // Code review: with no query committed yet, an outside reset left the
  // typed text in the field and its pending write landed after the clear.
  testWidgets('Clear all drops a first query still waiting to apply', (
    tester,
  ) async {
    await pumpHeader(tester, filter: const DiveFilterState(minDepth: 30));
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Clear all'));
    await tester.pump();
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf(), const DiveFilterState());
    expect(fieldOf(tester).controller!.text, isEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('Save stores the whole search as one query', (tester) async {
    QueryNode? saved;
    await pumpHeader(
      tester,
      filter: DiveFilterState(minDepth: 30, query: TextNode(['manta'])),
      saveOverride: (node) => saved = node,
    );
    await tester.tap(find.byKey(kDiveSearchSaveKey));
    await tester.pumpAndSettle();
    expect(
      saved,
      normalizeQuery(
        DiveFilterState(minDepth: 30, query: TextNode(['manta'])).toQuery(),
      ),
    );
  });

  testWidgets('Save asks for a name, as every saved query does', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(query: TextNode(['manta'])),
    );
    await tester.tap(find.byKey(kDiveSearchSaveKey));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
  });

  // Review Focus 5.
  testWidgets('no Save under All dives with nothing typed', (tester) async {
    await pumpHeader(
      tester,
      filter: const DiveFilterState(minDepth: 30, axesSuspended: true),
    );
    expect(find.byKey(kDiveSearchSaveKey), findsNothing);
  });

  testWidgets('an empty focused field shows suggestions; typing hides them', (
    tester,
  ) async {
    await pumpHeader(tester);
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    expect(find.byKey(kDiveSearchSuggestionsKey), findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    expect(find.byKey(kDiveSearchSuggestionsKey), findsNothing);
  });

  // Review Focus 1.
  testWidgets('a saved search loads as the whole search, axes cleared', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      filter: const DiveFilterState(minDepth: 30),
      savedLoads: [
        SavedQueryLoad(
          SavedQuery(
            id: 'q1',
            subject: 'dives',
            name: 'Mantas',
            queryJson: '{}',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          node: TextNode(['manta']),
        ),
      ],
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mantas'));
    await tester.pumpAndSettle();
    expect(filterOf(), DiveFilterState(query: TextNode(['manta'])));
  });

  testWidgets('Enter records a typed search', (tester) async {
    final typed = <String>[];
    await pumpHeader(
      tester,
      typedRecorder: (text, node, l, d) async => typed.add(text),
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(typed, ['manta']);
  });

  testWidgets('leaving the field after typing records the search', (
    tester,
  ) async {
    final typed = <String>[];
    await pumpHeader(
      tester,
      typedRecorder: (text, node, l, d) async => typed.add(text),
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(typed, ['manta']);
  });

  testWidgets('a query from outside is not recorded as typed', (tester) async {
    final typed = <String>[];
    await pumpHeader(
      tester,
      typedRecorder: (text, node, l, d) async => typed.add(text),
    );
    // Typed, then replaced from outside (a chip, an answer): what the field
    // ends up holding was not typed.
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: TextNode(['wreck']),
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(typed, isEmpty);
  });

  // Final review: the recents list printed the text from when it was
  // recorded, so it disagreed with the field after a units change.
  testWidgets('a typed recent shows in the diver units and current names', (
    tester,
  ) async {
    final node = normalizeQuery(
      const DiveFilterState(minDepth: 30, siteId: 's1').toQuery(),
    )!;
    final names = NameIndex([
      NameEntry(
        subject: QuerySubject.sites,
        label: 'Blue Hole',
        ids: const ['s1'],
        target: rowTargetFor(QuerySubject.sites),
        primary: true,
      ),
    ]);
    await pumpHeader(
      tester,
      names: names,
      prefs: const UnitPrefs(
        depth: DepthUnit.feet,
        temperature: TemperatureUnit.fahrenheit,
        pressure: PressureUnit.psi,
        weight: WeightUnit.pounds,
        volume: VolumeUnit.cubicFeet,
      ),
      recents: [
        RecentQuery(
          sentence: 'depth >= 30m site = "Old name"',
          locale: 'en',
          parsed: null,
          kind: RecentQueryKind.typed,
          node: node,
          lastUsedAt: DateTime(2026, 10, 2),
        ),
      ],
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pumpAndSettle();
    Finder inRecent(String text) => find.descendant(
      of: find.byType(ListTile),
      matching: find.textContaining(text),
    );
    expect(inRecent('Old name'), findsNothing);
    expect(inRecent('30m'), findsNothing);
    expect(inRecent('Blue Hole'), findsOneWidget);
    // 30 m as the diver's feet: a unitless number prints in their units.
    expect(inRecent('98.4'), findsOneWidget);
  });

  // Final review: a blur on text that does not parse filed the last tree.
  testWidgets('text that does not parse is not recorded', (tester) async {
    final typed = <String>[];
    await pumpHeader(
      tester,
      typedRecorder: (text, node, l, d) async => typed.add(text),
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'depth >');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(typed, isEmpty);
  });

  // Review Focus 1, pinned: a saved site that was deleted since.
  testWidgets('a saved search whose site is gone still loads', (tester) async {
    final node = ConditionNode(
      FieldPath(['site']),
      QueryOp.eq,
      const RefValue('gone', 'Old Reef'),
    );
    await pumpHeader(
      tester,
      savedLoads: [
        SavedQueryLoad(
          SavedQuery(
            id: 'q1',
            subject: 'dives',
            name: 'Old Reef dives',
            queryJson: '{}',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          node: node,
          problem: SavedQueryProblem.unresolvedRef,
        ),
      ],
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Old Reef dives'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(filterOf(), DiveFilterState(query: node));
    expect(find.textContaining('Old Reef'), findsWidgets);
  });

  // Plan ruling 3: a typed recent applies as typing would.
  testWidgets('a typed recent replaces the query and keeps the axes', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      filter: const DiveFilterState(minDepth: 30),
      recents: [
        RecentQuery(
          sentence: 'wreck',
          locale: 'en',
          parsed: null,
          kind: RecentQueryKind.typed,
          node: TextNode(['wreck']),
          lastUsedAt: DateTime(2026, 10, 2),
        ),
      ],
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'wreck'));
    await tester.pumpAndSettle();
    expect(
      filterOf(),
      DiveFilterState(minDepth: 30, query: TextNode(['wreck'])),
    );
  });

  // Plan ruling 3: an asked recent replays its stored answer.
  testWidgets('an asked recent replays', (tester) async {
    late _ReplayAsk fake;
    final recent = RecentQuery(
      sentence: 'turtles in Bonaire',
      locale: 'en',
      parsed: const ParsedQuery(subject: ParsedSubject.dives),
      lastUsedAt: DateTime(2026, 10, 1),
    );
    await pumpHeader(
      tester,
      askEnabled: true,
      ask: (ref) => fake = _ReplayAsk(ref),
      recents: [recent],
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'turtles in Bonaire'));
    await tester.pumpAndSettle();
    expect(fake.replayed, [recent]);
  });

  // Final review: Save read the filter, which still held the query from
  // before the debounce.
  testWidgets('Save inside the debounce stores what was typed', (tester) async {
    QueryNode? saved;
    await pumpHeader(
      tester,
      filter: DiveFilterState(query: TextNode(['manta'])),
      saveOverride: (node) => saved = node,
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'wreck');
    await tester.pump();
    await tester.tap(find.byKey(kDiveSearchSaveKey));
    await tester.pumpAndSettle();
    expect(saved, TextNode(['wreck']));
  });

  // Review: a typed recent naming a field this build lacks threw while
  // the suggestions printed it.
  testWidgets('a typed recent this build cannot read is left out', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      recents: [
        RecentQuery(
          sentence: 'noSuchField > 5',
          locale: 'en',
          parsed: null,
          kind: RecentQueryKind.typed,
          node: ConditionNode(
            FieldPath(['noSuchField']),
            QueryOp.gt,
            const NumberValue(5, null),
          ),
          lastUsedAt: DateTime(2026, 10, 2),
        ),
      ],
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(kDiveSearchSuggestionsKey), findsOneWidget);
    expect(find.textContaining('noSuchField'), findsNothing);
  });

  // Review: an asked recent ran with an empty field, so its notice or
  // error named a sentence the diver could not see.
  testWidgets('an asked recent shows its sentence in the field', (
    tester,
  ) async {
    final recent = RecentQuery(
      sentence: 'turtles in Bonaire',
      locale: 'en',
      parsed: const ParsedQuery(subject: ParsedSubject.dives),
      lastUsedAt: DateTime(2026, 10, 1),
    );
    await pumpHeader(
      tester,
      askEnabled: true,
      ask: (ref) => _ReplayAsk(ref),
      recents: [recent],
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'turtles in Bonaire'));
    await tester.pumpAndSettle();
    expect(fieldOf(tester).controller!.text, 'turtles in Bonaire');
    // The field is not empty, so the suggestions do not cover it.
    expect(find.byKey(kDiveSearchSuggestionsKey), findsNothing);
  });

  // Review: a tapped hint was filed as a typed search.
  testWidgets('a tapped hint is not recorded as typed', (tester) async {
    final typed = <String>[];
    await pumpHeader(
      tester,
      typedRecorder: (text, node, l, d) async => typed.add(text),
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    await tester.tap(find.text('manta'));
    await tester.pump();
    await tester.pump(kDiveSearchDebounce * 2);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(typed, isEmpty);
  });

  testWidgets('a hint the diver then edits is recorded', (tester) async {
    final typed = <String>[];
    await pumpHeader(
      tester,
      typedRecorder: (text, node, l, d) async => typed.add(text),
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    await tester.tap(find.text('manta'));
    await tester.pump();
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'mantas');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(typed, ['mantas']);
  });

  // Review: from an empty search, Save waited for the debounce to apply
  // the first query.
  testWidgets('Save offers a first query still on the debounce', (
    tester,
  ) async {
    QueryNode? saved;
    await pumpHeader(tester, saveOverride: (node) => saved = node);
    expect(find.byKey(kDiveSearchSaveKey), findsNothing);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    await tester.tap(find.byKey(kDiveSearchSaveKey));
    await tester.pumpAndSettle();
    expect(saved, TextNode(['manta']));
  });

  // Review: Save stayed up for a field just emptied, and its tap did
  // nothing.
  testWidgets('no Save once the field is emptied', (tester) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(query: TextNode(['manta'])),
    );
    expect(find.byKey(kDiveSearchSaveKey), findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), '');
    await tester.pump();
    expect(find.byKey(kDiveSearchSaveKey), findsNothing);
  });

  testWidgets('a hint is typed in and applied', (tester) async {
    await pumpHeader(tester);
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    await tester.tap(find.text('manta'));
    await tester.pump();
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf().query, TextNode(['manta']));
  });

  // Review finding: the jump list ran a full-log query per keystroke.
  testWidgets('the jump list queries only the debounced text', (tester) async {
    final queried = <QueryNode>[];
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveSearchBarOpenProvider.overrideWith((ref) => true),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith((ref, q) async {
            queried.add(q);
            return jumpRows;
          }),
        ],
        child: DiveSearchHeader(onOpenDive: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in ['m', 'ma', 'man']) {
      await tester.enterText(find.byKey(kDiveSearchFieldKey), text);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(queried, [
      TextNode(['man']),
    ]);
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsOneWidget);
  });

  testWidgets('jump rows stay while the next query loads', (tester) async {
    final pending = Completer<List<DiveSummary>>();
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveSearchBarOpenProvider.overrideWith((ref) => true),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith(
            (ref, q) => q == TextNode(['manta'])
                ? Future.value(jumpRows)
                : pending.future,
          ),
        ],
        child: DiveSearchHeader(onOpenDive: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsOneWidget);

    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta ray');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('dive-jump-d1')),
      findsOneWidget,
      reason: 'the previous rows stay until the new ones arrive',
    );
    pending.complete(const <DiveSummary>[]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsNothing);
  });

  // Code review: clearing the field must not leave the last jump rows up
  // for a debounce.
  testWidgets('clearing the field hides the jump rows at once', (tester) async {
    await pumpHeader(tester, jump: jumpRows);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), '');
    await tester.pump();
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsNothing);
    await tester.pump(kDiveSearchDebounce);
  });

  testWidgets('the Refine button opens the Refine panel', (tester) async {
    await pumpHeader(tester, filter: const DiveFilterState(minDepth: 30));
    await tester.tap(find.byKey(kDiveSearchRefineKey));
    await tester.pumpAndSettle();
    expect(find.byType(RefinePanel), findsOneWidget);
  });

  // Review finding (#2773): text typed just before opening Refine must not
  // be lost when the panel applies its draft.
  testWidgets('opening Refine inside the debounce keeps what was typed', (
    tester,
  ) async {
    await pumpHeader(tester);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(kDiveSearchRefineKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kRefineApplyKey));
    await tester.pumpAndSettle();
    expect(filterOf().query, TextNode(['manta']));
    expect(
      tester
          .widget<TextField>(find.byKey(kDiveSearchFieldKey))
          .controller!
          .text,
      'manta',
    );
  });

  // Code review: jumping to a dive closes the jump list.
  testWidgets('jumping to a dive closes the jump list', (tester) async {
    await pumpHeader(tester, jump: jumpRows, onOpenDive: (_) {});
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(kDiveSearchDebounce);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dive-jump-d1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dive-jump-d1')), findsNothing);
  });

  // Code review: on desktop the row sits in the narrow master pane, so the
  // pane's width decides, not the screen's.
  testWidgets('a narrow pane on a wide screen shows the Insights icon', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    await pumpHeader(
      tester,
      filter: const DiveFilterState(minDepth: 30),
      width: 400,
    );
    expect(
      tester.widget(find.byKey(kDiveSearchInsightsKey)),
      isA<IconButton>(),
    );
  });

  // Code review: on a phone, Open in Insights is an icon so the chips keep
  // the row.
  testWidgets('a narrow row shows Open in Insights as an icon', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await pumpHeader(tester, filter: const DiveFilterState(minDepth: 30));
    final insights = find.byKey(kDiveSearchInsightsKey);
    expect(tester.widget(insights), isA<IconButton>());
    expect(find.byTooltip('Open in Insights'), findsOneWidget);
  });
}

class _ReplayAsk extends DiveAskNotifier {
  _ReplayAsk(super.ref);

  final replayed = <RecentQuery>[];

  @override
  Future<String?> replay(RecentQuery recent) async {
    replayed.add(recent);
    return null;
  }
}
