import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_dive_photos_card.dart';

import '../support/media_widget_harness.dart';

/// The Site Details card that shows photos from the dives logged at the site
/// (issue #4502): a one-row strip of the newest, and the full grid on demand.
void main() {
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
  }) => mediaTestApp(
    overrides: [
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

  testWidgets('strip shows as many of the newest photos as fit', (
    tester,
  ) async {
    final recent = photos(10);
    await tester.pumpWidget(await host(count: 10, recent: recent));
    await tester.pumpAndSettle();
    // 400 of strip: four 88-wide tiles with 8 between them.
    expect(shownIds(tester), ['p0', 'p1', 'p2', 'p3']);
  });

  testWidgets('the strip tiles fill the row edge to edge', (tester) async {
    await tester.pumpWidget(await host(count: 10, recent: photos(10)));
    await tester.pumpAndSettle();
    final tiles = find.byType(MediaThumbnailTile);
    final first = tester.getRect(tiles.first);
    final last = tester.getRect(tiles.last);
    expect(last.right - first.left, closeTo(400, 0.01));
    expect(first.width, first.height);
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

  testWidgets('a card under two tiles wide shows one tile filling it', (
    tester,
  ) async {
    // 160 of strip, under two tiles' worth. One photo, so the header has no
    // Show all button competing for the narrow row.
    await tester.pumpWidget(
      await host(count: 1, recent: photos(1), width: 200),
    );
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['p0']);
    expect(
      tester.getSize(find.byType(MediaThumbnailTile)).width,
      closeTo(160, 0.01),
    );
  });

  testWidgets('Show all is offered when the cap, not the width, limits', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1700, 900);
    addTearDown(tester.view.reset);
    // 1560 of strip fits 16 tiles, but the strip reads at most 12 of 14.
    await tester.pumpWidget(
      await host(
        count: 14,
        recent: photos(kSiteDivePhotoStripLimit),
        width: 1600,
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
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['p0', 'p1', 'p2', 'p3']);
    expect(find.byType(GridView), findsNothing);
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

  testWidgets('tapping a photo in the expanded grid opens the viewer there', (
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
