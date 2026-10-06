import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/pdf_page_renderer.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';

import '../support/media_widget_harness.dart';

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

  testWidgets('a PDF shows its first page and page count', (tester) async {
    await pump(
      tester,
      testMediaItem(mediaType: MediaType.document, originalFilename: 'map.pdf'),
      preview: PdfPagePreview(jpeg: onePixelPng(), pageCount: 4),
    );
    expect(find.text('4 pages'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
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
