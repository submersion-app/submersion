import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';

import '../support/media_widget_harness.dart';

void main() {
  test('showInOsFileManagerLabel returns OS-appropriate label', () {
    final label = showInOsFileManagerLabel();
    if (Platform.isMacOS) {
      expect(label, 'Show in Finder');
    } else if (Platform.isWindows) {
      expect(label, 'Show in Explorer');
    } else {
      // Linux / iOS / Android fallback.
      expect(label, 'Show in Files');
    }
  });

  // The shared harness supplies the base overrides, a resolver registry that
  // serves decodable bytes without touching the filesystem, and the pinned
  // 'en' locale the English assertions below depend on.
  Future<Widget> host({
    VoidCallback? onAdd,
    VoidCallback? onAddDocument,
    List<MediaItem> media = const [],
    void Function(MediaItem)? onOpenDocument,
  }) => mediaTestApp(
    overrides: [
      mediaForDiveProvider('dive-1').overrideWith((ref) async => media),
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        child: DiveMediaSection(
          diveId: 'dive-1',
          onAddPressed: onAdd,
          onAddDocumentPressed: onAddDocument,
          onOpenDocument: onOpenDocument,
        ),
      ),
    ),
  );

  testWidgets('add menu shows document action when callback provided', (
    tester,
  ) async {
    var photos = 0;
    var docs = 0;
    await tester.pumpWidget(
      await host(onAdd: () => photos++, onAddDocument: () => docs++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_photo_alternate));
    await tester.pumpAndSettle();
    expect(find.text('Add photos or videos'), findsOneWidget);
    await tester.tap(find.text('Add document'));
    await tester.pumpAndSettle();
    expect(docs, 1);
    expect(photos, 0);
  });

  testWidgets('plain add button preserved when no document callback', (
    tester,
  ) async {
    var photos = 0;
    await tester.pumpWidget(await host(onAdd: () => photos++));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_photo_alternate));
    await tester.pumpAndSettle();
    expect(photos, 1); // fired directly, no menu
    expect(find.text('Add document'), findsNothing);
  });

  testWidgets('empty state message replaces the grid when the dive has no '
      'media', (tester) async {
    await tester.pumpWidget(await host());
    await tester.pumpAndSettle();
    expect(find.text('No photos yet'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNothing);
  });

  testWidgets('renders one tile per media item once the dive has media', (
    tester,
  ) async {
    await tester.pumpWidget(
      await host(
        media: [
          testMediaItem(id: 'm1', originalFilename: 'reef.png'),
          testMediaItem(id: 'm2', originalFilename: 'wreck.png'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.text('No photos yet'), findsNothing);
  });

  testWidgets('tapping a document tile opens the document and never the '
      'photo viewer', (tester) async {
    final opened = <MediaItem>[];
    await tester.pumpWidget(
      await host(
        media: [
          testMediaItem(
            id: 'doc-1',
            mediaType: MediaType.document,
            originalFilename: 'dive-plan.pdf',
          ),
        ],
        onOpenDocument: opened.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MediaThumbnailTile));
    await tester.pumpAndSettle();

    expect(opened.map((m) => m.id), ['doc-1']);
    expect(find.byType(PhotoViewerPage), findsNothing);
  });

  group('selection mode', () {
    Future<void> pumpWithTwo(WidgetTester tester) async {
      await tester.pumpWidget(
        await host(
          onAdd: () {},
          media: [
            testMediaItem(id: 'm1', originalFilename: 'reef.png'),
            testMediaItem(id: 'm2', originalFilename: 'wreck.png'),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('long-pressing a tile swaps in the selection header', (
      tester,
    ) async {
      await pumpWithTwo(tester);
      expect(find.text('Photos & Video'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaThumbnailTile).first);
      await tester.pumpAndSettle();

      // Both media sections render the shared SelectionAppBar; the old
      // MediaSelectionHeader has been removed.
      expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
      // The normal header and its add affordance yield to selection.
      expect(find.text('Photos & Video'), findsNothing);
      expect(find.byIcon(Icons.add_photo_alternate), findsNothing);
    });

    testWidgets('select all covers every tile, then cancel restores the '
        'normal header', (tester) async {
      await pumpWithTwo(tester);
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaThumbnailTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      // Nothing left to select, so the control disables rather than
      // disappearing -- the shared bar keeps a stable action set.
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('selection_select_all')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('selection_exit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selection_exit')), findsNothing);
      expect(find.text('Photos & Video'), findsOneWidget);
    });
  });

  testWidgets('tapping a photo tile pushes the photo viewer and leaves '
      'onOpenDocument untouched', (tester) async {
    final opened = <MediaItem>[];
    await tester.pumpWidget(
      await host(
        media: [testMediaItem(id: 'm1', originalFilename: 'reef.png')],
        onOpenDocument: opened.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MediaThumbnailTile));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.byType(PhotoViewerPage), findsOneWidget);
  });
}
