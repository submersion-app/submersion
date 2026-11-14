import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/library_site_catalogue.dart';
import 'package:submersion/core/services/shared_library/library_site_notes.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/site_detacher.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_bridge.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A shared library site's row never enters the personal sync, so the
/// catalogue link and answers a profile gives it travel in that profile's
/// library_site_notes record, as its private notes and rating do.
void main() {
  const answers = SiteCatalogueAnswers(notSame: {'r9'});
  final answersText = answers.encode();

  Future<void> diver(String id) => DiverRepository().createDiver(
    Diver(
      id: id,
      name: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  Future<void> member(String diverId, {String memberId = 'm'}) async {
    final store = SharedLibraryStore();
    await store.upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Survey',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
        roles: SharedLibraryRoles(editors: {'m', 'm2'}),
      ),
    );
    await store.upsertMembership(
      SharedLibraryMembership(
        id: 'ms-$diverId',
        diverId: diverId,
        libraryId: 'L',
        memberId: memberId,
        displayName: diverId,
        libraryName: 'Reef Survey',
        backendKind: 's3',
      ),
    );
  }

  Future<void> librarySite({String notes = '', double? rating}) =>
      SiteRepository().createSite(
        DiveSite(
          id: 's',
          name: 'Thistlegorm',
          location: const GeoPoint(27.8138, 33.92),
          sharedLibraryId: 'L',
          notes: notes,
          rating: rating,
        ),
      );

  Future<({String? link, String? answers, String notes, double? rating})?>
  record(String diverId) async {
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.librarySiteNotes,
    )..where((t) => t.id.equals('$diverId:s'))).getSingleOrNull();
    return row == null
        ? null
        : (
            link: row.catalogueId,
            answers: row.catalogueAnswers,
            notes: row.notes,
            rating: row.rating,
          );
  }

  Future<void> put(
    String diverId, {
    required String? link,
    required String? answers,
  }) => putLibrarySiteCatalogue(
    DatabaseService.instance.database,
    SyncRepository(),
    diverId: diverId,
    siteId: 's',
    catalogueId: link,
    catalogueAnswers: answers,
  );

  setUp(() async {
    await setUpTestDatabase();
    await diver('d1');
  });

  tearDown(tearDownTestDatabase);

  group('keeping them for the profile', () {
    test('a new record starts from the notes and rating on the row', () async {
      await member('d1');
      await librarySite(notes: 'surge at the stern', rating: 4);

      await put('d1', link: 'r1', answers: answersText);

      final kept = (await record('d1'))!;
      expect(kept.link, 'r1');
      expect(kept.answers, answersText);
      expect(kept.notes, 'surge at the stern');
      expect(kept.rating, 4);
    });

    test("another profile's notes on the row are not taken up", () async {
      await member('d1');
      await diver('d2');
      await member('d2', memberId: 'm2');
      await librarySite();
      // d1's private notes: on the row, and in d1's own record.
      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's',
        notes: 'd1 keeps this to themselves',
        rating: 5,
      );
      await applyLibrarySiteNotes(DatabaseService.instance.database);

      await put('d2', link: 'r1', answers: null);

      final kept = (await record('d2'))!;
      expect(kept.link, 'r1');
      expect(kept.notes, '');
      expect(kept.rating, isNull);
    });

    test('the record is marked for personal sync', () async {
      await member('d1');
      await librarySite();

      await put('d1', link: 'r1', answers: null);

      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.where(
          (r) =>
              r.entityType == SharedLibraryStore.siteNotesEntity &&
              r.recordId == 'd1:s',
        ),
        hasLength(1),
      );
    });

    test('a second call changes the two columns and nothing else', () async {
      await member('d1');
      await librarySite();
      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's',
        notes: 'park by the pier',
        rating: 5,
      );

      await put('d1', link: 'r1', answers: answersText);

      final kept = (await record('d1'))!;
      expect(kept.link, 'r1');
      expect(kept.notes, 'park by the pier');
      expect(kept.rating, 5);
    });

    test('a later edit of the notes leaves the link and answers', () async {
      await member('d1');
      await librarySite();
      await put('d1', link: 'r1', answers: answersText);

      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's',
        notes: 'new notes',
        rating: null,
      );

      final kept = (await record('d1'))!;
      expect(kept.notes, 'new notes');
      expect(kept.link, 'r1');
      expect(kept.answers, answersText);
    });

    test('the stamper keeps them for the acting profile', () async {
      await member('d1');
      await librarySite();

      await LibraryEditStamper().keepCatalogue(
        's',
        catalogueId: 'r1',
        answers: answers,
        actingDiverId: 'd1',
      );

      expect((await record('d1'))!.link, 'r1');
      expect((await record('d1'))!.answers, answersText);
    });

    test('with no profile named, the sole member is the one', () async {
      await member('d1');
      await librarySite();

      await LibraryEditStamper().keepCatalogue(
        's',
        catalogueId: 'r1',
        answers: SiteCatalogueAnswers.empty,
      );

      expect((await record('d1'))!.link, 'r1');
    });

    test('with no profile named and two members, nothing is kept', () async {
      await member('d1');
      await diver('d2');
      await member('d2', memberId: 'm2');
      await librarySite();

      await LibraryEditStamper().keepCatalogue(
        's',
        catalogueId: 'r1',
        answers: SiteCatalogueAnswers.empty,
      );

      expect(await record('d1'), isNull);
      expect(await record('d2'), isNull);
    });

    test('a personal site keeps nothing here', () async {
      await SiteRepository().createSite(
        const DiveSite(id: 's', name: 'Mine', diverId: 'd1'),
      );

      await LibraryEditStamper().keepCatalogue(
        's',
        catalogueId: 'r1',
        answers: answers,
        actingDiverId: 'd1',
      );

      expect(await record('d1'), isNull);
    });
  });

  group('reaching the row on another device', () {
    Future<DiveSite> afterApply() async {
      await applyLibrarySiteNotes(DatabaseService.instance.database);
      return (await SiteRepository().getSiteById('s'))!;
    }

    test('a record\'s link and answers are copied onto the row', () async {
      await member('d1');
      await librarySite();
      // As personal sync brings them from the profile's other device.
      await put('d1', link: 'r1', answers: answersText);

      final site = await afterApply();

      expect(site.catalogueId, 'r1');
      expect(site.catalogueAnswers, answers);
    });

    test('a record with notes only clears neither', () async {
      await member('d1');
      await SiteRepository().createSite(
        const DiveSite(
          id: 's',
          name: 'Thistlegorm',
          sharedLibraryId: 'L',
          catalogueId: 'r1',
          catalogueAnswers: answers,
        ),
      );
      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's',
        notes: 'from the tablet',
        rating: 3,
      );

      final site = await afterApply();

      expect(site.notes, 'from the tablet');
      expect(site.catalogueId, 'r1');
      expect(site.catalogueAnswers, answers);
    });

    test(
      'a newer record without a link does not hide an older one\'s',
      () async {
        await member('d1');
        await diver('d2');
        await member('d2', memberId: 'm2');
        await librarySite();
        await put('d1', link: 'r1', answers: answersText);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await SharedLibraryStore().putSiteNotes(
          diverId: 'd2',
          siteId: 's',
          notes: 'd2 notes',
          rating: null,
        );

        final site = await afterApply();

        expect(site.notes, 'd2 notes');
        expect(site.catalogueId, 'r1');
        expect(site.catalogueAnswers, answers);
      },
    );

    test("a profile's link does not hide another profile's notes", () async {
      await member('d1');
      await diver('d2');
      await member('d2', memberId: 'm2');
      await librarySite();
      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's',
        notes: 'd1 notes',
        rating: 5,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // d2 links the site. Their record is the newest, and it says nothing
      // about notes: it exists for the link alone.
      await put('d2', link: 'r1', answers: null);

      final site = await afterApply();

      expect(site.notes, 'd1 notes');
      expect(site.rating, 5);
      expect(site.catalogueId, 'r1');
    });

    test('notes cleared by the only profile are still cleared here', () async {
      await member('d1');
      // As this device last knew the site.
      await librarySite(notes: 'out of date', rating: 2);
      // As personal sync brings the record: the notes cleared, a link kept.
      await SharedLibraryStore().putSiteNotes(
        diverId: 'd1',
        siteId: 's',
        notes: '',
        rating: null,
      );
      await put('d1', link: 'r1', answers: null);

      final site = await afterApply();

      expect(site.notes, '');
      expect(site.rating, isNull);
      expect(site.catalogueId, 'r1');
    });

    test('a personal site is never touched', () async {
      await SiteRepository().createSite(
        const DiveSite(id: 's', name: 'Mine', diverId: 'd1'),
      );
      await put('d1', link: 'r1', answers: answersText);

      final site = await afterApply();

      expect(site.catalogueId, isNull);
      expect(site.catalogueAnswers, SiteCatalogueAnswers.empty);
    });

    test('the record round-trips through personal sync', () async {
      await member('d1');
      await librarySite();
      await put('d1', link: 'r1', answers: answersText);
      final sent = (await SyncDataSerializer().fetchRecord(
        SharedLibraryStore.siteNotesEntity,
        'd1:s',
      ))!;
      expect(sent['catalogueId'], 'r1');
      expect(sent['catalogueAnswers'], answersText);

      // The other device: the diver and the library site, nothing else.
      await tearDownTestDatabase();
      await setUpTestDatabase();
      await diver('d1');
      await member('d1');
      await librarySite();
      await SyncDataSerializer().upsertRecord(
        SharedLibraryStore.siteNotesEntity,
        sent,
      );

      final site = await afterApply();
      expect(site.catalogueId, 'r1');
      expect(site.catalogueAnswers, answers);
    });
  });

  group('writes of this slice', () {
    const wreck = CatalogueSite(
      id: 'r1',
      name: 'SS Thistlegorm',
      location: GeoPoint(27.8138, 33.92),
      maxDepth: 32,
      description: 'Cargo ship, lost 1941',
      source: 'ukho',
    );

    test(
      'applying a pair keeps the link and answers for the profile',
      () async {
        await member('d1');
        await librarySite();

        await SiteCatalogueFillRepository().applyFill(
          siteId: 's',
          record: wreck,
          fields: {CatalogueGapField.depth},
          declined: {CatalogueGapField.description},
          actingDiverId: 'd1',
        );

        final site = (await SiteRepository().getSiteById('s'))!;
        expect(site.catalogueId, 'r1');
        expect(site.maxDepth, 32);
        final kept = (await record('d1'))!;
        expect(kept.link, 'r1');
        expect(SiteCatalogueAnswers.decode(kept.answers).declined, {
          'r1': {'description'},
        });
        // The depth is a shared field: it goes to the library.
        expect((await SharedLibraryStore().getSiteState('s'))?.dirty, isTrue);
      },
    );

    test('an answer is kept for the profile', () async {
      await member('d1');
      await librarySite();

      await SiteCatalogueFillRepository().updateAnswers(
        's',
        (current) => current.withNotSame('r1'),
        actingDiverId: 'd1',
      );

      expect(
        SiteCatalogueAnswers.decode((await record('d1'))!.answers).notSame,
        {'r1'},
      );
      // An answer is the profile's own: never a library edit.
      expect(
        (await SharedLibraryStore().getSiteState('s'))?.dirty,
        isNot(true),
      );
    });
  });

  test('a merge keeps what the surviving library site now claims', () async {
    await member('d1');
    await SiteRepository().createSite(
      const DiveSite(
        id: 's',
        name: 'Thistlegorm',
        sharedLibraryId: 'L',
        catalogueId: 'r1',
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(
        id: 'twin',
        name: 'SS Thistlegorm',
        sharedLibraryId: 'L',
        catalogueId: 'r2',
      ),
    );

    await SiteRepository().mergeSites(
      // The merge page hands over the survivor with its form's values: it
      // is still the library's site, and carries no link or answers.
      mergedSite: const DiveSite(
        id: 's',
        name: 'Thistlegorm',
        sharedLibraryId: 'L',
      ),
      siteIds: ['s', 'twin'],
      actingDiverId: 'd1',
    );

    final kept = (await record('d1'))!;
    expect(kept.link, 'r1');
    expect(SiteCatalogueAnswers.decode(kept.answers).also, {'r2'});
  });

  test('undoing that merge takes the claims back out of the record', () async {
    await member('d1');
    await SiteRepository().createSite(
      const DiveSite(
        id: 's',
        name: 'Thistlegorm',
        sharedLibraryId: 'L',
        catalogueId: 'r1',
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(
        id: 'twin',
        name: 'SS Thistlegorm',
        sharedLibraryId: 'L',
        catalogueId: 'r2',
      ),
    );
    final snapshot = await SiteRepository().mergeSites(
      mergedSite: const DiveSite(
        id: 's',
        name: 'Thistlegorm',
        sharedLibraryId: 'L',
      ),
      siteIds: ['s', 'twin'],
      actingDiverId: 'd1',
    );

    await SiteRepository().undoMerge(snapshot!);
    // As the next sync would: what the profile keeps is copied to the row.
    await applyLibrarySiteNotes(DatabaseService.instance.database);

    final site = (await SiteRepository().getSiteById('s'))!;
    expect(site.catalogueId, 'r1');
    expect(site.catalogueAnswers, SiteCatalogueAnswers.empty);
  });

  group('library paths that rewrite a row', () {
    Future<void> linkedRow() => SiteRepository().createSite(
      const DiveSite(
        id: 's',
        name: 'Thistlegorm',
        hazards: 'h',
        sharedLibraryId: 'L',
        catalogueId: 'r1',
        catalogueAnswers: answers,
      ),
    );

    test('a pulled document leaves the link and answers on the row', () async {
      await member('d1');
      await linkedRow();
      final doc = SiteDocument(
        id: 's',
        fields: const {'name': 'Thistlegorm', 'hazards': 'strong current'},
        clocks: {
          for (final f in SiteDocument.fieldNames)
            f: const FieldClock(hlc: Hlc(9, 0, 'm'), memberId: 'm'),
        },
      );

      await SiteDocumentBridge().apply(
        doc,
        libraryId: 'L',
        vocabularyDiverId: 'd1',
      );

      final site = (await SiteRepository().getSiteById('s'))!;
      expect(site.hazards, 'strong current');
      expect(site.catalogueId, 'r1');
      expect(site.catalogueAnswers, answers);
    });

    test('a site detached into a personal copy carries both', () async {
      await linkedRow();
      await SharedLibraryStore().putSiteState(
        const SharedSiteState(siteId: 's', libraryId: 'L'),
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'dv', diveNumber: 1).copyWith(
          site: const DiveSite(id: 's', name: 'Thistlegorm'),
        ),
      );

      final newId = await SiteDetacher().detachOrRemove(
        siteId: 's',
        ownerDiverId: 'd1',
      );

      final copy = (await SiteRepository().getSiteById(newId!))!;
      expect(copy.sharedLibraryId, isNull);
      expect(copy.catalogueId, 'r1');
      expect(copy.catalogueAnswers, answers);
    });
  });
}
