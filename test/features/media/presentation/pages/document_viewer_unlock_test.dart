import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/pages/document_viewer_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';

/// The PDF viewer opened from a site has the attachment's own lock (issue
/// #4527, phase 2): it opens locked with no Edit details, and unlocked its
/// details are held until one Save.
void main() {
  late AppDatabase db;
  const unlockKey = ValueKey('document_unlock');

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await insertTestSite('s1', 'Blue Hole');
    await insertTestMedia(
      id: 'doc1',
      siteId: 's1',
      fileType: 'document',
      originalFilename: 'reef-map.pdf',
    );
  });
  tearDown(tearDownTestDatabase);

  Future<MediaItem> stored(WidgetTester tester) async =>
      (await tester.runAsync(() => MediaRepository().getMediaById('doc1')))!;

  Future<void> pumpDocument(
    WidgetTester tester, {
    String? editableSiteId = 's1',
    bool browser = false,
    bool pushed = false,
  }) async {
    final item = await stored(tester);
    final page = DocumentViewerPage(item: item, editableSiteId: editableSiteId);
    await pumpViewerApp(
      tester,
      pushed ? pushedFrom(page) : page,
      browser: browser,
    );
    if (pushed) await openPushed(tester);
  }

  Future<void> removeDocument(WidgetTester tester) async {
    await tester.runAsync(
      () => (db.delete(db.media)..where((t) => t.id.equals('doc1'))).go(),
    );
    await settleViewer(tester, rounds: 10);
    // An open sitting ends first, then the page closes: let its route go.
    await settleViewer(tester, rounds: 10);
  }

  RecordEditController<PhotoRecord> controller(WidgetTester tester) =>
      RecordEditScope.maybeOf<PhotoRecord>(
        tester.element(find.byType(RecordEditBar)),
      )!;

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byKey(unlockKey));
    await settleViewer(tester);
  }

  /// Opens Edit details and picks [category] in place of [from].
  Future<void> holdCategory(
    WidgetTester tester, {
    required String from,
    required String category,
  }) async {
    await tester.tap(find.byTooltip('Edit details'));
    await settleViewer(tester);
    await tester.tap(find.text(from).last);
    await settleViewer(tester);
    await tester.tap(find.text(category).last);
    await settleViewer(tester);
    await tester.tap(find.text('Done'));
    await settleViewer(tester);
  }

  testWidgets('locked: the lock and Share, no Edit details, nothing written', (
    tester,
  ) async {
    await pumpDocument(tester);
    final mark = (await tester.runAsync(() => eventCount(db)))!;

    expect(find.byKey(unlockKey), findsOneWidget);
    expect(find.byTooltip('Edit details'), findsNothing);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect((await tester.runAsync(() => eventCount(db)))!, mark);
  });

  testWidgets('unlocked: held details, one entry on Save', (tester) async {
    await pumpDocument(tester);
    await unlock(tester);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Editing document'), findsOneWidget);

    await holdCategory(tester, from: 'Uncategorized', category: 'Site map');
    expect((await stored(tester)).siteCategory, isNull);

    await tester.tap(find.text('Save'));
    await settleViewer(tester, rounds: 10);

    expect((await stored(tester)).siteCategory, SiteAttachmentCategory.siteMap);
    expect(find.byType(RecordEditBar), findsNothing);
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
      'record_edit:media:details',
    ]);
  });

  testWidgets('Cancel with held details asks first', (tester) async {
    await pumpDocument(tester);
    await unlock(tester);
    await holdCategory(tester, from: 'Uncategorized', category: 'Site map');

    await tester.tap(find.text('Cancel'));
    await settleViewer(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settleViewer(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(controller(tester).isDirty, isTrue);
  });

  // Review Focus 3 on this page: Back with held details asks first.
  testWidgets('Back with held details asks first', (tester) async {
    await pumpDocument(tester);
    await unlock(tester);
    await holdCategory(tester, from: 'Uncategorized', category: 'Site map');

    await tester.binding.handlePopRoute();
    await settleViewer(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  // Review Focus 4: a change undone leaves nothing to save.
  testWidgets('details set back to what is stored leave nothing to save', (
    tester,
  ) async {
    await pumpDocument(tester);
    await unlock(tester);
    await holdCategory(tester, from: 'Uncategorized', category: 'Site map');
    expect(controller(tester).isDirty, isTrue);

    await holdCategory(tester, from: 'Site map', category: 'Uncategorized');

    expect(controller(tester).isDirty, isFalse);
  });

  // Review Focus 1: the document goes while its lock is open.
  testWidgets('a document removed while unlocked ends the sitting in '
      'document words, and the viewer closes', (tester) async {
    await pumpDocument(tester, pushed: true);
    await unlock(tester);

    await removeDocument(tester);

    expect(find.byType(DocumentViewerPage), findsNothing);
    expect(
      find.text('This document was removed. Your changes were not saved.'),
      findsOneWidget,
    );
    expect(find.text('This document was removed.'), findsNothing);
  });

  testWidgets('a document removed while locked closes the viewer and says '
      'so', (tester) async {
    await pumpDocument(tester, pushed: true);

    await removeDocument(tester);

    expect(find.byType(DocumentViewerPage), findsNothing);
    expect(find.text('This document was removed.'), findsOneWidget);
  });

  testWidgets('a document unlinked from the site closes the viewer', (
    tester,
  ) async {
    await pumpDocument(tester, pushed: true);

    await tester.runAsync(
      () => (db.update(db.media)..where((t) => t.id.equals('doc1'))).write(
        const MediaCompanion(siteId: Value(null)),
      ),
    );
    await settleViewer(tester, rounds: 10);
    await settleViewer(tester, rounds: 10);

    expect(find.byType(DocumentViewerPage), findsNothing);
    expect(find.text('This document was removed.'), findsOneWidget);
  });

  testWidgets('a document unlinked while unlocked ends the sitting unsaved '
      'and closes the viewer', (tester) async {
    await pumpDocument(tester, pushed: true);
    await unlock(tester);
    await holdCategory(tester, from: 'Uncategorized', category: 'Site map');

    await tester.runAsync(
      () => (db.update(db.media)..where((t) => t.id.equals('doc1'))).write(
        const MediaCompanion(siteId: Value(null)),
      ),
    );
    await settleViewer(tester, rounds: 10);
    await settleViewer(tester, rounds: 10);

    expect(find.byType(DocumentViewerPage), findsNothing);
    expect(
      find.text('This document was removed. Your changes were not saved.'),
      findsOneWidget,
    );
    expect((await stored(tester)).siteCategory, isNull);
  });

  testWidgets('a viewer opened on a document already removed closes', (
    tester,
  ) async {
    final item = await stored(tester);
    await tester.runAsync(
      () => (db.delete(db.media)..where((t) => t.id.equals('doc1'))).go(),
    );
    await pumpViewerApp(
      tester,
      pushedFrom(DocumentViewerPage(item: item, editableSiteId: 's1')),
    );

    await openPushed(tester);
    await settleViewer(tester, rounds: 10);

    expect(find.byType(DocumentViewerPage), findsNothing);
    expect(find.text('This document was removed.'), findsOneWidget);
  });

  testWidgets('opened from a dive it offers no lock', (tester) async {
    await pumpDocument(tester, editableSiteId: null);

    expect(find.byKey(unlockKey), findsNothing);
    expect(find.byTooltip('Edit details'), findsNothing);
  });

  // Review Focus 5: a browser changes no media.
  testWidgets('a browser offers no lock', (tester) async {
    await pumpDocument(tester, browser: true);

    expect(find.byKey(unlockKey), findsNothing);
    expect(find.byTooltip('Edit details'), findsNothing);
  });
}
