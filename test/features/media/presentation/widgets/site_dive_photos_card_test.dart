import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/learned_aspect.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_block.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_dive_photos_card.dart';

import '../support/media_widget_harness.dart';

/// A learned-shape store whose load waits for [load].
class _PendingShapes implements MediaAspectCacheRepository {
  _PendingShapes(this.load);

  final Future<Map<String, LearnedAspect>> load;

  @override
  Future<Map<String, LearnedAspect>> loadAll() => load;

  @override
  Future<void> putAll(Map<String, LearnedAspect> entries) async {}
}

/// The Site Details card that shows photos from the dives logged at the site
/// (issue #4502): one justified row of the newest, flush with the card, and
/// every photo in justified rows on demand (issue #4741).
void main() {
  /// Photos with no stored size, so each lays out at the 4:3 fallback: at
  /// the 100 px target three fill the 400 px strip (133 px each, 4 apart).
  List<MediaItem> photos(int n, {String prefix = 'p'}) => [
    for (var i = 0; i < n; i++)
      testMediaItem(
        id: '$prefix$i',
        diveId: 'dive-1',
        takenAt: DateTime(2026, 3, 1, 9).add(Duration(minutes: i)),
      ),
  ];

  /// Hosts the card at [width] logical pixels. The card's own margin (4) and
  /// padding (16) leave `width - 40` for the strip.
  Future<Widget> host({
    required int count,
    List<MediaItem> recent = const [],
    List<MediaItem> all = const [],
    double width = 440,
    List<String>? recentReads,
    List<String>? allReads,
    Object? recentError,
    Future<List<MediaItem>>? pendingRecent,
    MediaAspectCacheRepository? shapes,
  }) => mediaTestApp(
    // No thumbnail decodes, so no tile teaches the learned shapes a stand-in
    // image's 1:1 and the stored shapes stay the ones laid out (issue
    // #4741). A test that needs a report calls onImageSize.
    resolverData: const UnavailableData(kind: UnavailableKind.notFound),
    overrides: [
      mediaAspectCacheRepositoryProvider.overrideWithValue(
        shapes ?? FakeAspectCacheRepository(),
      ),
      recentMediaFromDivesAtSiteProvider('site-1').overrideWith((ref) async {
        recentReads?.add('site-1');
        if (recentError != null) throw recentError;
        if (pendingRecent != null) return pendingRecent;
        return recent;
      }),
      flatMediaFromDivesAtSiteProvider('site-1').overrideWith((ref) async {
        allReads?.add('site-1');
        return all;
      }),
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SiteDivePhotosCard(siteId: 'site-1', count: count),
          ),
        ),
      ),
    ),
  );

  List<String> shownIds(WidgetTester tester) => [
    for (final tile in tester.widgetList<MediaThumbnailTile>(
      find.byType(MediaThumbnailTile),
    ))
      tile.item.id,
  ];

  testWidgets('shows the title with the count', (tester) async {
    await tester.pumpWidget(await host(count: 23, recent: photos(3)));
    await tester.pumpAndSettle();
    expect(find.text('Photos from dives (23)'), findsOneWidget);
  });

  testWidgets('strip shows one justified row of the newest photos', (
    tester,
  ) async {
    await tester.pumpWidget(await host(count: 10, recent: photos(10)));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['p0', 'p1', 'p2']);
    final tiles = find.byType(MediaThumbnailTile);
    final heights = {
      for (final e in tiles.evaluate())
        tester.getSize(find.byWidget(e.widget)).height,
    };
    expect(heights, hasLength(1));
  });

  testWidgets('the strip ends flush with the card and keeps shapes', (
    tester,
  ) async {
    await tester.pumpWidget(await host(count: 10, recent: photos(10)));
    await tester.pumpAndSettle();
    final tiles = find.byType(MediaThumbnailTile);
    final first = tester.getRect(tiles.first);
    final last = tester.getRect(tiles.last);
    expect(last.right - first.left, closeTo(400, 0.5));
    expect(first.width / first.height, closeTo(4 / 3, 0.02));
  });

  testWidgets('a strip that does not reach the edge is not stretched', (
    tester,
  ) async {
    await tester.pumpWidget(await host(count: 1, recent: photos(1)));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(MediaThumbnailTile));
    expect(size.height, closeTo(100, 0.01));
    expect(size.width, closeTo(400 / 3, 0.01));
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('strip never exceeds the query cap', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2100, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await host(
        count: 40,
        recent: photos(kSiteDivePhotoStripLimit),
        width: 2000,
      ),
    );
    await tester.pumpAndSettle();
    expect(shownIds(tester), hasLength(kSiteDivePhotoStripLimit));
  });

  testWidgets('a card narrower than one photo shows it at the card width', (
    tester,
  ) async {
    // 80 of strip, under one 133 px photo. One photo, so the header has no
    // Show all button competing for the narrow row.
    await tester.pumpWidget(
      await host(count: 1, recent: photos(1), width: 120),
    );
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['p0']);
    expect(
      tester.getSize(find.byType(MediaThumbnailTile)).width,
      closeTo(80, 0.01),
    );
  });

  testWidgets('Show all is offered when the cap, not the width, limits', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1800, 900);
    addTearDown(tester.view.reset);
    // 1660 of strip holds all 12 photos the strip reads, but there are 14.
    await tester.pumpWidget(
      await host(
        count: 14,
        recent: photos(kSiteDivePhotoStripLimit),
        width: 1700,
      ),
    );
    await tester.pumpAndSettle();
    expect(shownIds(tester), hasLength(kSiteDivePhotoStripLimit));
    expect(find.text('Show all'), findsOneWidget);
  });

  testWidgets('Show all is hidden when everything fits', (tester) async {
    await tester.pumpWidget(await host(count: 3, recent: photos(3)));
    await tester.pumpAndSettle();
    expect(shownIds(tester), hasLength(3));
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('Show all is hidden while the strip loads', (tester) async {
    final pending = Completer<List<MediaItem>>();
    await tester.pumpWidget(
      await host(count: 20, pendingRecent: pending.future),
    );
    await tester.pump();
    expect(find.text('Show all'), findsNothing);
    pending.complete(photos(10));
    await tester.pumpAndSettle();
    expect(find.text('Show all'), findsOneWidget);
  });

  testWidgets('Show all reads the full list only when tapped', (tester) async {
    final allReads = <String>[];
    final all = photos(9, prefix: 'a');
    await tester.pumpWidget(
      await host(count: 9, recent: photos(9), all: all, allReads: allReads),
    );
    await tester.pumpAndSettle();
    expect(allReads, isEmpty);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(allReads, hasLength(1));
    expect(shownIds(tester), [for (final m in all) m.id]);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['p0', 'p1', 'p2']);
  });

  testWidgets('expanded photos keep their shapes', (tester) async {
    final tall = testMediaItem(
      id: 'tall',
      diveId: 'dive-1',
    ).copyWith(width: 300, height: 400);
    await tester.pumpWidget(
      await host(count: 9, recent: photos(9), all: [...photos(3), tall]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    final size = tester.getSize(
      find.byWidgetPredicate(
        (w) => w is MediaThumbnailTile && w.item.id == 'tall',
      ),
    );
    expect(size.width / size.height, closeTo(0.75, 0.02));
    expect(find.byType(JustifiedMediaBlock), findsOneWidget);
  });

  testWidgets('nothing is laid out until the learned shapes load', (
    tester,
  ) async {
    // A photo stored landscape and shown portrait must not lay out wide
    // first and then jump.
    final load = Completer<Map<String, LearnedAspect>>();
    await tester.pumpWidget(
      await host(
        count: 1,
        recent: photos(1),
        shapes: _PendingShapes(load.future),
      ),
    );
    await tester.pump();
    expect(find.byType(MediaThumbnailTile), findsNothing);

    load.complete({'p0': (ratio: 0.75, width: null, height: null)});
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(MediaThumbnailTile));
    expect(size.width / size.height, closeTo(0.75, 0.02));
  });

  testWidgets('a tile decodes at its laid-out size and reports its shape', (
    tester,
  ) async {
    final shapes = FakeAspectCacheRepository();
    await tester.pumpWidget(
      await host(count: 1, recent: photos(1), width: 1200, shapes: shapes),
    );
    await tester.pumpAndSettle();
    final finder = find.byType(MediaThumbnailTile);
    final tile = tester.widget<MediaThumbnailTile>(finder);
    expect(tile.targetSize, mediaThumbnailDecodeTarget(tester.getSize(finder)));
    // A photo stored 4:3 whose thumbnail decodes portrait is learned and
    // stored, so the next layout keeps its real shape.
    tile.onImageSize!(const Size(300, 400));
    await tester.pump();
    await tester.pump();
    expect(shapes.written, ['p0']);
  });

  testWidgets('tiles are read-only dive photos', (tester) async {
    await tester.pumpWidget(await host(count: 1, recent: photos(1)));
    await tester.pumpAndSettle();
    final tile = tester.widget<MediaThumbnailTile>(
      find.byType(MediaThumbnailTile),
    );
    expect(tile.isSelectionMode, isFalse);
    expect(tile.semanticsLabel, 'Dive photo');
  });

  testWidgets('tapping a photo opens the viewer in divePhotos scope', (
    tester,
  ) async {
    await tester.pumpWidget(await host(count: 3, recent: photos(3)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MediaThumbnailTile).at(1));
    await tester.pumpAndSettle();

    final viewer = tester.widget<SiteMediaViewerPage>(
      find.byType(SiteMediaViewerPage),
    );
    expect(viewer.siteId, 'site-1');
    expect(viewer.initialMediaId, 'p1');
    expect(viewer.scope, SiteViewerScope.divePhotos);
  });

  testWidgets('tapping a photo in the expanded rows opens the viewer there', (
    tester,
  ) async {
    await tester.pumpWidget(
      await host(
        count: 9,
        recent: photos(9),
        all: photos(9, prefix: 'a'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MediaThumbnailTile).at(6));
    await tester.pumpAndSettle();

    final viewer = tester.widget<SiteMediaViewerPage>(
      find.byType(SiteMediaViewerPage),
    );
    expect(viewer.initialMediaId, 'a6');
    expect(viewer.scope, SiteViewerScope.divePhotos);
  });

  testWidgets('a strip still loading shows a spinner', (tester) async {
    final pending = Completer<List<MediaItem>>();
    await tester.pumpWidget(
      await host(count: 2, pendingRecent: pending.future),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNothing);

    pending.complete(photos(2));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
  });

  testWidgets('a failed read shows the error text', (tester) async {
    await tester.pumpWidget(
      await host(count: 2, recentError: StateError('boom')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Error loading media'), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNothing);
  });
}
