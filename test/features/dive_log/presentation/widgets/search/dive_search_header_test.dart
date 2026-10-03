import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveFilterProvider.overrideWith((ref) => filter),
          diveSearchBarOpenProvider.overrideWith((ref) => open),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith(
            (ref, q) => jumpFor != null ? jumpFor(q) : Future.value(jump),
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
