import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/media/data/scratch/scratch_session.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/presentation/pages/identify_viewer_page.dart';

import '../../../../helpers/test_database.dart';
import 'media_viewer_unlock_harness.dart';

/// The Identify viewer over files the diver has not kept (issue #5122).
void main() {
  late AppDatabase db;
  late ScratchSession session;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, {int count = 1}) async {
    session = (await tester.runAsync(
      () => ScratchSession.open(
        source: db,
        items: [
          for (var i = 0; i < count; i++)
            MediaItem(
              id: ScratchSession.newId(),
              mediaType: MediaType.photo,
              sourceType: MediaSourceType.localFile,
              localPath: '/nowhere/GX01024$i.JPG',
              originalFilename: 'GX01024$i.JPG',
              takenAt: DateTime.utc(2026, 11, 1),
              createdAt: DateTime.utc(2026, 11, 1),
              updatedAt: DateTime.utc(2026, 11, 1),
            ),
        ],
      ),
    ))!;
    await pumpViewerApp(tester, IdentifyViewerPage(session: session));
    await settleViewer(tester);
  }

  testWidgets('says the file is not kept and offers Keep', (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('media_identify_banner')), findsOneWidget);
    expect(
      find.text('Not in your library. Nothing is kept unless you keep it.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('media_identify_keep')), findsOneWidget);
  });

  testWidgets('shows no dive, site or edit actions', (tester) async {
    await pump(tester);

    // Species is the file's to name; the rest belongs to a kept photo.
    expect(find.byTooltip('Species'), findsOneWidget);
    expect(find.byTooltip('Tag people'), findsNothing);
    expect(find.byTooltip('Adjust color'), findsNothing);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
  });

  testWidgets('Keep asks where, and this file or all with more than one', (
    tester,
  ) async {
    await pump(tester, count: 2);

    await tester.tap(find.byKey(const ValueKey('media_identify_keep')));
    await settleViewer(tester);

    expect(find.text('Keep in your library'), findsOneWidget);
    expect(find.text('Put on a dive'), findsOneWidget);
    expect(find.text('Put on a site'), findsOneWidget);
    expect(find.text('Keep without a place'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('media_identify_keep_scope')),
      findsOneWidget,
    );
  });

  testWidgets('one file asks no this-or-all question', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('media_identify_keep')));
    await settleViewer(tester);

    expect(
      find.byKey(const ValueKey('media_identify_keep_scope')),
      findsNothing,
    );
  });

  test('a picked file becomes a scratch item with its own date and place', () {
    final modified = DateTime.utc(2026, 1, 2);
    final video = scratchItemFromFile(
      '/clips/GX010245.MP4',
      MediaSourceMetadata(
        mimeType: 'video/mp4',
        takenAt: DateTime.utc(2025, 7, 4),
        latitude: 20.5,
        longitude: -87.25,
      ),
      modified: modified,
    );
    final undated = scratchItemFromFile(
      '/clips/photo.jpg',
      const MediaSourceMetadata(mimeType: 'image/jpeg'),
      modified: modified,
    );

    expect(ScratchSession.isScratchId(video.id), isTrue);
    expect(video.mediaType, MediaType.video);
    expect(video.takenAt, DateTime.utc(2025, 7, 4));
    expect(video.latitude, 20.5);
    expect(video.originalFilename, 'GX010245.MP4');
    expect(undated.mediaType, MediaType.photo);
    expect(undated.takenAt, modified);
  });
}
