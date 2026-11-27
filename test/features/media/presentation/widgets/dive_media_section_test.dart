import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';

import '../../../../helpers/mock_providers.dart' show Override;
import '../support/media_widget_harness.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';
import '../../../../helpers/marine_life_id_off.dart';

void main() {
  turnOffMarineLifeIdForEachTest();

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
    List<MediaItem> media = const [],
    void Function(MediaItem)? onOpenDocument,
    List<Override> overrides = const [],
    RecordEditController<Dive>? lockable,
    bool open = false,
  }) => mediaTestApp(
    overrides: [
      mediaForDiveProvider('dive-1').overrideWith((ref) async => media),
      ...overrides,
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        child: lockable == null
            ? DiveMediaSection(diveId: 'dive-1', onOpenDocument: onOpenDocument)
            : RecordEditScope<Dive>(
                controller: lockable,
                child: DiveMediaSection(
                  diveId: 'dive-1',
                  onOpenDocument: onOpenDocument,
                  editing: open ? lockable.session : null,
                ),
              ),
      ),
    ),
  );

  /// A dive page unlocked, its sitting open (issue #4673: only the open
  /// card adds, scans, selects or unlinks).
  RecordEditController<Dive> unlocked() {
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(Dive(id: 'dive-1', dateTime: DateTime.utc(2026)));
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets('the open card offers an add menu with photos and a '
      'document', (tester) async {
    await tester.pumpWidget(await host(lockable: unlocked(), open: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_photo_alternate));
    await tester.pumpAndSettle();
    expect(find.text('Add photos or videos'), findsOneWidget);
    expect(find.text('Add document'), findsOneWidget);
  });

  testWidgets('a card without a sitting offers no add, scan or select '
      'control (#4673)', (tester) async {
    await tester.pumpWidget(
      await host(
        media: [testMediaItem(id: 'm1', originalFilename: 'reef.png')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnailTile), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate), findsNothing);
    expect(find.byIcon(Icons.image_search), findsNothing);
    expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
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
          media: [
            testMediaItem(id: 'm1', originalFilename: 'reef.png'),
            testMediaItem(id: 'm2', originalFilename: 'wreck.png'),
          ],
          lockable: unlocked(),
          open: true,
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

  testWidgets('a browser shows the media but offers neither adding nor '
      'selecting, even in the open card (#4121)', (tester) async {
    await tester.pumpWidget(
      await host(
        media: [testMediaItem(id: 'm1', originalFilename: 'reef.png')],
        lockable: unlocked(),
        open: true,
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnailTile), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate), findsNothing);
    expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
  });

  group('on a dive page that offers editing (issue #4527)', () {
    MediaItem photo(String id, int minute) => MediaItem(
      id: id,
      diveId: 'dive-1',
      mediaType: MediaType.photo,
      takenAt: DateTime.utc(2026, 1, 1, 10, minute),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    testWidgets('locked: no add, no scan and no selection', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {});
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        await host(media: [photo('s1', 5)], lockable: controller),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_photo_alternate), findsNothing);
      expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
      expect(find.byType(MediaThumbnailTile), findsOneWidget);
    });

    testWidgets("open: the sitting's photos are drawn, an unlinked one "
        'gone', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(Dive(id: 'dive-1', dateTime: DateTime.utc(2026)));
      addTearDown(controller.dispose);
      final session = controller.session!;
      holdSittingMedia(
        session,
        SittingMediaWriters(
          writeRows: (_) async => const [],
          insertNetwork: (_) async => const [],
          unlink: (_) async {},
          replace: (_, _, _) async {},
          drainDeletes: () async {},
          enqueueUpload: (_) {},
        ),
        cardId: 'media',
      );
      addMediaToSitting(session, [
        HeldMediaRow((item: photo('n1', 10), enrichment: null)),
      ]);
      unlinkMediaInSitting(session, {'s1'});

      await tester.pumpWidget(
        await host(
          media: [photo('s1', 5), photo('s2', 20)],
          lockable: controller,
          open: true,
        ),
      );
      await tester.pumpAndSettle();

      final tiles = tester
          .widgetList<MediaThumbnailTile>(find.byType(MediaThumbnailTile))
          .map((t) => t.item.id);
      expect(tiles, ['n1', 's2']);
      expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);

      // Not stored yet: the viewer opens on it all the same, from the
      // sitting's photos (plan 10 Task 13), with the dive's sitting and a
      // lock of its own.
      await tester.tap(find.byType(MediaThumbnailTile).first);
      await tester.pumpAndSettle();
      final viewer = tester.widget<PhotoViewerPage>(
        find.byType(PhotoViewerPage),
      );
      expect(viewer.initialMediaId, 'n1');
      expect(viewer.diveEditing, same(controller));
    });

    testWidgets('open: a read that failed offers Try again, which reads the '
        'media again', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(Dive(id: 'dive-1', dateTime: DateTime.utc(2026)));
      addTearDown(controller.dispose);
      var reads = 0;
      await tester.pumpWidget(
        await mediaTestApp(
          overrides: [
            mediaForDiveProvider('dive-1').overrideWith((ref) async {
              if (reads++ == 0) throw StateError('database closed');
              return [photo('s1', 5)];
            }),
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: DiveMediaSection(
                  diveId: 'dive-1',
                  editing: controller.session,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SittingLoadFailed), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(reads, 2);
      expect(find.byType(MediaThumbnailTile), findsOneWidget);
    });

    testWidgets('a selection made in the open card ends when the card '
        'closes, so no Unlink is left on the read-only card', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(Dive(id: 'dive-1', dateTime: DateTime.utc(2026)));
      addTearDown(controller.dispose);
      Future<Widget> card({required bool open}) => host(
        media: [photo('s1', 5), photo('s2', 20)],
        lockable: controller,
        open: open,
      );

      await tester.pumpWidget(await card(open: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaThumbnailTile).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);

      await tester.pumpWidget(await card(open: false));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selection_exit')), findsNothing);
      expect(find.byIcon(Icons.link_off), findsNothing);
    });
  });
}
