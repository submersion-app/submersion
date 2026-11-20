import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/presentation/pages/media_scoped_gallery_page.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_scoped_gallery_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_preview.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';
import 'package:submersion/features/media/presentation/widgets/site_dive_photos_card.dart';

import '../support/media_widget_harness.dart';

class _NoShapesRepository implements MediaAspectCacheRepository {
  @override
  Future<Map<String, LearnedAspect>> loadAll() async => const {};

  @override
  Future<void> putAll(Map<String, LearnedAspect> entries) async {}
}

/// The Site Details card that shows photos from the dives logged at the site
/// (issue #4502): two justified rows of the newest (issue #4741), and +N on
/// the last one shown for the rest, in the library.
void main() {
  /// Square photos: on the default 440 card (400 inside), three to a row at
  /// the 100 px target, so two rows hold six.
  List<MediaItem> photos(int n, {String prefix = 'p'}) => [
    for (var i = 0; i < n; i++)
      testMediaItem(
        id: '$prefix$i',
        diveId: 'dive-1',
        takenAt: DateTime(2026, 3, 1, 9).add(Duration(minutes: i)),
      ).copyWith(width: 120, height: 100),
  ];

  late ProviderContainer container;

  /// Hosts the card at [width] logical pixels on a router whose `/media` is
  /// a stand-in for the library. The card's own margin (4) and padding (16)
  /// leave `width - 40` for the preview.
  Future<Widget> host({
    required int count,
    List<MediaItem> recent = const [],
    double width = 440,
    Object? recentError,
    Future<List<MediaItem>>? pendingRecent,
  }) {
    final router = GoRouter(
      initialLocation: '/site',
      routes: [
        GoRoute(
          path: '/site',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: SiteDivePhotosCard(siteId: 'site-1', count: count),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        GoRoute(
          path: '/media',
          builder: (context, _) => const Scaffold(body: Text('LIBRARY')),
        ),
      ],
    );
    return mediaTestRouterApp(
      router: router,
      overrides: [
        mediaAspectCacheRepositoryProvider.overrideWithValue(
          _NoShapesRepository(),
        ),
        recentMediaFromDivesAtSiteProvider('site-1').overrideWith((ref) async {
          if (recentError != null) throw recentError;
          if (pendingRecent != null) return pendingRecent;
          return recent;
        }),
        flatMediaFromDivesAtSiteProvider(
          'site-1',
        ).overrideWith((ref) async => recent),
        siteProvider('site-1').overrideWith((ref) async => null),
        mediaScopedLibraryProvider.overrideWith(
          (ref, scope) => SeededMediaLibraryNotifier(),
        ),
      ],
    );
  }

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

  testWidgets('shows two justified rows of the newest photos', (tester) async {
    await tester.pumpWidget(await host(count: 20, recent: photos(20)));
    await tester.pumpAndSettle();
    expect(shownIds(tester), ['p0', 'p1', 'p2', 'p3', 'p4', 'p5']);
    final tops = {
      for (final e in find.byType(MediaThumbnailTile).evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    };
    expect(tops, hasLength(2));
  });

  testWidgets('each full row ends flush with the card', (tester) async {
    await tester.pumpWidget(await host(count: 20, recent: photos(20)));
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byType(MediaThumbnailTile).first);
    final third = tester.getRect(find.byType(MediaThumbnailTile).at(2));
    expect(third.right - first.left, closeTo(400, 0.01));
  });

  testWidgets('the last photo shown counts the rest, read or not', (
    tester,
  ) async {
    // 23 at the site, 20 read, six shown.
    await tester.pumpWidget(await host(count: 23, recent: photos(20)));
    await tester.pumpAndSettle();
    expect(find.text('+17'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(kJustifiedPreviewMoreKey)),
      tester.getRect(find.byType(MediaThumbnailTile).last),
    );
  });

  testWidgets('everything that fits shows without +N', (tester) async {
    await tester.pumpWidget(await host(count: 3, recent: photos(3)));
    await tester.pumpAndSettle();
    expect(shownIds(tester), hasLength(3));
    expect(find.byKey(kJustifiedPreviewMoreKey), findsNothing);
  });

  testWidgets('the card has no Show all button and no zoom', (tester) async {
    await tester.pumpWidget(await host(count: 20, recent: photos(20)));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(MediaThumbnailWheelZoom), findsNothing);
  });

  testWidgets('tapping +N opens a gallery of this site\'s dive photos', (
    tester,
  ) async {
    await tester.pumpWidget(await host(count: 20, recent: photos(20)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kJustifiedPreviewMoreKey));
    await tester.pumpAndSettle();

    final gallery = tester.widget<MediaScopedGalleryPage>(
      find.byType(MediaScopedGalleryPage),
    );
    expect(gallery.title, 'Photos from dives');
    expect(
      gallery.filter,
      const MediaLibraryFilter(
        siteId: 'site-1',
        attachedTo: {MediaAttachmentKind.dive},
      ),
    );
    expect(find.byType(SiteMediaViewerPage), findsNothing);
    // The Media screen keeps its own filter (issue #4741).
    expect(container.read(mediaLibraryFilterProvider), MediaLibraryFilter.none);
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

  testWidgets('a preview still loading shows a spinner', (tester) async {
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
