import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_aspect_cache_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_hover_region.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../support/dive_media_sitting.dart';
import '../support/media_widget_harness.dart';

MediaItem _photo(String id, int width, int height) => MediaItem(
  id: id,
  diveId: 'dive-1',
  originalFilename: '$id.jpg',
  mediaType: MediaType.photo,
  width: width,
  height: height,
  takenAt: DateTime(2026, 3, 15),
  createdAt: DateTime(2026, 3, 15),
  updatedAt: DateTime(2026, 3, 15),
);

MediaItem _document(String id) => MediaItem(
  id: id,
  diveId: 'dive-1',
  originalFilename: '$id.pdf',
  mediaType: MediaType.document,
  takenAt: DateTime(2026, 3, 15),
  createdAt: DateTime(2026, 3, 15),
  updatedAt: DateTime(2026, 3, 15),
);

/// The dive's stored media, changeable mid-test the way a first link is.
final _storedMedia = StateProvider<List<MediaItem>>((ref) => const []);

void main() {
  Future<void> pumpSection(
    WidgetTester tester,
    List<MediaItem> media, {
    MediaAspectCacheRepository? cache,
    EditSession<Dive>? editing,
    void Function(MediaItem)? onOpenDocument,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          _storedMedia.overrideWith((ref) => media),
          mediaForDiveProvider(
            'dive-1',
          ).overrideWith((ref) => ref.watch(_storedMedia)),
          mediaAspectCacheRepositoryProvider.overrideWithValue(
            cache ?? FakeAspectCacheRepository(),
          ),
        ],
        child: Directionality(
          textDirection: textDirection,
          child: SingleChildScrollView(
            // Rebuilt on every change to the sitting, as the card's editor
            // rebuilds it (DiveMediaCardEditor).
            child: ListenableBuilder(
              listenable: editing ?? const AlwaysStoppedAnimation(0),
              builder: (context, _) => DiveMediaSection(
                diveId: 'dive-1',
                editing: editing,
                onOpenDocument: onOpenDocument,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tiles() => find.descendant(
    of: find.byType(DragSelectGridView<MediaItem>),
    matching: find.byType(MediaHoverRegion),
  );

  List<Rect> tileRects(WidgetTester tester) => [
    for (var i = 0; i < tiles().evaluate().length; i++)
      tester.getRect(tiles().at(i)),
  ];

  /// The tiles sharing [member]'s row, in list order.
  List<Rect> rowOf(List<Rect> rects, Rect member) =>
      rects.where((r) => r.top == member.top).toList();

  Rect gridRect(WidgetTester tester) =>
      tester.getRect(find.byType(DragSelectGridView<MediaItem>));

  group('DiveMediaSection justified rows', () {
    testWidgets('lays each item out at its own shape', (tester) async {
      await pumpSection(tester, [
        _photo('wide', 600, 400),
        _photo('tall', 400, 600),
        _document('doc'),
      ]);

      final rects = tileRects(tester);
      expect(rects, hasLength(3));
      // Too few to fill the card: one open row at the target height.
      for (final rect in rects) {
        expect(rect.top, rects.first.top);
        expect(rect.height, closeTo(kDiveMediaRowHeight, 0.01));
      }
      expect(rects[0].width / rects[0].height, closeTo(1.5, 0.01));
      expect(rects[1].width / rects[1].height, closeTo(2 / 3, 0.01));
      // A document keeps the page shape, whatever it stores.
      expect(rects[2].width / rects[2].height, closeTo(0.75, 0.01));
    });

    testWidgets('a full row ends flush with the card, tiles 4 px apart', (
      tester,
    ) async {
      await pumpSection(tester, [
        for (var i = 0; i < 12; i++) _photo('p$i', 600, 400),
      ]);

      final rects = tileRects(tester);
      final grid = gridRect(tester);
      final firstRow = rowOf(rects, rects.first);
      expect(firstRow.length, greaterThan(1));
      expect(firstRow.first.left, closeTo(grid.left, 0.5));
      expect(firstRow.last.right, closeTo(grid.right, 0.5));
      for (var k = 1; k < firstRow.length; k++) {
        expect(
          firstRow[k].left - firstRow[k - 1].right,
          closeTo(kDiveMediaGap, 0.01),
        );
      }
      // The next row starts one gap below.
      final second = rects.firstWhere((r) => r.top > rects.first.top);
      expect(second.top - firstRow.first.bottom, closeTo(kDiveMediaGap, 0.01));
    });

    testWidgets('right to left, rows start at the card\'s right edge', (
      tester,
    ) async {
      await pumpSection(tester, [
        for (var i = 0; i < 12; i++) _photo('p$i', 600, 400),
      ], textDirection: TextDirection.rtl);

      final rects = tileRects(tester);
      final grid = gridRect(tester);
      final firstRow = rowOf(rects, rects.first);
      // The first item sits at the right edge and the row runs leftward,
      // ending flush with the left edge, gaps as in left to right.
      expect(firstRow.first.right, closeTo(grid.right, 0.5));
      expect(firstRow.last.left, closeTo(grid.left, 0.5));
      for (var k = 1; k < firstRow.length; k++) {
        expect(
          firstRow[k - 1].left - firstRow[k].right,
          closeTo(kDiveMediaGap, 0.01),
        );
      }
      // The open last row keeps its items' widths and starts at the right.
      final lastRow = rowOf(rects, rects.last);
      expect(lastRow.first.right, closeTo(grid.right, 0.5));
    });

    testWidgets('the last row keeps the 120 px target height', (tester) async {
      await pumpSection(tester, [
        for (var i = 0; i < 12; i++) _photo('p$i', 600, 400),
      ]);

      expect(tileRects(tester).last.height, closeTo(120, 0.01));
    });

    testWidgets('a learned shape overrides the stored size', (tester) async {
      await pumpSection(
        tester,
        [_photo('sideways', 600, 400)],
        cache: FakeAspectCacheRepository({
          'sideways': (ratio: 0.75, width: 600, height: 400),
        }),
      );

      final rect = tileRects(tester).single;
      expect(rect.width / rect.height, closeTo(0.75, 0.01));
    });

    testWidgets('a tile\'s decoded shape relays the card out', (tester) async {
      await pumpSection(tester, [_photo('sideways', 600, 400)]);
      final before = tileRects(tester).single;
      expect(before.width / before.height, closeTo(1.5, 0.01));

      // The thumbnail decodes upright: the tile reports it, and the card
      // learns the shape the photo is shown at.
      tester
          .widget<MediaThumbnailTile>(find.byType(MediaThumbnailTile))
          .onImageSize!(const Size(400, 600));
      await tester.pumpAndSettle();

      final after = tileRects(tester).single;
      expect(after.width / after.height, closeTo(2 / 3, 0.01));
    });

    testWidgets('a dive with no media does not read the learned shapes', (
      tester,
    ) async {
      final cache = FakeAspectCacheRepository();
      await pumpSection(tester, const [], cache: cache);

      expect(tiles(), findsNothing);
      expect(cache.loads, 0);
    });

    testWidgets(
      'a dive gaining its first media reads the shapes and lays out',
      (tester) async {
        final cache = FakeAspectCacheRepository();
        await pumpSection(tester, const [], cache: cache);
        expect(cache.loads, 0);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DiveMediaSection)),
        );
        container.read(_storedMedia.notifier).state = [_photo('a', 600, 400)];
        await tester.pumpAndSettle();

        expect(cache.loads, 1);
        final rect = tileRects(tester).single;
        expect(rect.width / rect.height, closeTo(1.5, 0.01));
      },
    );

    testWidgets(
      'a first photo held in the sitting reads the shapes and lays out',
      (tester) async {
        final cache = FakeAspectCacheRepository();
        final editing = openDiveMediaSitting();
        await pumpSection(tester, const [], cache: cache, editing: editing);
        expect(cache.loads, 0);

        addMediaToSitting(editing, [
          HeldMediaRow((item: _photo('held', 400, 600), enrichment: null)),
        ]);
        await tester.pumpAndSettle();

        expect(cache.loads, 1);
        final rect = tileRects(tester).single;
        expect(rect.width / rect.height, closeTo(2 / 3, 0.01));
      },
    );

    testWidgets('lays out when the learned shapes cannot be read', (
      tester,
    ) async {
      await pumpSection(tester, [
        _photo('a', 600, 400),
        _photo('b', 400, 600),
      ], cache: FakeAspectCacheRepository.failing());

      expect(tiles(), findsNWidgets(2));
      final rects = tileRects(tester);
      expect(rects[0].width / rects[0].height, closeTo(1.5, 0.01));
    });

    testWidgets('drag-select runs across a row break in list order', (
      tester,
    ) async {
      await pumpSection(tester, [
        for (var i = 0; i < 12; i++) _photo('p$i', 600, 400),
      ], editing: openDiveMediaSitting());
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      final rects = tileRects(tester);
      final perRow = rowOf(rects, rects.first).length;
      // From the second tile of the first row to the second of the next.
      final gesture = await tester.startGesture(rects[1].center);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(rects[perRow + 1].center);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final checked = [
        for (final tile in tester.widgetList<MediaThumbnailTile>(
          find.byType(MediaThumbnailTile),
        ))
          if (tile.isSelected) tile.item.id,
      ];
      expect(checked, [for (var i = 1; i <= perRow + 1; i++) 'p$i']);
    });

    testWidgets('a document held until Save does not open; a stored one does', (
      tester,
    ) async {
      final editing = openDiveMediaSitting();
      addMediaToSitting(editing, [
        HeldMediaRow((item: _document('held'), enrichment: null)),
      ]);
      final opened = <String>[];
      await pumpSection(
        tester,
        [_document('stored')],
        editing: editing,
        onOpenDocument: (item) => opened.add(item.id),
      );
      final ids = [
        for (final tile in tester.widgetList<MediaThumbnailTile>(
          find.byType(MediaThumbnailTile),
        ))
          tile.item.id,
      ];

      // The held document has no file to open yet.
      await tester.tap(tiles().at(ids.indexOf('held')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);

      await tester.tap(tiles().at(ids.indexOf('stored')));
      await tester.pumpAndSettle();
      expect(opened, ['stored']);
    });

    testWidgets('repacks when the card width changes', (tester) async {
      final media = [for (var i = 0; i < 12; i++) _photo('p$i', 600, 400)];
      await pumpSection(tester, media);
      int firstRowCount() {
        final rects = tileRects(tester);
        return rowOf(rects, rects.first).length;
      }

      final wide = firstRowCount();
      tester.view.physicalSize = const Size(500, 900);
      await tester.pumpAndSettle();

      expect(firstRowCount(), lessThan(wide));
      final rects = tileRects(tester);
      final firstRow = rowOf(rects, rects.first);
      expect(firstRow.last.right, closeTo(gridRect(tester).right, 0.5));
    });
  });
}
