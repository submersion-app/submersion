import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_unlink.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/marine_life_id_off.dart';
import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';

/// Saving the media viewer's held Unlink (issue #5126).
void main() {
  turnOffMarineLifeIdForEachTest();

  late AppDatabase db;
  late RowDeletingCoordinator coordinator;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
    // A photo on the dive that the site also uses.
    await insertTestMedia(
      id: 'ps',
      diveId: 'd1',
      siteId: 's1',
      takenAt: DateTime(2024, 1, 10, 9, 2),
    );
    coordinator = RowDeletingCoordinator();
  });

  tearDown(tearDownTestDatabase);

  /// The viewer on [ids] at [initial], unlocked.
  Future<void> openUnlocked(
    WidgetTester tester, {
    List<String> ids = const ['p1', 'p2', 'p3'],
    String initial = 'p2',
  }) async {
    final items = await tester.runAsync(() => storedMedia(ids));
    await pumpViewerApp(
      tester,
      MediaViewerPage(mediaList: items!, initialMediaId: initial),
      overrides: [
        mediaDeletionCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    await tapUnlock(tester);
  }

  /// Holds the unlink for [scope], as confirming the action does.
  Future<void> hold(WidgetTester tester, ViewerUnlinkScope scope) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MediaViewerToolbar)),
    );
    holdViewerUnlink(
      photoController(tester).session!,
      viewerUnlinkWriters(scope, container.read),
    );
    await settleViewer(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await settleViewer(tester, rounds: 10);
  }

  Future<List<String?>> labels(WidgetTester tester) async {
    await tester.runAsync(() => ChangeLogRepository().settleAll());
    final rows = (await tester.runAsync(
      () => db
          .customSelect(
            'SELECT label FROM change_log_operations WHERE label IS NOT NULL',
          )
          .get(),
    ))!;
    return [for (final r in rows) r.read<String?>('label')];
  }

  testWidgets('dive scope deletes a dive-only photo on Save, as one entry', (
    tester,
  ) async {
    await openUnlocked(tester);
    await hold(tester, ViewerUnlinkScope.dive);

    expect(
      await tester.runAsync(() => MediaRepository().getMediaById('p2')),
      isNotNull,
      reason: 'held until Save',
    );
    await save(tester);

    expect(coordinator.deleted, ['p2']);
    expect(
      await tester.runAsync(() => MediaRepository().getMediaById('p2')),
      isNull,
    );
    expect(coordinator.drains, 1, reason: 'the held remote delete is let go');
    expect(await labels(tester), ['record_edit:media:unlink']);
  });

  testWidgets('dive scope keeps a site-linked row with its dive link cleared', (
    tester,
  ) async {
    await openUnlocked(tester, ids: ['p1', 'ps'], initial: 'ps');
    await hold(tester, ViewerUnlinkScope.dive);
    await save(tester);

    expect(coordinator.deleted, isEmpty, reason: 'the site still uses it');
    final kept = (await tester.runAsync(
      () => MediaRepository().getMediaById('ps'),
    ))!;
    expect(kept.diveId, isNull);
    expect(kept.siteId, 's1');
  });

  testWidgets('held edits are written with the unlink', (tester) async {
    await openUnlocked(tester, ids: ['p1', 'ps'], initial: 'ps');
    photoController(tester).session!.set(photoPinField, 42);
    await hold(tester, ViewerUnlinkScope.dive);
    await save(tester);

    final kept = (await tester.runAsync(
      () => MediaRepository().getMediaById('ps'),
    ))!;
    expect(kept.manualElapsedSeconds, 42);
    expect(kept.diveId, isNull);
  });

  testWidgets('a moved photo refuses the unlink and writes nothing', (
    tester,
  ) async {
    await openUnlocked(tester);
    await hold(tester, ViewerUnlinkScope.dive);
    await tester.runAsync(() async {
      await insertTestDive(
        id: 'd2',
        at: DateTime(2024, 1, 11, 9),
        siteId: 's1',
        diverId: 'me',
      );
      await db.customStatement(
        "UPDATE media SET dive_id = 'd2' WHERE id = 'p2'",
      );
    });
    await settleViewer(tester);
    final mark = (await tester.runAsync(() => eventCount(db)))!;

    await save(tester);

    expect(
      find.text(AppLocalizationsEn().media_viewer_movedWhileEditing),
      findsOneWidget,
    );
    expect(coordinator.deleted, isEmpty);
    expect(
      await tester.runAsync(() => MediaRepository().getMediaById('p2')),
      isNotNull,
    );
    expect(await tester.runAsync(() => eventCount(db)), mark);
    expect(
      viewerUnlinkHeld(photoController(tester).session),
      isTrue,
      reason: 'the unlink stays held',
    );
  });

  test('the History entry names Unlink', () async {
    final AppLocalizations l = AppLocalizationsEn();
    expect(
      changeLogStoredLabel(l, 'record_edit:media:unlink'),
      contains(l.media_editCard_unlink),
    );
    expect(
      changeLogStoredLabel(l, 'record_edit:media:unlink'),
      isNot(contains('unlink')),
    );
  });
}
