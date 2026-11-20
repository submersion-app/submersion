import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/helpers/media_layout_aspect.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_preview.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_thumbnail_wheel_zoom.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';
import 'package:submersion/features/media/presentation/widgets/site_media_section.dart';

import '../support/media_widget_harness.dart';

class _NoShapesRepository implements MediaAspectCacheRepository {
  @override
  Future<Map<String, LearnedAspect>> loadAll() async => const {};

  @override
  Future<void> putAll(Map<String, LearnedAspect> entries) async {}
}

/// The Site Media card (issue #4741): every attachment, grouped by category
/// with its large cards as before (issue #1039), the tiles in justified rows
/// that keep each one's shape. Nothing hides behind +N.
void main() {
  /// Square photos. The card is 400 wide on the default host, 360 inside:
  /// at the 120 px target, three to a row.
  List<MediaItem> photos(int n, {SiteAttachmentCategory? category}) => [
    for (var i = 0; i < n; i++)
      testMediaItem(
        id: 'p$i',
        siteId: 'site-1',
        takenAt: DateTime(2026, 3, 1, 9).add(Duration(minutes: i)),
      ).copyWith(width: 100, height: 100, siteCategory: category),
  ];

  MediaItem doc(String id) => testMediaItem(
    id: id,
    siteId: 'site-1',
    mediaType: MediaType.document,
    originalFilename: '$id.pdf',
    takenAt: DateTime(2026, 3, 1, 12),
  );

  Future<void> pump(WidgetTester tester, List<MediaItem> attachments) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          mediaAspectCacheRepositoryProvider.overrideWithValue(
            _NoShapesRepository(),
          ),
          mediaForSiteProvider(
            'site-1',
          ).overrideWith((ref) async => attachments),
        ],
        home: const Scaffold(
          body: SingleChildScrollView(
            child: SiteMediaSection(siteId: 'site-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int shownTiles(WidgetTester tester) =>
      find.byType(MediaThumbnailTile).evaluate().length;

  testWidgets('every tile shows, in justified rows, with no +N', (
    tester,
  ) async {
    await pump(tester, [...photos(10), doc('d0')]);
    expect(shownTiles(tester), 11);
    expect(find.byKey(kJustifiedPreviewMoreKey), findsNothing);
    // Shapes kept: a square photo is as wide as it is tall, a document is
    // a 3:4 page.
    final photo = tester.getSize(find.byType(MediaThumbnailTile).first);
    expect(photo.width, closeTo(photo.height, 0.01));
    final page = tester.getSize(find.byType(MediaThumbnailTile).last);
    expect(page.width / page.height, closeTo(0.75, 0.01));
  });

  testWidgets('a large attachment keeps its card outside selection', (
    tester,
  ) async {
    final map = testMediaItem(
      id: 'map',
      siteId: 'site-1',
      originalFilename: 'map.png',
    ).copyWith(siteCategory: SiteAttachmentCategory.siteMap);
    await pump(tester, [
      map,
      ...photos(2, category: SiteAttachmentCategory.underwater),
    ]);
    expect(find.text('Site map (1)'), findsOneWidget);
    expect(find.text('Underwater (2)'), findsOneWidget);
    expect(find.byType(SiteAttachmentLargeCard), findsOneWidget);
    expect(shownTiles(tester), 2);
  });

  testWidgets('selecting keeps the same tiles', (tester) async {
    await pump(tester, [...photos(10), doc('d0')]);
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    expect(shownTiles(tester), 11);

    await tester.tap(find.byKey(const ValueKey('selection_exit')));
    await tester.pumpAndSettle();
    expect(shownTiles(tester), 11);
  });

  testWidgets('the card does not zoom', (tester) async {
    await pump(tester, photos(10));
    expect(find.byType(MediaThumbnailWheelZoom), findsNothing);
  });
}
