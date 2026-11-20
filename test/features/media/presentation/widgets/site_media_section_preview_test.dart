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
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_scoped_gallery_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_preview.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';
import 'package:submersion/features/media/presentation/widgets/site_media_section.dart';

import '../support/media_widget_harness.dart';

class _NoShapesRepository implements MediaAspectCacheRepository {
  @override
  Future<Map<String, LearnedAspect>> loadAll() async => const {};

  @override
  Future<void> putAll(Map<String, LearnedAspect> entries) async {}
}

/// The Site Media card's preview (issue #4741): documents first, then the
/// photos and videos in two justified rows, the last one shown carrying +N
/// and opening the library on the site's own attachments.
void main() {
  /// Square photos. The card is 400 wide on the default host, 360 inside:
  /// at the 120 px target, three to a row, so two rows hold six.
  List<MediaItem> photos(int n) => [
    for (var i = 0; i < n; i++)
      testMediaItem(
        id: 'p$i',
        siteId: 'site-1',
        takenAt: DateTime(2026, 3, 1, 9).add(Duration(minutes: i)),
      ).copyWith(width: 100, height: 100),
  ];

  List<MediaItem> docs(int n) => [
    for (var i = 0; i < n; i++)
      testMediaItem(
        id: 'd$i',
        siteId: 'site-1',
        mediaType: MediaType.document,
        originalFilename: 'rules$i.pdf',
        takenAt: DateTime(2026, 3, 1, 12).add(Duration(minutes: i)),
      ),
  ];

  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, List<MediaItem> attachments) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/site',
      routes: [
        GoRoute(
          path: '/site',
          builder: (context, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SingleChildScrollView(
                  child: SiteMediaSection(siteId: 'site-1'),
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
    await tester.pumpWidget(
      await mediaTestRouterApp(
        router: router,
        overrides: [
          mediaAspectCacheRepositoryProvider.overrideWithValue(
            _NoShapesRepository(),
          ),
          mediaForSiteProvider(
            'site-1',
          ).overrideWith((ref) async => attachments),
          siteProvider('site-1').overrideWith((ref) async => null),
          mediaScopedLibraryProvider.overrideWith(
            (ref, scope) => SeededMediaLibraryNotifier(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> shownIds(WidgetTester tester) => [
    for (final tile in tester.widgetList<MediaThumbnailTile>(
      find.byType(MediaThumbnailTile),
    ))
      tile.item.id,
  ];

  testWidgets('photos show in two rows, the last one counting the rest', (
    tester,
  ) async {
    await pump(tester, photos(10));
    expect(shownIds(tester), ['p0', 'p1', 'p2', 'p3', 'p4', 'p5']);
    expect(find.text('+4'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(kJustifiedPreviewMoreKey)),
      tester.getRect(find.byType(MediaThumbnailTile).last),
    );
  });

  testWidgets('documents come first, all of them, outside the rows', (
    tester,
  ) async {
    await pump(tester, [...photos(10), ...docs(4)]);
    expect(shownIds(tester), [
      'd0', 'd1', 'd2', 'd3', //
      'p0', 'p1', 'p2', 'p3', 'p4', 'p5',
    ]);
    // The documents are not in the library, so +N leaves them out.
    expect(find.text('+4'), findsOneWidget);
  });

  testWidgets('everything that fits shows without +N', (tester) async {
    await pump(tester, [...photos(4), ...docs(1)]);
    expect(shownIds(tester), hasLength(5));
    expect(find.byKey(kJustifiedPreviewMoreKey), findsNothing);
  });

  testWidgets('the preview does not zoom', (tester) async {
    await pump(tester, photos(10));
    expect(find.byType(MediaThumbnailWheelZoom), findsNothing);
  });

  testWidgets('tapping +N opens a gallery of the site\'s attachments', (
    tester,
  ) async {
    await pump(tester, photos(10));
    await tester.tap(find.byKey(kJustifiedPreviewMoreKey));
    await tester.pumpAndSettle();

    final gallery = tester.widget<MediaScopedGalleryPage>(
      find.byType(MediaScopedGalleryPage),
    );
    expect(gallery.title, 'Site Media');
    expect(
      gallery.filter,
      const MediaLibraryFilter(
        siteId: 'site-1',
        attachedTo: {MediaAttachmentKind.site},
      ),
    );
    expect(container.read(mediaLibraryFilterProvider), MediaLibraryFilter.none);
  });

  testWidgets('selecting shows every attachment, in justified rows', (
    tester,
  ) async {
    await pump(tester, [...photos(10), ...docs(1)]);
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();

    expect(shownIds(tester), hasLength(11));
    expect(find.byKey(kJustifiedPreviewMoreKey), findsNothing);
    // Shapes kept: a square photo is as wide as it is tall, a document is
    // a 3:4 page.
    final photo = tester.getSize(find.byType(MediaThumbnailTile).first);
    expect(photo.width, closeTo(photo.height, 0.01));
    final doc = tester.getSize(find.byType(MediaThumbnailTile).last);
    expect(doc.width / doc.height, closeTo(0.75, 0.01));

    await tester.tap(find.byKey(const ValueKey('selection_exit')));
    await tester.pumpAndSettle();
    expect(shownIds(tester), hasLength(7));
  });
}
