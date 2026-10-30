import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

/// An exact grid has no estimates to absorb a height change above the
/// viewport, so these pin that the view holds still when headers or
/// thumbnails above it change height (issue #3826).

MediaLibraryEntry _entry(String id) => MediaLibraryEntry(
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

List<MediaLibraryGroup> _groups(int count, {String site = 'Blue Hole'}) => [
  for (var g = 0; g < count; g++)
    MediaLibraryGroup(
      header: DiveGroupHeader(diveId: 'd$g', diveNumber: g, siteName: site),
      entries: [for (var i = 0; i < 4; i++) _entry('$g-$i')],
    ),
];

class _View {
  const _View({
    required this.groups,
    this.columns = 4,
    this.width = 800,
    this.selecting = false,
  });

  final List<MediaLibraryGroup> groups;
  final int columns;
  final double width;
  final bool selecting;

  _View copyWith({
    List<MediaLibraryGroup>? groups,
    int? columns,
    double? width,
    bool? selecting,
  }) => _View(
    groups: groups ?? this.groups,
    columns: columns ?? this.columns,
    width: width ?? this.width,
    selecting: selecting ?? this.selecting,
  );
}

void main() {
  Widget host(_View view) => ProviderScope(
    overrides: [
      mediaStoreAttachedProvider.overrideWith((ref) async => false),
      mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: view.width,
            child: MediaLibraryGroupedList(
              groups: view.groups,
              hasMore: false,
              onLoadMore: () {},
              onTileTap: (_) {},
              columns: view.columns,
              isSelectionMode: view.selecting,
            ),
          ),
        ),
      ),
    ),
  );

  Finder tileOf(String id) => find.byWidgetPredicate(
    (w) => w is MediaLibraryTile && w.entry.item.id == id,
  );

  ScrollPosition positionOf(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  /// Opens [view] scrolled [offset] down, nudged until a thumbnail in a row's
  /// first column crosses the top edge, and returns it.
  Future<String> openAt(
    WidgetTester tester,
    _View view, {
    double offset = 20000,
  }) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(view));
    await tester.pump();
    final position = positionOf(tester);
    position.jumpTo(offset);
    await tester.pump();
    for (var nudge = 0; nudge < 40; nudge++) {
      for (final element in find.byType(MediaLibraryTile).evaluate()) {
        final tile = element.widget as MediaLibraryTile;
        if (!tile.entry.item.id.endsWith('-0')) continue;
        final rect = tester.getRect(find.byWidget(tile));
        if (rect.top < -5 && rect.bottom > 5) return tile.entry.item.id;
      }
      position.jumpTo(position.pixels + 30);
      await tester.pump();
    }
    fail('no thumbnail crossed the top edge');
  }

  /// How far down the thumbnail the top edge falls, 0 to 1.
  double fractionAtEdge(WidgetTester tester, String id) {
    final rect = tester.getRect(tileOf(id));
    return -rect.top / rect.height;
  }

  testWidgets('entering and leaving selection holds the view still', (
    tester,
  ) async {
    final view = _View(groups: _groups(300));
    final id = await openAt(tester, view);
    final top = tester.getRect(tileOf(id)).top;

    await tester.pumpWidget(host(view.copyWith(selecting: true)));
    expect(tester.getRect(tileOf(id)).top, moreOrLessEquals(top));

    await tester.pumpWidget(host(view));
    expect(tester.getRect(tileOf(id)).top, moreOrLessEquals(top));
  });

  testWidgets('the size slider holds the view still', (tester) async {
    final view = _View(groups: _groups(300));
    final id = await openAt(tester, view);
    final before = fractionAtEdge(tester, id);

    // No wheel, so no anchor: the column count just changes.
    await tester.pumpWidget(host(view.copyWith(columns: 2)));

    expect(tileOf(id), findsOneWidget);
    expect(fractionAtEdge(tester, id), moreOrLessEquals(before, epsilon: 0.01));
  });

  testWidgets('a width change holds the view still', (tester) async {
    final view = _View(groups: _groups(300));
    final id = await openAt(tester, view);
    final before = fractionAtEdge(tester, id);

    await tester.pumpWidget(host(view.copyWith(width: 500)));

    expect(fractionAtEdge(tester, id), moreOrLessEquals(before, epsilon: 0.01));
  });

  testWidgets('a pane dragged wider and narrower holds the view still', (
    tester,
  ) async {
    final view = _View(groups: _groups(300));
    final id = await openAt(tester, view);
    final before = fractionAtEdge(tester, id);

    for (final width in [790.0, 760.0, 700.0, 640.0, 700.0, 860.0, 1000.0]) {
      await tester.pumpWidget(host(view.copyWith(width: width)));
      expect(
        fractionAtEdge(tester, id),
        moreOrLessEquals(before, epsilon: 0.01),
        reason: 'at $width',
      );
    }
  });

  testWidgets('a header that stops wrapping above the view holds it still', (
    tester,
  ) async {
    final view = _View(
      groups: _groups(
        300,
        site: 'A dive site with a very long name that wraps when narrow',
      ),
      width: 400,
    );
    final id = await openAt(tester, view);
    final before = fractionAtEdge(tester, id);

    await tester.pumpWidget(host(view.copyWith(width: 1190)));

    expect(fractionAtEdge(tester, id), moreOrLessEquals(before, epsilon: 0.01));
  });

  testWidgets('paging moves nothing on screen', (tester) async {
    final groups = _groups(300);
    final view = _View(groups: groups);
    final id = await openAt(tester, view);
    final top = tester.getRect(tileOf(id)).top;

    await tester.pumpWidget(
      host(view.copyWith(groups: [...groups, ..._groups(1)])),
    );

    expect(tester.getRect(tileOf(id)).top, moreOrLessEquals(top));
  });

  testWidgets('at the very top, a change stays at the very top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final view = _View(groups: _groups(300));
    await tester.pumpWidget(host(view));
    await tester.pump();

    await tester.pumpWidget(host(view.copyWith(columns: 2, selecting: true)));

    expect(positionOf(tester).pixels, 0);
  });
}
