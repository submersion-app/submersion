import 'dart:async';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';
import 'package:submersion/features/media/domain/value_objects/learned_aspect.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_thumbnail_scale_provider.dart';
import 'package:submersion/features/media/presentation/widgets/justified_media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_groups.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

import '../support/media_widget_harness.dart';

/// Issue #1039: a site's attachments in category groups.
void main() {
  late SelectionController selection;
  late List<String> opened;

  setUp(() {
    selection = SelectionController();
    opened = [];
  });

  tearDown(() => selection.dispose());

  MediaItem m(String id, int minute, {SiteAttachmentCategory? category}) =>
      testMediaItem(
        id: id,
        siteId: 's1',
        originalFilename: '$id.png',
        takenAt: DateTime(2026, 3, 1, 9, minute),
      ).copyWith(siteCategory: category);

  Future<void> pump(
    WidgetTester tester,
    List<MediaItem> items, {
    MediaAspectCacheRepository? shapes,
    bool settle = true,
    double width = 400,
    TextDirection direction = TextDirection.ltr,
  }) async {
    // Tall enough that a large tile and the tiles under it are all on
    // screen, so taps land.
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await mediaTestApp(
        // No thumbnail decodes, so no tile teaches the learned shapes a
        // stand-in image's 1:1 and the stored shapes stay the ones laid out
        // (issue #4741). A test that needs a report calls onImageSize.
        resolverData: const UnavailableData(kind: UnavailableKind.notFound),
        overrides: [
          mediaAspectCacheRepositoryProvider.overrideWithValue(
            shapes ?? FakeAspectCacheRepository(),
          ),
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            // The section rebuilds on every selection change; so does this
            // host, as the section's ValueListenableBuilder does.
            child: ValueListenableBuilder<SelectionState>(
              valueListenable: selection,
              builder: (context, state, _) => Directionality(
                textDirection: direction,
                child: SiteAttachmentGroups(
                  layout: layoutSiteAttachments(items),
                  selection: selection,
                  isSelectionMode: state.isActive,
                  settings: const AppSettings(),
                  onOpen: (item) => opened.add(item.id),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('uncategorized-only shows tiles and no headings', (tester) async {
    await pump(tester, [m('a', 1), m('b', 2)]);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.textContaining('Uncategorized'), findsNothing);
  });

  testWidgets('headings follow category order with counts', (tester) async {
    await pump(tester, [
      m('u', 1),
      m('w', 2, category: SiteAttachmentCategory.underwater),
      m('s', 3, category: SiteAttachmentCategory.siteMap),
    ]);
    final siteMap = tester.getTopLeft(find.text('Site map (1)')).dy;
    final underwater = tester.getTopLeft(find.text('Underwater (1)')).dy;
    final none = tester.getTopLeft(find.text('Uncategorized (1)')).dy;
    expect(siteMap, lessThan(underwater));
    expect(underwater, lessThan(none));
  });

  Finder tileOf(String id) =>
      find.byWidgetPredicate((w) => w is MediaThumbnailTile && w.item.id == id);

  testWidgets('a site map and an underwater photo are both tiles', (
    tester,
  ) async {
    await pump(tester, [
      m('s', 1, category: SiteAttachmentCategory.siteMap),
      m('w', 2, category: SiteAttachmentCategory.underwater),
    ]);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.byTooltip('More options'), findsNothing);
  });

  testWidgets('outside selection, a tap opens a large tile and a tile', (
    tester,
  ) async {
    await pump(tester, [
      m('s', 1, category: SiteAttachmentCategory.siteMap),
      m('w', 2, category: SiteAttachmentCategory.underwater),
    ]);
    await tester.tap(tileOf('s'));
    await tester.tap(tileOf('w'));
    expect(opened, ['s', 'w']);
  });

  testWidgets('selection can span a large tile and a tile', (tester) async {
    await pump(tester, [
      m('s', 1, category: SiteAttachmentCategory.siteMap),
      m('w', 2, category: SiteAttachmentCategory.underwater),
    ]);
    selection.enterExplicit();
    await tester.pumpAndSettle();
    await tester.tap(tileOf('s'));
    await tester.pumpAndSettle();
    await tester.tap(tileOf('w'));
    await tester.pumpAndSettle();
    expect(selection.value.checkedIds, {'s', 'w'});
    expect(opened, isEmpty);
  });

  testWidgets('a tile tap keeps the checks made in another group', (
    tester,
  ) async {
    await pump(tester, [
      m('w1', 1, category: SiteAttachmentCategory.underwater),
      m('u1', 2),
    ]);
    selection.enterExplicit();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).last);
    await tester.pumpAndSettle();
    expect(selection.value.checkedIds, {'w1', 'u1'});
  });

  // Issue #4741: tiles in justified rows that keep each one's shape.
  MediaItem sized(String id, int minute, int width, int height) => m(
    id,
    minute,
    category: SiteAttachmentCategory.underwater,
  ).copyWith(width: width, height: height);

  double ratioOf(WidgetTester tester, String id) {
    final size = tester.getSize(
      find.byWidgetPredicate((w) => w is MediaThumbnailTile && w.item.id == id),
    );
    return size.width / size.height;
  }

  JustifiedMediaTable tableOf(WidgetTester tester) =>
      (tester
                  .widget<DragSelectGridView<MediaItem>>(
                    find.byType(DragSelectGridView<MediaItem>),
                  )
                  .gridDelegate
              as JustifiedMediaGridDelegate)
          .table;

  testWidgets("tiles keep each attachment's shape", (tester) async {
    await pump(tester, [sized('w', 1, 400, 300), sized('t', 2, 300, 400)]);
    expect(ratioOf(tester, 'w'), closeTo(4 / 3, 0.02));
    expect(ratioOf(tester, 't'), closeTo(3 / 4, 0.02));
  });

  testWidgets("a document tile lays out at a page's shape", (tester) async {
    final doc = testMediaItem(
      id: 'doc',
      siteId: 's1',
      mediaType: MediaType.document,
      originalFilename: 'rules.pdf',
    ).copyWith(displaySizeOverride: AttachmentDisplaySize.tile);
    await pump(tester, [doc]);
    expect(ratioOf(tester, 'doc'), closeTo(0.75, 0.02));
  });

  testWidgets('tiles wait for the learned shapes', (tester) async {
    final load = Completer<Map<String, LearnedAspect>>();
    await pump(
      tester,
      [sized('w', 1, 400, 300)],
      shapes: _PendingShapes(load.future),
      settle: false,
    );
    await tester.pump();
    expect(find.byType(MediaThumbnailTile), findsNothing);
    load.complete({'w': (ratio: 0.75, width: 400, height: 300)});
    await tester.pumpAndSettle();
    expect(ratioOf(tester, 'w'), closeTo(0.75, 0.02));
  });

  testWidgets('a selection change keeps the tile layout', (tester) async {
    // Every check rebuilds the groups; a new table would lay them all out
    // again.
    await pump(tester, [sized('a', 1, 400, 300), sized('b', 2, 300, 400)]);
    final before = tableOf(tester);
    selection.toggle('a');
    await tester.pump();
    expect(identical(tableOf(tester), before), isTrue);
  });

  testWidgets('a group adds no safe-area padding around its tiles', (
    tester,
  ) async {
    // A phone's home indicator inset belongs to the page, not to each grid.
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 34);
    addTearDown(tester.view.resetPadding);
    await pump(tester, [sized('a', 1, 400, 300), sized('b', 2, 300, 400)]);
    final grid = find.byType(DragSelectGridView<MediaItem>);
    expect(
      tester.getSize(grid).height,
      closeTo(tableOf(tester).totalExtent, 0.5),
    );
  });

  testWidgets('a tile decodes at its own laid-out size', (tester) async {
    // A 3:1 panorama at the 120 px target is 360 wide: past the 200 px
    // default, so the tile must ask for more.
    await pump(tester, [sized('a', 1, 300, 100)]);
    final tile = find.byType(MediaThumbnailTile);
    expect(tester.getSize(tile).width, closeTo(360, 0.5));
    expect(
      tester.widget<MediaThumbnailTile>(tile).targetSize,
      mediaThumbnailDecodeTarget(tester.getSize(tile)),
    );
  });

  testWidgets('a tile teaches the learned shapes and relays out', (
    tester,
  ) async {
    // Stored 4:3, decoded portrait: a photo kept sideways with an EXIF turn.
    final shapes = FakeAspectCacheRepository();
    await pump(tester, [sized('a', 1, 400, 300)], shapes: shapes);
    tester
        .widget<MediaThumbnailTile>(find.byType(MediaThumbnailTile))
        .onImageSize!(const Size(300, 400));
    await tester.pumpAndSettle();
    expect(shapes.written, ['a']);
    final size = tester.getSize(find.byType(MediaThumbnailTile));
    expect(size.width / size.height, closeTo(0.75, 0.02));
  });

  testWidgets('drag-select covers the tiles between the anchor and the '
      'pointer across uneven tiles', (tester) async {
    await pump(tester, [
      sized('a', 1, 300, 400),
      sized('b', 2, 480, 270),
      sized('c', 3, 300, 300),
      sized('d', 4, 270, 480),
    ]);
    selection.enterExplicit();
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(tileOf('a')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(tileOf('c')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selection.value.checkedIds.toSet(), {'a', 'b', 'c'});
  });

  // Issue #4786: a Large attachment spans two rows of its group's tiles.
  MediaItem large(String id, int minute, int width, int height) => sized(
    id,
    minute,
    width,
    height,
  ).copyWith(displaySizeOverride: AttachmentDisplaySize.large);

  testWidgets('a Large attachment spans two rows, first in its group, with '
      'the rows beside it flush', (tester) async {
    // Captured last, still laid out first.
    await pump(tester, [
      sized('a', 1, 400, 300),
      sized('b', 2, 300, 400),
      sized('c', 3, 400, 400),
      sized('d', 4, 480, 270),
      sized('e', 5, 300, 400),
      sized('f', 6, 400, 300),
      sized('g', 7, 400, 300),
      sized('h', 8, 300, 400),
      sized('i', 9, 400, 300),
      sized('j', 10, 400, 400),
      sized('k', 11, 480, 270),
      large('map', 12, 400, 300),
    ], width: 900);
    final grid = tester.getRect(find.byType(DragSelectGridView<MediaItem>));
    final map = tester.getRect(tileOf('map'));
    expect(map.topLeft, grid.topLeft);
    expect(map.width / map.height, closeTo(4 / 3, 0.02));
    expect(map.height, greaterThan(2 * kSiteAttachmentRowHeight * 0.75));

    final tiles = [
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k'])
        tester.getRect(tileOf(id)),
    ];
    final beside = tiles.where((r) => r.top < map.bottom).toList();
    final rows = {for (final r in beside) r.top};
    expect(rows.length, 2);
    for (final top in rows) {
      final row = beside.where((r) => r.top == top);
      expect(
        row.map((r) => r.left).reduce((a, b) => a < b ? a : b),
        closeTo(map.right + kSiteAttachmentGap, 0.5),
      );
      expect(
        row.map((r) => r.right).reduce((a, b) => a > b ? a : b),
        closeTo(grid.right, 0.5),
      );
    }
    for (final r in beside.where((r) => r.top == rows.last)) {
      expect(r.bottom, closeTo(map.bottom, 0.5));
    }
  });

  testWidgets('right to left, a Large attachment sits at the right with its '
      'rows to its left', (tester) async {
    await pump(
      tester,
      [
        for (var i = 0; i < 11; i++) sized('t$i', i + 1, 400, 300),
        large('map', 12, 400, 300),
      ],
      width: 900,
      direction: TextDirection.rtl,
    );
    final grid = tester.getRect(find.byType(DragSelectGridView<MediaItem>));
    final map = tester.getRect(tileOf('map'));
    expect(map.right, closeTo(grid.right, 0.5));
    expect(map.top, grid.top);
    final beside = [
      for (var i = 0; i < 11; i++) tester.getRect(tileOf('t$i')),
    ].where((r) => r.top < map.bottom).toList();
    expect(beside, isNotEmpty);
    for (final r in beside) {
      expect(r.right, lessThanOrEqualTo(map.left - kSiteAttachmentGap + 0.5));
    }
    expect(
      beside.map((r) => r.left).reduce((a, b) => a < b ? a : b),
      closeTo(grid.left, 0.5),
    );
  });

  testWidgets('on a phone a wide Large attachment fills the width alone', (
    tester,
  ) async {
    await pump(tester, [
      large('map', 1, 400, 300),
      sized('a', 2, 400, 300),
    ], width: 390);
    final grid = tester.getRect(find.byType(DragSelectGridView<MediaItem>));
    final map = tester.getRect(tileOf('map'));
    expect(map.width, closeTo(grid.width, 0.5));
    expect(map.height, closeTo(grid.width * 3 / 4, 0.5));
    expect(
      tester.getRect(tileOf('a')).top,
      closeTo(map.bottom + kSiteAttachmentGap, 0.5),
    );
  });

  testWidgets('a group of only Large attachments still lays out', (
    tester,
  ) async {
    await pump(tester, [large('map', 1, 400, 300)], width: 900);
    final map = tester.getSize(tileOf('map'));
    expect(map.height, closeTo(2 * kSiteAttachmentRowHeight + 4, 0.5));
  });

  testWidgets('a Large photo draws its original, letterboxed; a tile draws '
      'its thumbnail', (tester) async {
    await pump(tester, [large('map', 1, 400, 300), sized('a', 2, 400, 300)]);
    MediaItemView viewOf(String id) => tester.widget<MediaItemView>(
      find.descendant(of: tileOf(id), matching: find.byType(MediaItemView)),
    );
    expect(viewOf('map').thumbnail, isFalse);
    expect(viewOf('map').fit, BoxFit.contain);
    expect(viewOf('a').thumbnail, isTrue);
    expect(viewOf('a').fit, BoxFit.cover);
    // Learned shapes come from thumbnails only: an original's decode does
    // not teach them.
    expect(viewOf('map').onImageSize, isNull);
    expect(viewOf('a').onImageSize, isNotNull);
  });

  testWidgets('a Large document still draws its rendered page', (tester) async {
    // Only the thumbnail path renders a PDF's page 1.
    final doc = testMediaItem(
      id: 'doc',
      siteId: 's1',
      mediaType: MediaType.document,
      originalFilename: 'briefing.pdf',
    ).copyWith(displaySizeOverride: AttachmentDisplaySize.large);
    await pump(tester, [doc]);
    final view = tester.widget<MediaItemView>(find.byType(MediaItemView));
    expect(view.thumbnail, isTrue);
  });
}

/// A learned-shape store whose load waits for [load].
class _PendingShapes implements MediaAspectCacheRepository {
  _PendingShapes(this.load);

  final Future<Map<String, LearnedAspect>> load;

  @override
  Future<Map<String, LearnedAspect>> loadAll() => load;

  @override
  Future<void> putAll(Map<String, LearnedAspect> entries) async {}
}
