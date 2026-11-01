import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';

import '../../../../helpers/contrast_ratio.dart';
import '../support/media_widget_harness.dart';

/// A solid-colour JPEG at [width]x[height], so a widget test can pump a
/// real decodable page render with a known aspect ratio instead of the
/// degenerate 1x1 fixture.
Uint8List solidJpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 200, 200));
  return img.encodeJpg(image);
}

/// Issue #1039: a site attachment shown at full card width.
void main() {
  Future<void> pump(
    WidgetTester tester,
    MediaItem item, {
    PdfPagePreview? preview,
    bool selectionMode = false,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onEdit,
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          pdfLargePreviewProvider.overrideWith((ref, req) async => preview),
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: SiteAttachmentLargeCard(
              item: item,
              isSelectionMode: selectionMode,
              isSelected: selected,
              onTap: onTap ?? () {},
              onEditDetails: onEdit,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The play icon was a bare white glyph. A video with no poster frame
  // shows the light surfaceContainerHighest placeholder, where it vanished.
  testWidgets('the video play icon carries its own dark backing', (
    tester,
  ) async {
    await pump(tester, testMediaItem(mediaType: MediaType.video));

    final play = find.byIcon(Icons.play_arrow);
    final color = tester.widget<Icon>(play).color!;
    final backing = find.descendant(
      of: find.ancestor(of: play, matching: find.byType(Center)).first,
      matching: find.ancestor(of: play, matching: find.byType(DecoratedBox)),
    );
    expect(backing, findsOneWidget);
    final scrim =
        (tester.widget<DecoratedBox>(backing).decoration as BoxDecoration)
            .color!;
    // Held on the worst case: a white poster or placeholder under the scrim.
    expect(
      contrastRatio(color, Color.alphaBlend(scrim, Colors.white)),
      greaterThanOrEqualTo(3.0),
    );
  });

  group('largeCardAspectRatio', () {
    test('uses the stored dimensions', () {
      expect(
        largeCardAspectRatio(
          testMediaItem().copyWith(width: 1600, height: 900),
        ),
        closeTo(16 / 9, 1e-9),
      );
    });

    test('falls back to 4:3 for unknown or zero dimensions', () {
      expect(largeCardAspectRatio(testMediaItem()), 4 / 3);
      expect(
        largeCardAspectRatio(testMediaItem().copyWith(width: 0, height: 900)),
        4 / 3,
      );
      expect(
        largeCardAspectRatio(testMediaItem().copyWith(width: 1600, height: 0)),
        4 / 3,
      );
    });
  });

  testWidgets('an image renders full width at its aspect ratio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      testMediaItem(
        originalFilename: 'entry.png',
      ).copyWith(width: 1600, height: 800),
    );
    final view = tester.getSize(find.byType(MediaItemView));
    expect(view.width / view.height, closeTo(2, 0.01));
    expect(find.text('entry.png'), findsOneWidget);
  });

  testWidgets('a tall portrait stops at 70% of the screen height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      testMediaItem(
        originalFilename: 'pinnacle.png',
      ).copyWith(width: 900, height: 3000),
    );
    expect(
      tester.getSize(find.byType(MediaItemView)).height,
      lessThanOrEqualTo(560.5),
    );
  });

  testWidgets('an image with no dimensions still has a 4:3 body', (
    tester,
  ) async {
    // Tall enough that the 70% height cap does not apply.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, testMediaItem(originalFilename: 'entry.png'));
    final view = tester.getSize(find.byType(MediaItemView));
    expect(view.height, greaterThan(0));
    expect(view.width / view.height, closeTo(4 / 3, 0.01));
  });

  /// The nearest Stack above the decoded page, which is the page's own box.
  final pageBox = find
      .ancestor(of: find.byType(RawImage), matching: find.byType(Stack))
      .first;

  /// Waits, in real time, for [settled] after a pump. Image.memory's decode
  /// runs on the engine's threads and hands back through fake-async
  /// microtasks, so it needs both.
  Future<void> pumpUntil(WidgetTester tester, bool Function() settled) async {
    for (var i = 0; i < 500 && !settled(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(settled(), isTrue, reason: 'the image never finished decoding');
  }

  /// Pumps a PDF preview of [jpeg] in a 400x900 window, past its real decode,
  /// and returns where the page landed.
  Future<Rect> pumpDecodedPage(
    WidgetTester tester,
    Uint8List jpeg, {
    int pageCount = 1,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'map.pdf'),
      preview: PdfPagePreview(jpeg: jpeg, pageCount: pageCount),
    );
    await pumpUntil(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
    return tester.getRect(pageBox);
  }

  testWidgets('a PDF shows its first page and page count', (tester) async {
    await pumpDecodedPage(tester, onePixelPng(), pageCount: 4);
    expect(find.text('4 pages'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('issue #3996: a landscape PDF preview keeps its own aspect '
      'ratio, not the portrait 70% height cap', (tester) async {
    final page = await pumpDecodedPage(tester, solidJpeg(2000, 1000));

    // The surrounding box, not just the Image: the bug left the Image
    // correctly sized but centered in a container stretched to the 70%
    // height cap (630 px here), leaving empty space above and below.
    expect(page.width / page.height, closeTo(2, 0.05));
    expect(page.height, lessThan(300));
  });

  testWidgets('issue #3996: an extreme portrait PDF that hits the height '
      'cap narrows and stays centered in the card', (tester) async {
    // 1:3, tall enough that the width-first clamp alone would still exceed
    // the 630 px height cap (70% of 900), forcing a second clamp that narrows
    // the page below the card's own width.
    final page = await pumpDecodedPage(tester, solidJpeg(600, 1800));

    final card = tester.getRect(find.byType(SiteAttachmentLargeCard));
    expect(page.height, closeTo(630, 1));
    expect(page.width, lessThan(card.width - 50));
    expect(page.width / page.height, closeTo(1 / 3, 0.05));
    expect(page.center.dx, closeTo(card.center.dx, 1));
  });

  testWidgets('the page-count chip is not clipped to a strip-shaped page', (
    tester,
  ) async {
    final page = await pumpDecodedPage(
      tester,
      solidJpeg(60, 1800),
      pageCount: 12,
    );

    expect(tester.getSize(find.byType(Chip)).width, greaterThan(page.width));
    expect(tester.widget<Stack>(pageBox).clipBehavior, Clip.none);
  });

  testWidgets('the card holds its loading height until the page decodes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'map.pdf'),
      preview: PdfPagePreview(jpeg: solidJpeg(2000, 1000), pageCount: 1),
    );

    // No real time has passed, so the decode has not finished.
    expect(find.byType(RawImage), findsNothing);
    expect(find.byType(Chip), findsNothing);
    final body = tester.getSize(find.byType(Image));
    expect(body.height, closeTo(body.width * 0.6, 1));
  });

  testWidgets('a page that cannot decode leaves only the document row', (
    tester,
  ) async {
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'map.pdf'),
      preview: PdfPagePreview(jpeg: Uint8List(8), pageCount: 1),
    );

    await pumpUntil(
      tester,
      () => tester.getSize(find.byType(Image)).height == 0,
    );
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('the PDF page decodes at the card width, not the bucket', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'map.pdf'),
      preview: PdfPagePreview(jpeg: onePixelPng(), pageCount: 1),
    );
    final provider = tester.widget<Image>(find.byType(Image)).image;
    expect(provider, isA<ResizeImage>());
    final cardWidth = tester
        .getSize(find.byType(SiteAttachmentLargeCard))
        .width;
    // The body sits inside the card's 1 px outline on each side.
    expect((provider as ResizeImage).width, closeTo(cardWidth, 2));
  });

  testWidgets('a PDF that cannot render falls back to the document row', (
    tester,
  ) async {
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'map.pdf'),
    );
    expect(find.text('map.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a non-PDF document is a full-width row with its extension', (
    tester,
  ) async {
    await pump(
      tester,
      testMediaItem(
        mediaType: MediaType.document,
        originalFilename: 'route.gpx',
      ),
    );
    expect(find.text('route.gpx'), findsOneWidget);
    expect(find.text('GPX'), findsOneWidget);
    expect(find.byType(MediaItemView), findsNothing);
  });

  testWidgets('a long name ellipsizes at phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      testMediaItem(
        mediaType: MediaType.document,
        originalFilename: '${'very long site map name ' * 8}.gpx',
      ),
      onEdit: () {},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap calls onTap; the menu offers Edit details', (tester) async {
    var taps = 0;
    var edits = 0;
    await pump(
      tester,
      testMediaItem(originalFilename: 'entry.png'),
      onTap: () => taps++,
      onEdit: () => edits++,
    );
    await tester.tap(find.byType(MediaItemView));
    expect(taps, 1);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(edits, 1);
  });

  testWidgets('in selection mode a checkbox replaces the menu', (tester) async {
    var taps = 0;
    await pump(
      tester,
      testMediaItem(originalFilename: 'entry.png'),
      selectionMode: true,
      selected: true,
      onTap: () => taps++,
      onEdit: () {},
    );
    expect(find.byTooltip('More options'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.tap(find.byType(Checkbox));
    expect(taps, 1);
  });
}
