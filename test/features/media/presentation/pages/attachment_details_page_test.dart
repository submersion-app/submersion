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
  }) async {
    final item = await stored(tester);
    await pumpViewerApp(
      tester,
      AttachmentDetailsPage(item: item, siteId: 's1', showOpen: showOpen),
      browser: browser,
    );
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

  // Review Focus 5: a browser changes no media.
  testWidgets('a browser reads only', (tester) async {
    await pumpPage(tester, browser: true);

    expect(find.byKey(unlockKey), findsNothing);
    expect(categoryField(tester).onChanged, isNull);
  });
}
