import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/features/media/presentation/pages/attachment_details_page.dart';

import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_attachment_card_editors.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_media_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import 'site_editor_harness.dart';

/// The site's Media and Documents cards hold what they add and remove until
/// Save (issue #4527, phase 2, plan 3).
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(id: 's1', diverId: 'me', name: 'Blue Hole');
  final at = DateTime.utc(2026);

  /// A document attachment, drawn as a tile.
  MediaItem attachment(String id, {String name = 'Map'}) => MediaItem(
    id: id,
    siteId: 's1',
    mediaType: MediaType.document,
    originalFilename: '$name.pdf',
    takenAt: at,
    createdAt: at,
    updatedAt: at,
  );

  /// Writers that record what Save would write, and write nothing.
  SittingMediaWriters recording(List<String> unlinked) => SittingMediaWriters(
    writeRows: (prepared) async => [for (final p in prepared) p.item.id],
    insertNetwork: (_) async => const [],
    unlink: (ids) async => unlinked.addAll(ids),
    replace: (_, _, _) async {},
    drainDeletes: () async {},
    enqueueUpload: (_) {},
  );

  group('the Media card', () {
    Future<EditSession<DiveSite>> pumpMedia(
      WidgetTester tester, {
      List<MediaItem> stored = const [],
      List<String>? unlinked,
      List<Override> overrides = const [],
    }) async {
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteMediaCardEditor(session: session),
        onStart: (session) => holdSittingMedia(
          session,
          recording(unlinked ?? []),
          cardId: 'media',
        ),
        overrides: [
          mediaForSiteProvider('s1').overrideWith((_) async => stored),
          ...overrides,
        ],
      );
      return h.session;
    }

    testWidgets('an added attachment shows as held and writes nothing', (
      tester,
    ) async {
      final session = await pumpMedia(tester);

      addMediaToSitting(session, [
        HeldMediaRow((item: attachment('held-1'), enrichment: null)),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(MediaThumbnailTile), findsOneWidget);
      expect(session.changedCardIds, {'media'});
    });

    testWidgets('unlinking a stored attachment holds it', (tester) async {
      final unlinked = <String>[];
      final session = await pumpMedia(
        tester,
        stored: [attachment('m1')],
        unlinked: unlinked,
      );

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaThumbnailTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.link_off));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.media_diveMediaSection_unlinkButton));
      await tester.pumpAndSettle();

      expect(sittingMedia(session).unlinked, {'m1'});
      expect(find.byType(MediaThumbnailTile), findsNothing);
      // Held: nothing unlinked until Save.
      expect(unlinked, isEmpty);
    });

    // The open card is built only on a page that edits in place, where an
    // attachment opens under its own lock (issue #4527, phase 2).
    testWidgets('the open Media card opens a document under its lock', (
      tester,
    ) async {
      final briefing = MediaItem(
        id: 'd2',
        siteId: 's1',
        mediaType: MediaType.document,
        originalFilename: 'briefing.docx',
        takenAt: at,
        createdAt: at,
        updatedAt: at,
      );
      await pumpMedia(
        tester,
        stored: [briefing],
        overrides: [
          photoRecordProvider('d2').overrideWith(
            (_) async => PhotoRecord(
              item: briefing,
              species: const [],
              people: const [],
            ),
          ),
        ],
      );

      await tester.tap(find.byType(MediaThumbnailTile));
      await tester.pumpAndSettle();

      expect(find.byType(AttachmentDetailsPage), findsOneWidget);
    });

    testWidgets('a held attachment cannot be opened', (tester) async {
      final opened = <String>[];
      final controller = RecordEditController<DiveSite>(
        onSave: (_) async {},
        onStart: (session) =>
            holdSittingMedia(session, recording([]), cardId: 'media'),
      )..unlock(site);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            mediaForSiteProvider('s1').overrideWith((_) async => <MediaItem>[]),
          ].cast<Override>(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ListenableBuilder(
                  listenable: controller.session!,
                  builder: (context, _) => SiteMediaSection(
                    siteId: 's1',
                    editing: controller.session,
                    onOpenDocument: (item) => opened.add(item.id),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      addMediaToSitting(controller.session!, [
        HeldMediaRow((item: attachment('held-1'), enrichment: null)),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MediaThumbnailTile));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
    });

    testWidgets('on a page that edits in place, the locked card offers no '
        'add or unlink', (tester) async {
      final controller = RecordEditController<DiveSite>(onSave: (_) async {});
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            mediaForSiteProvider(
              's1',
            ).overrideWith((_) async => [attachment('m1')]),
          ].cast<Override>(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordEditScope<DiveSite>(
                  controller: controller,
                  child: SiteMediaSection(
                    siteId: 's1',
                    onAddPhotosPressed: () {},
                    onAddDocumentPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l.media_diveMediaSection_addTooltip), findsNothing);
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.link_off), findsNothing);
    });
  });

  group('with a database', () {
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
      await insertDiver(db, 'me');
      await SiteRepository().createSite(site);
    });

    tearDown(tearDownTestDatabase);

    Document personal(String title) => Document(
      id: '',
      diverId: 'me',
      owner: const DocumentOwner.personal(),
      type: DocumentType.other,
      title: title,
      createdAt: at,
      updatedAt: at,
    );

    testWidgets('attaching a document holds it on the Documents card', (
      tester,
    ) async {
      final doc = await DocumentRepository().save(personal('Permit'), const []);
      final h = await pumpSiteEditor(
        tester,
        site,
        (session) => SiteDocumentsCardEditor(session: session),
      );
      holdDocumentLinks(
        h.session,
        ProviderScope.containerOf(
          tester.element(find.byType(SiteDocumentsCardEditor)),
        ).read,
        owner: const DocumentOwner(DocumentOwnerKind.site, 's1'),
        cardId: 'documents',
      );

      attachDocument(h.session, doc);
      await tester.pumpAndSettle();

      expect(find.text('Permit'), findsOneWidget);
      expect(h.session.changedCardIds, {'documents'});
      expect(
        (await DocumentRepository().getById(doc.id))!.owner,
        const DocumentOwner.personal(),
      );
    });

    test('Save writes the media row and the document owner as one History '
        'entry', () async {
      final doc = await DocumentRepository().save(personal('Permit'), const []);
      await ChangeLogRepository().settleAll();
      await db.customStatement('DELETE FROM change_log_operations');
      final container = ProviderContainer(
        overrides: [...(await getBaseOverrides()).cast<Override>()],
      );
      addTearDown(container.dispose);
      final session = EditSession<DiveSite>(site);
      addTearDown(session.dispose);
      holdSittingMedia(
        session,
        SittingMediaWriters(
          writeRows: (prepared) async => [
            for (final p in prepared)
              (await MediaRepository().createMedia(p.item)).id,
          ],
          insertNetwork: (_) async => const [],
          unlink: (_) async {},
          replace: (_, _, _) async {},
          drainDeletes: () async {},
          enqueueUpload: (_) {},
        ),
        cardId: 'media',
      );
      holdDocumentLinks(
        session,
        container.read,
        owner: const DocumentOwner(DocumentOwnerKind.site, 's1'),
        cardId: 'documents',
      );
      addMediaToSitting(session, [
        HeldMediaRow((item: attachment('held-1'), enrichment: null)),
      ]);
      attachDocument(session, doc);

      await SiteEditSaveService(SiteRepository()).save(
        siteId: 's1',
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        alsoWrite: session.runHeldWrites,
        alsoWriteIsAChange: session.hasHeldChanges,
      );

      expect((await MediaRepository().getMediaById('held-1'))?.siteId, 's1');
      expect(
        (await DocumentRepository().getById(doc.id))!.owner,
        const DocumentOwner(DocumentOwnerKind.site, 's1'),
      );
      await ChangeLogRepository().settleAll();
      final ops = await db
          .customSelect('SELECT label FROM change_log_operations')
          .get();
      expect(ops, hasLength(1));
      expect(ops.single.data['label'], contains('dive_sites:s1'));
    });
  });
}
