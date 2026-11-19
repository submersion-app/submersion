import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/pages/attachment_details_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';

/// A site document with no viewer (a Word file, a spreadsheet) opens a
/// details page with the attachment's own lock (issue #4527, phase 2): its
/// name, Open, Share and the details, read only until unlocked, then held
/// until one Save.
void main() {
  const unlockKey = ValueKey('document_unlock');

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await insertTestSite('s1', 'Blue Hole');
    await insertTestMedia(
      id: 'doc2',
      siteId: 's1',
      fileType: 'document',
      originalFilename: 'briefing.docx',
    );
  });
  tearDown(tearDownTestDatabase);

  Future<MediaItem> stored(WidgetTester tester) async =>
      (await tester.runAsync(() => MediaRepository().getMediaById('doc2')))!;

  Future<void> pumpPage(
    WidgetTester tester, {
    bool showOpen = true,
    bool browser = false,
    bool pushed = false,
    List<Override> overrides = const [],
  }) async {
    final item = await stored(tester);
    final page = AttachmentDetailsPage(
      item: item,
      siteId: 's1',
      showOpen: showOpen,
    );
    await pumpViewerApp(
      tester,
      pushed ? pushedFrom(page) : page,
      browser: browser,
      overrides: overrides,
    );
    if (pushed) await openPushed(tester);
  }

  Future<void> removeDocument(WidgetTester tester) async {
    final db = DatabaseService.instance.database;
    await tester.runAsync(
      () => (db.delete(db.media)..where((t) => t.id.equals('doc2'))).go(),
    );
    await settleViewer(tester, rounds: 10);
    // An open sitting ends first, then the page closes: let its route go.
    await settleViewer(tester, rounds: 10);
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byKey(unlockKey));
    await settleViewer(tester);
  }

  DropdownButton<SiteAttachmentCategory?> categoryField(WidgetTester tester) =>
      tester.widget(find.byType(DropdownButton<SiteAttachmentCategory?>));

  Future<void> pickCategory(WidgetTester tester, String category) async {
    await tester.tap(find.text('Uncategorized'));
    await settleViewer(tester);
    await tester.tap(find.text(category).last);
    await settleViewer(tester);
  }

  testWidgets('locked: the name, the details read only, Open and Share', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('briefing.docx'), findsOneWidget);
    expect(categoryField(tester).onChanged, isNull);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.byKey(unlockKey), findsOneWidget);
  });

  testWidgets('unlocked: the details change in place, held until Save', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(unlockKey));
    await settleViewer(tester);
    expect(find.text('Editing attachment'), findsOneWidget);

    await pickCategory(tester, 'Site map');
    expect((await stored(tester)).siteCategory, isNull);

    await tester.tap(find.text('Save'));
    await settleViewer(tester, rounds: 10);

    expect((await stored(tester)).siteCategory, SiteAttachmentCategory.siteMap);
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.byKey(unlockKey), findsOneWidget);
  });

  // Review Focus 3: a way out the bar does not hold still asks.
  testWidgets('Back with held changes asks first', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(unlockKey));
    await settleViewer(tester);
    await pickCategory(tester, 'Site map');

    await tester.binding.handlePopRoute();
    await settleViewer(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Open is not offered where it would be Share', (tester) async {
    await pumpPage(tester, showOpen: false);

    expect(find.text('Open'), findsNothing);
    expect(find.byIcon(Icons.share), findsOneWidget);
  });

  // A pick keeps the field it was made in, so a keyboard keeps its place;
  // a value set from outside (Cancel) still shows.
  testWidgets('a pick keeps its field, and Cancel puts the stored details '
      'back', (tester) async {
    await pumpPage(tester);
    await unlock(tester);
    final field = find.byType(DropdownButtonFormField<SiteAttachmentCategory?>);
    final before = tester.state(field);

    await pickCategory(tester, 'Site map');
    expect(tester.state(field), same(before));

    await tester.tap(find.text('Cancel'));
    await settleViewer(tester);
    await tester.tap(find.text('Discard'));
    await settleViewer(tester);
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.text('Site map'), findsNothing);
  });

  // A pick made while Save runs would be dropped: the fields wait.
  testWidgets('the fields wait while Save runs', (tester) async {
    final release = Completer<void>();
    await pumpPage(
      tester,
      overrides: [
        photoEditSaveServiceProvider.overrideWithValue(
          _SlowSave(release.future),
        ),
      ],
    );
    await unlock(tester);
    await pickCategory(tester, 'Site map');

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(categoryField(tester).onChanged, isNull);

    release.complete();
    await settleViewer(tester);
  });

  // The save itself finds the document gone (deleted or unlinked while it
  // ran): the sitting ends unsaved and the page closes, saying so once.
  testWidgets('a save that finds the document gone closes the page', (
    tester,
  ) async {
    await pumpPage(
      tester,
      pushed: true,
      overrides: [photoEditSaveServiceProvider.overrideWithValue(_GoneSave())],
    );
    await unlock(tester);
    await pickCategory(tester, 'Site map');

    await tester.tap(find.text('Save'));
    await settleViewer(tester, rounds: 10);
    await settleViewer(tester, rounds: 10);

    expect(find.byType(AttachmentDetailsPage), findsNothing);
    expect(
      find.text('This document was removed. Your changes were not saved.'),
      findsOneWidget,
    );
    expect(find.text('This document was removed.'), findsNothing);
  });

  // The document goes after the save wrote but before it finished: the
  // sitting ends as a save, so the page says the document was removed as
  // it closes, rather than closing without a word.
  testWidgets('a document removed while a save finishes closes the page and '
      'says so', (tester) async {
    final release = Completer<void>();
    await pumpPage(
      tester,
      pushed: true,
      overrides: [
        photoEditSaveServiceProvider.overrideWithValue(
          _SlowSave(release.future),
        ),
      ],
    );
    await unlock(tester);
    await pickCategory(tester, 'Site map');
    await tester.tap(find.text('Save'));
    await tester.pump();

    await removeDocument(tester);
    release.complete();
    await settleViewer(tester, rounds: 10);
    await settleViewer(tester, rounds: 10);

    expect(find.byType(AttachmentDetailsPage), findsNothing);
    expect(find.text('This document was removed.'), findsOneWidget);
  });

  // Review Focus 1 on this page: the document goes while unlocked.
  // The page closes once its document is gone, saying so once.
  testWidgets('a document removed while unlocked ends the sitting in '
      'document words, and the page closes', (tester) async {
    await pumpPage(tester, pushed: true);
    await unlock(tester);

    await removeDocument(tester);

    expect(find.byType(AttachmentDetailsPage), findsNothing);
    expect(
      find.text('This document was removed. Your changes were not saved.'),
      findsOneWidget,
    );
    expect(find.text('This document was removed.'), findsNothing);
  });

  testWidgets('a document removed while locked closes the page and says so', (
    tester,
  ) async {
    await pumpPage(tester, pushed: true);

    await removeDocument(tester);

    expect(find.byType(AttachmentDetailsPage), findsNothing);
    expect(find.text('This document was removed.'), findsOneWidget);
  });

  /// Unlinks the document from the site, as a site unlink does to a row a
  /// dive still uses: the row stays, its site link cleared.
  Future<void> unlinkFromSite(WidgetTester tester) async {
    final db = DatabaseService.instance.database;
    await tester.runAsync(
      () => (db.update(db.media)..where((t) => t.id.equals('doc2'))).write(
        const MediaCompanion(siteId: Value(null)),
      ),
    );
    await settleViewer(tester, rounds: 10);
    await settleViewer(tester, rounds: 10);
  }

  // Left the site, kept for a dive: no longer the site's attachment.
  testWidgets('a document unlinked from the site closes the page', (
    tester,
  ) async {
    await pumpPage(tester, pushed: true);

    await unlinkFromSite(tester);

    expect(find.byType(AttachmentDetailsPage), findsNothing);
    expect(find.text('This document was removed.'), findsOneWidget);
  });

  testWidgets('a document unlinked while unlocked ends the sitting unsaved '
      'and closes the page', (tester) async {
    await pumpPage(tester, pushed: true);
    await unlock(tester);
    await pickCategory(tester, 'Site map');

    await unlinkFromSite(tester);

    expect(find.byType(AttachmentDetailsPage), findsNothing);
    expect(
      find.text('This document was removed. Your changes were not saved.'),
      findsOneWidget,
    );
    final stored = await tester.runAsync(
      () => MediaRepository().getMediaById('doc2'),
    );
    expect(stored!.siteCategory, isNull);
  });

  // The page closes itself, whatever is open above it.
  testWidgets('a removed document closes the page under a dialog', (
    tester,
  ) async {
    await pumpPage(tester, pushed: true);
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(AttachmentDetailsPage)),
        builder: (_) => const AlertDialog(content: Text('above')),
      ),
    );
    await settleViewer(tester);

    await removeDocument(tester);

    expect(find.text('above'), findsNothing);
    expect(find.byType(AttachmentDetailsPage), findsNothing);
  });

  // Opened on a document already gone (a stale item while a sync lands):
  // the row is already read as missing when the page starts to follow it.
  testWidgets('a page opened on a document already removed closes', (
    tester,
  ) async {
    final item = await stored(tester);
    final db = DatabaseService.instance.database;
    await tester.runAsync(
      () => (db.delete(db.media)..where((t) => t.id.equals('doc2'))).go(),
    );
    await pumpViewerApp(
      tester,
      Column(
        children: [
          // Something else already holds the row's read, as missing.
          Consumer(
            builder: (context, ref, _) {
              final read = ref.watch(photoRecordProvider('doc2'));
              return Text(read.isLoading ? 'reading' : 'read');
            },
          ),
          Expanded(
            child: pushedFrom(AttachmentDetailsPage(item: item, siteId: 's1')),
          ),
        ],
      ),
    );
    expect(find.text('read'), findsOneWidget);

    await openPushed(tester);
    await settleViewer(tester, rounds: 10);

    expect(find.byType(AttachmentDetailsPage), findsNothing);
    expect(find.text('This document was removed.'), findsOneWidget);
  });

  testWidgets('a browser closes the page too', (tester) async {
    await pumpPage(tester, pushed: true, browser: true);

    await removeDocument(tester);

    expect(find.byType(AttachmentDetailsPage), findsNothing);
    expect(find.text('This document was removed.'), findsOneWidget);
  });

  // A browser follows the stored details too, though it never unlocks.
  testWidgets('a browser shows details changed elsewhere', (tester) async {
    await pumpPage(tester, browser: true);
    expect(find.text('Uncategorized'), findsOneWidget);

    final db = DatabaseService.instance.database;
    await tester.runAsync(
      () => (db.update(db.media)..where((t) => t.id.equals('doc2'))).write(
        const MediaCompanion(siteCategory: Value('siteMap')),
      ),
    );
    await settleViewer(tester, rounds: 10);

    expect(find.text('Site map'), findsOneWidget);
  });

  // Review Focus 5: a browser changes no media.
  testWidgets('a browser reads only', (tester) async {
    await pumpPage(tester, browser: true);

    expect(find.byKey(unlockKey), findsNothing);
    expect(categoryField(tester).onChanged, isNull);
  });
}

/// A save that waits for [release], as a slow write does.
class _SlowSave extends Fake implements PhotoEditSaveService {
  _SlowSave(this.release);

  final Future<void> release;

  @override
  Future<({PhotoRecord before, PhotoRecord after})?> save({
    required String mediaId,
    required String? diverId,
    required PhotoRecord Function(PhotoRecord stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    ({String? id})? diveAtStart,
    String? siteAtStart,
  }) async {
    await release;
    return null;
  }
}

/// A save that finds the document gone, as one deleted or unlinked while
/// it ran does.
class _GoneSave extends Fake implements PhotoEditSaveService {
  @override
  Future<({PhotoRecord before, PhotoRecord after})?> save({
    required String mediaId,
    required String? diverId,
    required PhotoRecord Function(PhotoRecord stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    ({String? id})? diveAtStart,
    String? siteAtStart,
  }) async => throw PhotoGoneError(mediaId);
}
