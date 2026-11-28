import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/pages/site_media_viewer_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';

/// The site media viewer gets the photo's lock too (issue #4527): Adjust
/// color and Edit details are held until Save.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await insertTestSite('s1', 'Blue Hole');
    for (final id in ['a1', 'a2']) {
      await insertTestMedia(
        id: id,
        siteId: 's1',
        takenAt: DateTime(2024, 1, 10, 9),
      );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpSite(WidgetTester tester) => pumpViewerApp(
    tester,
    const SiteMediaViewerPage(
      siteId: 's1',
      initialMediaId: 'a1',
      scope: SiteViewerScope.attachments,
    ),
  );

  RecordEditController<PhotoRecord> controller(WidgetTester tester) =>
      RecordEditScope.maybeOf<PhotoRecord>(
        tester.element(find.byType(MediaItemView).first),
      )!;

  Future<MediaItem> stored(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => MediaRepository().getMediaById(id)))!;

  testWidgets('locked: no Adjust color or Edit details; tapping the controls '
      'writes nothing', (tester) async {
    await pumpSite(tester);
    final mark = (await tester.runAsync(() => eventCount(db)))!;

    expect(find.byTooltip('Adjust color'), findsNothing);
    expect(find.byTooltip('Edit details'), findsNothing);
    expect(find.byKey(const ValueKey('viewer_unlock')), findsOneWidget);
    await tester.tap(find.byTooltip('Next media'));
    await settleViewer(tester);

    expect((await tester.runAsync(() => eventCount(db)))!, mark);
  });

  testWidgets('unlocked: a colour and new details are held; Save writes both '
      'in one entry', (tester) async {
    await pumpSite(tester);
    await tapUnlock(tester);
    expect(find.byType(RecordEditBar), findsOneWidget);

    await tester.tap(find.byTooltip('Edit details'));
    await settleViewer(tester);
    await tester.tap(find.text('Uncategorized'));
    await settleViewer(tester);
    await tester.tap(find.text('Site map').last);
    await settleViewer(tester);
    await tester.tap(find.text('Done'));
    await settleViewer(tester);
    controller(
      tester,
    ).session!.set(photoColorField, const ColorAdjustment(warmth: 0.3));
    await settleViewer(tester);
    expect((await stored(tester, 'a1')).siteCategory, isNull);

    await tester.tap(find.text('Save'));
    await settleViewer(tester, rounds: 10);

    final after = await stored(tester, 'a1');
    expect(after.siteCategory, SiteAttachmentCategory.siteMap);
    expect(after.colorAdjustment, const ColorAdjustment(warmth: 0.3));
    await tester.runAsync(() => ChangeLogRepository().settleAll());
    final ops = (await tester.runAsync(
      () => db
          .customSelect(
            'SELECT label FROM change_log_operations '
            'WHERE label IS NOT NULL',
          )
          .get(),
    ))!;
    expect(ops.map((r) => r.read<String?>('label')), [
      'record_edit:media:color,details',
    ]);
  });

  testWidgets('next with changes asks; Keep editing keeps them', (
    tester,
  ) async {
    await pumpSite(tester);
    await tapUnlock(tester);
    controller(
      tester,
    ).session!.set(photoColorField, const ColorAdjustment(warmth: 0.3));
    await settleViewer(tester);

    await tester.tap(find.byTooltip('Next media'));
    await settleViewer(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settleViewer(tester);

    expect(controller(tester).isDirty, isTrue);
    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  testWidgets('a narrow window: the editing bar folds its actions into the '
      'menu and does not overflow', (tester) async {
    await pumpViewerApp(
      tester,
      const SiteMediaViewerPage(
        siteId: 's1',
        initialMediaId: 'a1',
        scope: SiteViewerScope.attachments,
      ),
      size: const Size(300, 800),
    );
    await tapUnlock(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byKey(const ValueKey('viewer_overflow')), findsOneWidget);
  });

  testWidgets('a viewer built with only its site opens locked', (tester) async {
    await pumpViewerApp(
      tester,
      const SiteMediaViewerPage(
        siteId: 's1',
        initialMediaId: 'a1',
        scope: SiteViewerScope.attachments,
      ),
    );

    expect(find.byKey(const ValueKey('viewer_unlock')), findsOneWidget);
    expect(find.byTooltip('Adjust color'), findsNothing);
    expect(find.byTooltip('Edit details'), findsNothing);
  });

  group('unlink (#5126)', () {
    late RowDeletingCoordinator coordinator;
    setUp(() => coordinator = RowDeletingCoordinator());

    Future<void> pumpSiteUnlinkable(WidgetTester tester) => pumpViewerApp(
      tester,
      pushedFrom(
        const SiteMediaViewerPage(
          siteId: 's1',
          initialMediaId: 'a1',
          scope: SiteViewerScope.attachments,
        ),
      ),
      overrides: [
        mediaDeletionCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );

    Future<void> holdUnlink(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('viewer_unlink')));
      await settleViewer(tester);
      await tester.tap(find.byKey(const ValueKey('viewer_unlink_confirm')));
      await settleViewer(tester);
    }

    testWidgets('held: the strip says the site, editing goes quiet', (
      tester,
    ) async {
      await pumpSiteUnlinkable(tester);
      await openPushed(tester);
      await tapUnlock(tester);
      expect(find.byTooltip('Unlink from site'), findsOneWidget);

      await holdUnlink(tester);

      expect(find.byKey(const ValueKey('viewer_unlink_strip')), findsOneWidget);
      expect(
        find.text('Will be unlinked from this site when you save'),
        findsOneWidget,
      );
      expect(find.byTooltip('Adjust color'), findsNothing);
      expect(find.byTooltip('Edit details'), findsNothing);
      expect(find.byKey(const ValueKey('viewer_unlink')), findsNothing);
    });

    testWidgets('the dive photos taken here unlink from their dive', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await insertTestDiver('me');
        await insertTestDive(
          id: 'd1',
          at: DateTime(2024, 1, 10, 9),
          siteId: 's1',
          diverId: 'me',
        );
        await insertTestMedia(
          id: 'p1',
          diveId: 'd1',
          takenAt: DateTime(2024, 1, 10, 9, 2),
        );
      });
      await pumpViewerApp(
        tester,
        const SiteMediaViewerPage(
          siteId: 's1',
          initialMediaId: 'p1',
          scope: SiteViewerScope.divePhotos,
        ),
      );
      await tapUnlock(tester);

      expect(find.byTooltip('Unlink from dive'), findsOneWidget);
      expect(find.byTooltip('Unlink from site'), findsNothing);
    });

    testWidgets('Save unlinks it, and the next attachment shows', (
      tester,
    ) async {
      await pumpSiteUnlinkable(tester);
      await openPushed(tester);
      await tapUnlock(tester);
      await holdUnlink(tester);

      await tester.tap(find.text('Save'));
      await settleViewer(tester, rounds: 10);

      expect(coordinator.deleted, ['a1']);
      expect(
        await tester.runAsync(() => MediaRepository().getMediaById('a1')),
        isNull,
      );
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('moved to another site meanwhile, Save unlinks nothing', (
      tester,
    ) async {
      await pumpSiteUnlinkable(tester);
      await openPushed(tester);
      await tapUnlock(tester);
      await holdUnlink(tester);
      await tester.runAsync(() async {
        await insertTestSite('s2', 'Shark Point');
        await db.customStatement(
          "UPDATE media SET site_id = 's2' WHERE id = 'a1'",
        );
      });
      await settleViewer(tester);

      await tester.tap(find.text('Save'));
      await settleViewer(tester, rounds: 10);

      expect(coordinator.deleted, isEmpty);
      expect((await stored(tester, 'a1')).siteId, 's2');
    });

    testWidgets('the only attachment closes the viewer', (tester) async {
      await tester.runAsync(
        () => MediaRepository().deleteMultipleMedia(['a2']),
      );
      await pumpSiteUnlinkable(tester);
      await openPushed(tester);
      await tapUnlock(tester);
      await holdUnlink(tester);

      await tester.tap(find.text('Save'));
      await settleViewer(tester, rounds: 10);
      await tester.pumpAndSettle();

      expect(find.byType(SiteMediaViewerPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
