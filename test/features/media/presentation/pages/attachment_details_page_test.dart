import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:flutter/material.dart';
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
    List<Override> overrides = const [],
  }) async {
    final item = await stored(tester);
    await pumpViewerApp(
      tester,
      AttachmentDetailsPage(item: item, siteId: 's1', showOpen: showOpen),
      browser: browser,
      overrides: overrides,
    );
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

  // Review Focus 1 on this page: the document goes while unlocked.
  testWidgets('a document removed while unlocked ends the sitting in '
      'document words', (tester) async {
    await pumpPage(tester);
    await unlock(tester);

    final db = DatabaseService.instance.database;
    await tester.runAsync(
      () => (db.delete(db.media)..where((t) => t.id.equals('doc2'))).go(),
    );
    await settleViewer(tester, rounds: 10);

    expect(find.byType(RecordEditBar), findsNothing);
    expect(
      find.text('This document was removed. Your changes were not saved.'),
      findsOneWidget,
    );
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
  }) async {
    await release;
    return null;
  }
}
