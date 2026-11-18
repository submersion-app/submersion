import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';
import 'video_viewer_test_harness.dart';

/// What the viewer tells the diver when a sitting cannot go on (issue
/// #4527): its photo or video deleted, or moved to another dive.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
  });
  tearDown(tearDownTestDatabase);

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(RecordEditBar),
        matching: find.text('Save'),
      ),
    );
    await settleViewer(tester);
  }

  testWidgets('a photo moved to another dive: Save says so, and how to go '
      'on', (tester) async {
    await pumpViewer(tester);
    await tapUnlock(tester);
    photoController(tester).session!.set(photoPinField, 120);
    await settleViewer(tester);

    await tester.runAsync(() async {
      await insertTestDive(
        id: 'd2',
        at: DateTime(2024, 1, 11, 9),
        diverId: 'me',
      );
      await (db.update(db.media)..where((m) => m.id.equals('p2'))).write(
        const MediaCompanion(diveId: Value('d2')),
      );
    });
    await settleViewer(tester);
    await tapSave(tester);

    expect(
      find.text(
        'Moved to another dive since you unlocked it. '
        'Cancel, then unlock it again.',
      ),
      findsOneWidget,
    );
    expect(photoController(tester).isDirty, isTrue);
  });

  testWidgets('the photo deleted with its species sheet open: the sheet '
      'closes with the sitting', (tester) async {
    await pumpViewer(tester);
    await tapUnlock(tester);
    await tester.tap(find.byKey(const ValueKey('viewer_species')));
    await settleViewer(tester);
    expect(find.byType(MediaSpeciesSheet), findsOneWidget);

    await tester.runAsync(() => MediaRepository().deleteMedia('p2'));
    await settleViewer(tester, rounds: 10);

    expect(find.byType(MediaSpeciesSheet), findsNothing);
    expect(
      find.text('This photo was removed. Your changes were not saved.'),
      findsOneWidget,
    );
  });

  testWidgets('the photo deleted while a page is open over the viewer: the '
      'page stays', (tester) async {
    await pumpViewer(tester);
    await tapUnlock(tester);
    final viewer = tester.element(find.byType(MediaSpeciesChipsRow));
    unawaited(
      Navigator.of(viewer).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('A species page')),
        ),
      ),
    );
    await settleViewer(tester);

    await tester.runAsync(() => MediaRepository().deleteMedia('p2'));
    await settleViewer(tester, rounds: 10);

    expect(find.text('A species page'), findsOneWidget);
  });

  testWidgets('a video deleted in its sitting: the message names a video', (
    tester,
  ) async {
    await tester.runAsync(
      () => insertTestMedia(
        id: 'v1',
        diveId: 'd1',
        takenAt: DateTime(2024, 1, 10, 9, 3),
        fileType: 'video',
      ),
    );
    final platform = FakeVideoPlatform();
    useVideoPlatform(platform);
    final items = await tester.runAsync(() => storedMedia(['p1', 'v1']));
    await pumpViewerApp(
      tester,
      MediaViewerPage(mediaList: items!, initialMediaId: 'v1'),
      overrides: [
        resolvedFilePathProvider.overrideWith(
          (ref, MediaItem arg) async => tempVideoPath('v1'),
        ),
      ],
    );
    await tester.runAsync(() async {
      platform.completeInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleViewer(tester);
    await tapUnlock(tester);

    await tester.runAsync(() => MediaRepository().deleteMedia('v1'));
    await settleViewer(tester, rounds: 10);

    expect(
      find.text('This video was removed. Your changes were not saved.'),
      findsOneWidget,
    );
    expect(find.byType(RecordEditBar), findsNothing);
  });
}
