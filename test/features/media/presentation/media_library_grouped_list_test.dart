import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/media_group_header.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

MediaLibraryEntry entry(String id) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id.jpg',
    takenAt: DateTime.utc(2026, 6, 12),
    createdAt: DateTime.utc(2026, 6, 12),
    updatedAt: DateTime.utc(2026, 6, 12),
  ),
);

MediaLibraryGroup diveGroup({
  String? diveId,
  int? diveNumber,
  String? siteName,
  DateTime? diveDateTime,
  List<MediaLibraryEntry>? entries,
}) => MediaLibraryGroup(
  header: DiveGroupHeader(
    diveId: diveId,
    diveNumber: diveNumber,
    siteName: siteName,
    diveDateTime: diveDateTime,
  ),
  entries: entries ?? [entry('a')],
);

/// The status badge each tile now renders is a ConsumerWidget, so every tree
/// here needs a scope.
///
/// Typed `List<dynamic>` rather than `List<Override>` because Riverpod 3 does
/// not export the `Override` type: naming it fails to compile with
/// "The name 'Override' isn't a type". The `.cast()` at each call site is the
/// established workaround in this repo, not an oversight. Its dependencies are stubbed to the quiet state so the
/// badge stays invisible and these tests keep asserting only about grouping.
List<dynamic> _badgeOverrides() => [
  mediaStoreAttachedProvider.overrideWith((ref) async => false),
  mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
  // The list watches settingsProvider for its date headers. The real notifier
  // reaches for DiverSettingsRepository and a DatabaseService this harness
  // never starts, and its constructor load is unlistened, so a failure would
  // escape to the zone and fail whichever test is running at the time.
  settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
];

void main() {
  Widget host(
    List<MediaLibraryGroup> groups, {
    bool hasMore = false,
    VoidCallback? onLoadMore,
    void Function(MediaLibraryEntry)? onTileTap,
    Set<String> selectedIds = const {},
    bool isSelectionMode = false,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return ProviderScope(
      overrides: _badgeOverrides().cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: textDirection,
          child: Scaffold(
            body: MediaLibraryGroupedList(
              groups: groups,
              hasMore: hasMore,
              onLoadMore: onLoadMore ?? () {},
              onTileTap: onTileTap ?? (_) {},
              columns: 4,
              selectedIds: selectedIds,
              isSelectionMode: isSelectionMode,
            ),
          ),
        ),
      ),
    );
  }

  void setSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('builds only what is near the viewport (issue #3826)', () {
    int tiles() =>
        find.byType(MediaLibraryTile, skipOffstage: false).evaluate().length;
    int headers() =>
        find.byType(MediaGroupHeader, skipOffstage: false).evaluate().length;

    for (final (groups, each) in [
      (1, 60),
      (1, 180),
      (1, 1000),
      (500, 3),
      (3000, 3),
    ]) {
      testWidgets('$groups group(s) of $each', (tester) async {
        setSize(tester);
        await tester.pumpWidget(
          host([
            for (var g = 0; g < groups; g++)
              diveGroup(
                diveId: 'd$g',
                diveNumber: g,
                entries: [for (var i = 0; i < each; i++) entry('$g-$i')],
              ),
          ]),
        );
        await tester.pump();

        // Three pane heights at most, the visible one and two beyond it,
        // whatever the gallery holds.
        expect(tiles(), lessThan(100));
        expect(headers(), lessThan(30));

        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pump();

        expect(tiles(), lessThan(100));
        expect(headers(), lessThan(30));
      });
    }
  });

  testWidgets('the gallery is exactly as tall as its headers and thumbnails', (
    tester,
  ) async {
    setSize(tester);
    await tester.pumpWidget(
      host([
        diveGroup(
          diveId: 'd1',
          diveNumber: 1,
          entries: [for (var i = 0; i < 10; i++) entry('$i')],
        ),
      ]),
    );
    await tester.pump();

    // A 48 header, then 3 rows of (800 - 16 - 3 * 4) / 4 = 193 with 2 gaps of
    // 4, then 8 of padding, in a pane 600 tall.
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.maxScrollExtent, 48 + 3 * 193 + 2 * 4 + 8 - 600);
  });

  testWidgets('thumbnails sit as the old grids put them', (tester) async {
    setSize(tester);
    await tester.pumpWidget(
      host([
        diveGroup(
          diveId: 'd1',
          diveNumber: 1,
          entries: [for (var i = 0; i < 5; i++) entry('$i')],
        ),
      ]),
    );
    await tester.pump();

    final tiles = find.byType(MediaLibraryTile);
    expect(tester.getRect(tiles.at(0)), const Rect.fromLTWH(8, 48, 193, 193));
    expect(tester.getRect(tiles.at(3)), const Rect.fromLTWH(599, 48, 193, 193));
    expect(tester.getRect(tiles.at(4)), const Rect.fromLTWH(8, 245, 193, 193));
  });

  testWidgets('right to left mirrors the thumbnails', (tester) async {
    setSize(tester);
    await tester.pumpWidget(
      host([
        diveGroup(
          diveId: 'd1',
          diveNumber: 1,
          entries: [for (var i = 0; i < 5; i++) entry('$i')],
        ),
      ], textDirection: TextDirection.rtl),
    );
    await tester.pump();

    final tiles = find.byType(MediaLibraryTile);
    expect(tester.getRect(tiles.at(0)).right, 792);
    expect(tester.getRect(tiles.at(3)).left, 8);
    expect(tester.getRect(tiles.at(4)).right, 792);
  });

  testWidgets('a dive header reads as number and site', (tester) async {
    await tester.pumpWidget(
      host([diveGroup(diveId: 'd1', diveNumber: 9, siteName: 'Blue Hole')]),
    );
    await tester.pump();

    expect(find.text('#9 · Blue Hole'), findsOneWidget);
  });

  testWidgets('a dive with neither number nor site falls back to its date', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([diveGroup(diveId: 'd1', diveDateTime: DateTime.utc(2026, 6, 12))]),
    );
    await tester.pump();

    expect(find.text('Jun 12, 2026'), findsOneWidget);
  });

  testWidgets('a dive with nothing at all renders an empty header', (
    tester,
  ) async {
    await tester.pumpWidget(host([diveGroup(diveId: 'd1')]));
    await tester.pump();

    // No crash, and no stray label text.
    expect(find.byType(MediaLibraryGroupedList), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the unlinked group gets its own localized header', (
    tester,
  ) async {
    await tester.pumpWidget(host([diveGroup()]));
    await tester.pump();

    expect(find.text('Unlinked'), findsOneWidget);
  });

  testWidgets('only linked headers are tappable', (tester) async {
    await tester.pumpWidget(
      host([
        diveGroup(diveId: 'd1', diveNumber: 9),
        diveGroup(entries: [entry('b')]),
      ]),
    );
    await tester.pump();

    // The linked header navigates; the unlinked one has nowhere to go.
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('a dive header leaves the library beneath the dive detail', (
    tester,
  ) async {
    // Shell-shaped like production: app_router nests both /media and
    // /dives/:diveId inside one ShellRoute, and :diveId is a CHILD of /dives,
    // which is what makes a stack-replacing `go` synthesize the dive list.
    final router = GoRouter(
      initialLocation: '/media',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/media',
              builder: (context, state) => MediaLibraryGroupedList(
                groups: [diveGroup(diveId: 'd1', diveNumber: 9)],
                hasMore: false,
                onLoadMore: () {},
                onTileTap: (_) {},
                columns: 4,
                selectedIds: const {},
              ),
            ),
            GoRoute(
              path: '/dives',
              builder: (context, state) => const Text('Dive List'),
              routes: [
                GoRoute(
                  path: ':diveId',
                  builder: (context, state) => Scaffold(
                    appBar: AppBar(),
                    body: const Text('Dive Detail'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _badgeOverrides().cast(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('#9'));
    await tester.pumpAndSettle();
    expect(find.text('Dive Detail'), findsOneWidget);
    expect(router.state.uri.toString(), '/dives/d1');
    // skipOffstage: false -- the dive list must never be materialized, not
    // merely be invisible.
    expect(find.text('Dive List', skipOffstage: false), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('#9'), findsOneWidget);
    expect(find.text('Dive List', skipOffstage: false), findsNothing);
  });

  testWidgets('a dive header is inert while a selection is in progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        [
          diveGroup(diveId: 'd1', diveNumber: 9, entries: [entry('a')]),
        ],
        selectedIds: const {'a'},
        isSelectionMode: true,
      ),
    );
    await tester.pump();

    // Tiles toggle selection during multi-select; the header must not
    // navigate out from under a half-built selection.
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('#9'), findsOneWidget);
  });

  testWidgets('a dive header is inert in selection mode with nothing checked', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        diveGroup(diveId: 'd1', diveNumber: 9, entries: [entry('a')]),
      ], isSelectionMode: true),
    );
    await tester.pump();

    // The Select button enters the mode with an empty selection, a state the
    // old id-set could not represent. Keying header navigation off "something
    // is checked" would leave the header live for exactly that first tap.
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('#9'), findsOneWidget);
  });

  testWidgets('a linked dive with no label still shows a tappable header', (
    tester,
  ) async {
    await tester.pumpWidget(host([diveGroup(diveId: 'd1')]));
    await tester.pump();

    expect(find.text('Untitled dive'), findsOneWidget);
    final size = tester.getSize(find.byType(InkWell));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('tiles report taps with their entry', (tester) async {
    MediaLibraryEntry? tapped;
    await tester.pumpWidget(
      host([
        diveGroup(diveId: 'd1', diveNumber: 9, entries: [entry('a')]),
      ], onTileTap: (e) => tapped = e),
    );
    await tester.pump();

    await tester.tap(find.byType(MediaLibraryTile).first);
    await tester.pump();

    expect(tapped?.item.id, 'a');
  });

  testWidgets('scrolling near the end asks for more', (tester) async {
    var loadMoreCalls = 0;
    await tester.pumpWidget(
      host(
        [
          for (var i = 0; i < 30; i++)
            diveGroup(
              diveId: 'd$i',
              diveNumber: i,
              entries: [entry('a$i'), entry('b$i')],
            ),
        ],
        hasMore: true,
        onLoadMore: () => loadMoreCalls++,
      ),
    );
    await tester.pump();

    // Over-drag deliberately: the list clamps at maxScrollExtent, so this
    // reaches the end regardless of how tall the group headers are.
    await tester.drag(
      find.byType(MediaLibraryGroupedList),
      const Offset(0, -20000),
    );
    await tester.pump();

    expect(loadMoreCalls, greaterThan(0));
  });

  testWidgets('load-more stays quiet once the list is exhausted', (
    tester,
  ) async {
    var loadMoreCalls = 0;
    await tester.pumpWidget(
      host([
        for (var i = 0; i < 30; i++)
          diveGroup(diveId: 'd$i', diveNumber: i, entries: [entry('a$i')]),
      ], onLoadMore: () => loadMoreCalls++),
    );
    await tester.pump();

    // Over-drag deliberately: the list clamps at maxScrollExtent, so this
    // reaches the end regardless of how tall the group headers are.
    await tester.drag(
      find.byType(MediaLibraryGroupedList),
      const Offset(0, -20000),
    );
    await tester.pump();

    expect(loadMoreCalls, 0);
  });
}
