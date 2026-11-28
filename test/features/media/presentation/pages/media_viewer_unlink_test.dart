import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_unlink.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/marine_life_id_off.dart';
import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';

/// The media viewer's Unlink, held until Save (issue #5126).
void main() {
  turnOffMarineLifeIdForEachTest();

  late AppDatabase db;
  late RowDeletingCoordinator coordinator;
  final l10n = AppLocalizationsEn();

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
    coordinator = RowDeletingCoordinator();
  });

  tearDown(tearDownTestDatabase);

  Future<void> open(
    WidgetTester tester, {
    List<String> ids = const ['p1', 'p2', 'p3'],
    String initial = 'p2',
    ViewerUnlinkScope? scope = ViewerUnlinkScope.dive,
    bool browser = false,
  }) => pumpViewer(
    tester,
    ids: ids,
    initial: initial,
    unlinkScope: scope,
    browser: browser,
    overrides: [
      mediaDeletionCoordinatorProvider.overrideWithValue(coordinator),
    ],
  );

  Finder unlinkAction() => find.byKey(const ValueKey('viewer_unlink'));
  Finder strip() => find.byKey(const ValueKey('viewer_unlink_strip'));

  /// Taps Unlink and confirms it.
  Future<void> holdUnlink(WidgetTester tester) async {
    await tester.tap(unlinkAction());
    await settleViewer(tester);
    await tester.tap(find.byKey(const ValueKey('viewer_unlink_confirm')));
    await settleViewer(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await settleViewer(tester, rounds: 10);
  }

  bool canSave(WidgetTester tester) =>
      tester.widget<RecordEditBar>(find.byType(RecordEditBar)).canSave;

  String shownId(WidgetTester tester) => tester
      .widget<MediaViewerToolbar>(find.byType(MediaViewerToolbar))
      .item
      .id;

  Future<bool> stored(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => MediaRepository().getMediaById(id))) != null;

  testWidgets('no unlink while locked; unlocking offers it', (tester) async {
    await open(tester);
    expect(unlinkAction(), findsNothing);

    await tapUnlock(tester);

    expect(unlinkAction(), findsOneWidget);
    expect(find.byTooltip(l10n.media_viewer_unlinkFromDive), findsOneWidget);
  });

  testWidgets('no unlink without a scope', (tester) async {
    await open(tester, scope: null);
    await tapUnlock(tester);
    expect(unlinkAction(), findsNothing);
  });

  testWidgets('no dive-scoped unlink on a photo with no dive', (tester) async {
    await open(tester, ids: ['lib'], initial: 'lib');
    await tapUnlock(tester);
    expect(unlinkAction(), findsNothing);
  });

  testWidgets('the browser build offers no unlink', (tester) async {
    await open(tester, browser: true);
    expect(unlinkAction(), findsNothing);
    expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
  });

  testWidgets('the question speaks of one item', (tester) async {
    await open(tester);
    await tapUnlock(tester);
    await tester.tap(unlinkAction());
    await settleViewer(tester);

    expect(find.text(l10n.media_viewer_unlinkConfirmDiveBody), findsOneWidget);
  });

  testWidgets('cancelling the question holds nothing', (tester) async {
    await open(tester);
    await tapUnlock(tester);
    await tester.tap(unlinkAction());
    await settleViewer(tester);

    await tester.tap(find.text(l10n.common_action_cancel).last);
    await settleViewer(tester);

    expect(strip(), findsNothing);
    expect(canSave(tester), isFalse);
  });

  testWidgets('confirming holds the unlink: the strip, quiet actions, Save', (
    tester,
  ) async {
    await open(tester);
    await tapUnlock(tester);
    expect(find.byKey(const ValueKey('viewer_species')), findsOneWidget);

    await holdUnlink(tester);

    expect(strip(), findsOneWidget);
    expect(find.text(l10n.media_viewer_unlinkHeldDive), findsOneWidget);
    expect(find.byKey(const ValueKey('viewer_species')), findsNothing);
    expect(unlinkAction(), findsNothing, reason: 'the strip has Undo');
    expect(canSave(tester), isTrue);
    expect(await stored(tester, 'p2'), isTrue, reason: 'held until Save');
  });

  testWidgets('Undo drops the hold', (tester) async {
    await open(tester);
    await tapUnlock(tester);
    await holdUnlink(tester);

    await tester.tap(find.byKey(const ValueKey('viewer_unlink_undo')));
    await settleViewer(tester);

    expect(strip(), findsNothing);
    expect(canSave(tester), isFalse);
    expect(unlinkAction(), findsOneWidget);
  });

  testWidgets('discarding a held unlink keeps the photo', (tester) async {
    await open(tester);
    await tapUnlock(tester);
    await holdUnlink(tester);
    final mark = (await tester.runAsync(() => eventCount(db)))!;

    await tester.tap(find.text('Cancel'));
    await settleViewer(tester);
    await tester.tap(find.text('Discard'));
    await settleViewer(tester);

    expect(strip(), findsNothing);
    expect(find.byType(RecordEditBar), findsNothing);
    expect(await stored(tester, 'p2'), isTrue);
    expect(await tester.runAsync(() => eventCount(db)), mark);
  });

  group('after Save', () {
    testWidgets('the next item shows', (tester) async {
      await open(tester, scope: ViewerUnlinkScope.library);
      await tapUnlock(tester);
      await holdUnlink(tester);

      await save(tester);

      expect(await stored(tester, 'p2'), isFalse);
      expect(shownId(tester), 'p3');
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('the last item falls back to the one before', (tester) async {
      await open(tester, initial: 'p3', scope: ViewerUnlinkScope.library);
      await tapUnlock(tester);
      await holdUnlink(tester);

      await save(tester);

      expect(shownId(tester), 'p2');
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('an only item closes the viewer', (tester) async {
      final items = await tester.runAsync(() => storedMedia(['lib']));
      await pumpViewerApp(
        tester,
        pushedFrom(
          MediaViewerPage(
            mediaList: items!,
            initialMediaId: 'lib',
            unlinkScope: ViewerUnlinkScope.library,
          ),
        ),
        overrides: [
          mediaDeletionCoordinatorProvider.overrideWithValue(coordinator),
        ],
      );
      await openPushed(tester);
      await tapUnlock(tester);
      await holdUnlink(tester);

      await save(tester);
      // The close waits a frame, then the route animates away.
      await tester.pumpAndSettle();

      expect(find.byType(MediaViewerPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(await stored(tester, 'lib'), isFalse);
    });

    testWidgets('no gone message after its own unlink', (tester) async {
      await open(tester, scope: ViewerUnlinkScope.library);
      await tapUnlock(tester);
      await holdUnlink(tester);

      await save(tester);
      await settleViewer(tester, rounds: 6);

      expect(find.text(l10n.media_viewer_photoGoneWhileEditing), findsNothing);
    });

    testWidgets('a video unlinks too', (tester) async {
      await tester.runAsync(
        () => insertTestMedia(
          id: 'v1',
          diveId: 'd1',
          fileType: 'video',
          takenAt: DateTime(2024, 1, 10, 9, 3),
        ),
      );
      await open(tester, ids: ['p1', 'v1'], initial: 'v1');
      await tapUnlock(tester);
      await holdUnlink(tester);

      await save(tester);

      expect(await stored(tester, 'v1'), isFalse);
      expect(coordinator.deleted, ['v1']);
    });
  });
}
