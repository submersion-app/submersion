import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveSitesCompanion;
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

const _record = CatalogueSite(
  id: 'r1',
  name: 'SS Thistlegorm',
  location: GeoPoint(27.8138, 33.9200),
  countryCode: 'EG',
  country: 'Egypt',
  region: 'Red Sea',
  locality: 'Sharm',
  island: 'Shag Rock',
  bodyOfWater: 'Red Sea',
  waterType: WaterType.salt,
  minDepth: 16,
  maxDepth: 32,
  typeIds: ['wreck'],
  entryMethods: [EntryMethod.boat],
  difficulty: SiteDifficulty.advanced,
  hazards: 'Current',
  description: 'Cargo ship, lost 1941',
  source: 'ukho',
);

/// A stamper that decides who may edit and records what it was told.
class _Stamper extends LibraryEditStamper {
  _Stamper({this.allow = true, this.keepFails = false});

  final bool allow;

  /// Whether keeping the link and answers for the profile fails.
  final bool keepFails;

  @override
  Future<void> keepCatalogue(
    String siteId, {
    required String? catalogueId,
    required SiteCatalogueAnswers answers,
    String? actingDiverId,
  }) {
    if (keepFails) throw StateError('disk full');
    return super.keepCatalogue(
      siteId,
      catalogueId: catalogueId,
      answers: answers,
      actingDiverId: actingDiverId,
    );
  }

  final List<({String siteId, Set<String> fields})> stamped = [];

  @override
  Future<bool> mayEdit(String siteId, {String? actingDiverId}) async => allow;

  @override
  Future<void> stamp(
    String siteId,
    Set<String> fields, {
    String? actingDiverId,
  }) async {
    stamped.add((siteId: siteId, fields: fields));
  }
}

void main() {
  late AppDatabase db;
  late SiteRepository sites;
  late SiteCatalogueFillRepository fills;

  setUp(() async {
    db = await setUpTestDatabase();
    sites = SiteRepository();
    fills = SiteCatalogueFillRepository();
    await seedDivers(db, ['d1']);
  });

  tearDown(tearDownTestDatabase);

  /// A site at the record's place with nothing else filled in.
  Future<void> seedBare({
    String id = 's1',
    String? link,
    GeoPoint? at = const GeoPoint(27.8138, 33.9200),
  }) => sites.createSite(
    DiveSite(
      id: id,
      diverId: 'd1',
      name: 'Thistlegorm',
      location: at,
      catalogueId: link,
      notes: 'Imported from Bundled dive site database',
      rating: 4,
      exitMethods: const [EntryMethod.boat],
    ),
  );

  Future<DiveSite> stored([String id = 's1']) async =>
      (await sites.getSiteById(id))!;

  Future<Set<String>> typesOf([String id = 's1']) async => {
    for (final t in await SiteClassificationRepository().getTypesForSite(id))
      t.id,
  };

  test('links the site and writes the chosen fields', () async {
    await seedBare();

    final write = await fills.applyFill(
      siteId: 's1',
      record: _record,
      fields: CatalogueGapField.values.toSet(),
      actingDiverId: 'd1',
    );

    expect(write.outcome, CatalogueFillOutcome.applied);
    expect(write.linked, isTrue);
    final site = await stored();
    expect(site.catalogueId, 'r1');
    expect(site.minDepth, 16);
    expect(site.maxDepth, 32);
    expect(site.country, 'Egypt');
    expect(site.countryCode, 'EG');
    expect(site.region, 'Red Sea');
    expect(site.city, 'Sharm');
    expect(site.island, 'Shag Rock');
    expect(site.bodyOfWater, 'Red Sea');
    expect(site.waterType, WaterType.salt);
    expect(site.entryMethods, [EntryMethod.boat]);
    expect(site.difficulty, SiteDifficulty.advanced);
    expect(site.hazards, 'Current');
    expect(site.description, 'Cargo ship, lost 1941');
    expect(await typesOf(), {'wreck'});
    // The site had a position: it is not a field that can be written.
    expect(
      write.filled,
      CatalogueGapField.values.toSet()..remove(CatalogueGapField.position),
    );
  });

  test('writes only the fields that were chosen', () async {
    await seedBare();

    final write = await fills.applyFill(
      siteId: 's1',
      record: _record,
      fields: {CatalogueGapField.depth},
      actingDiverId: 'd1',
    );

    expect(write.filled, {CatalogueGapField.depth});
    final site = await stored();
    expect(site.maxDepth, 32);
    expect(site.description, '');
    expect(site.hazards, isNull);
    expect(site.country, isNull);
    expect(await typesOf(), isEmpty);
  });

  test('never touches what the diver owns', () async {
    await seedBare();

    await fills.applyFill(
      siteId: 's1',
      record: _record,
      fields: CatalogueGapField.values.toSet(),
      actingDiverId: 'd1',
    );

    final site = await stored();
    expect(site.name, 'Thistlegorm');
    expect(site.notes, 'Imported from Bundled dive site database');
    expect(site.rating, 4);
    expect(site.exitMethods, [EntryMethod.boat]);
    expect(site.location, const GeoPoint(27.8138, 33.9200));
    expect(site.diverId, 'd1');
  });

  test('a value typed since the list loaded is not overwritten', () async {
    await seedBare();
    // The diver fills the depth and the description on another screen.
    await sites.applyImportedMetadata(
      's1',
      const DiveSitesCompanion(
        maxDepth: Value(30),
        description: Value('My notes on the wreck.'),
      ),
    );

    final write = await fills.applyFill(
      siteId: 's1',
      record: _record,
      fields: {
        CatalogueGapField.depth,
        CatalogueGapField.description,
        CatalogueGapField.hazards,
      },
      actingDiverId: 'd1',
    );

    expect(write.filled, {CatalogueGapField.hazards});
    final site = await stored();
    expect(site.maxDepth, 30);
    expect(site.minDepth, isNull);
    expect(site.description, 'My notes on the wreck.');
    expect(site.hazards, 'Current');
  });

  test('gives a position only to a site that has none', () async {
    await seedBare(at: null);

    final write = await fills.applyFill(
      siteId: 's1',
      record: _record,
      fields: {CatalogueGapField.position},
      actingDiverId: 'd1',
    );

    expect(write.filled, {CatalogueGapField.position});
    expect((await stored()).location, const GeoPoint(27.8138, 33.9200));
  });

  test('a sea name in the diver\'s language is written when given', () async {
    await seedBare();

    await fills.applyFill(
      siteId: 's1',
      record: _record,
      fields: {CatalogueGapField.bodyOfWater},
      bodyOfWater: 'Rotes Meer',
      actingDiverId: 'd1',
    );

    expect((await stored()).bodyOfWater, 'Rotes Meer');
  });

  test('site types are added only to a site that has none', () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        diverId: 'd1',
        name: 'Thistlegorm',
        location: GeoPoint(27.8138, 33.9200),
      ),
      classification: const SiteClassification(typeIds: ['reef']),
    );

    final write = await fills.applyFill(
      siteId: 's1',
      record: _record,
      fields: {CatalogueGapField.siteTypes},
      actingDiverId: 'd1',
    );

    expect(write.filled, isEmpty);
    expect(await typesOf(), {'reef'});
  });

  group('the link', () {
    test('is kept, and not set twice, on a site already linked', () async {
      await seedBare(link: 'r1');

      final write = await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: {CatalogueGapField.depth},
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.applied);
      expect(write.linked, isFalse);
      expect(write.filled, {CatalogueGapField.depth});
      expect((await stored()).catalogueId, 'r1');
    });

    test('a site linked to the record is filled though an older site '
        'is linked to it too', () async {
      // Two devices each adopted the record before they synced.
      await seedBare(id: 'older', link: 'r1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await seedBare(link: 'r1');

      final write = await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: {CatalogueGapField.depth},
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.applied);
      expect(write.filled, {CatalogueGapField.depth});
      expect((await stored()).maxDepth, 32);
    });

    test('a site linked to another record is left alone', () async {
      await seedBare(link: 'other');

      final write = await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: {CatalogueGapField.depth},
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.siteChanged);
      expect(write.filled, isEmpty);
      final site = await stored();
      expect(site.catalogueId, 'other');
      expect(site.maxDepth, isNull);
    });

    test('a record another site of the diver claims is skipped', () async {
      await seedBare();
      await seedBare(id: 's2', link: 'r1');

      final write = await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: {CatalogueGapField.depth},
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.claimedElsewhere);
      final site = await stored();
      expect(site.catalogueId, isNull);
      expect(site.maxDepth, isNull);
    });

    test('a record another site stands for is skipped too', () async {
      await seedBare();
      await sites.createSite(
        const DiveSite(
          id: 's2',
          diverId: 'd1',
          name: 'Merged',
          catalogueId: 'r9',
          catalogueAnswers: SiteCatalogueAnswers(also: {'r1'}),
        ),
      );

      final write = await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: const {},
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.claimedElsewhere);
    });

    test('linking with no fields chosen links and fills nothing', () async {
      await seedBare();

      final write = await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: const {},
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.applied);
      expect(write.linked, isTrue);
      expect(write.filled, isEmpty);
      final site = await stored();
      expect(site.catalogueId, 'r1');
      expect(site.maxDepth, isNull);
    });
  });

  test('fields turned down are remembered under the record', () async {
    await seedBare();

    await fills.applyFill(
      siteId: 's1',
      record: _record,
      fields: {CatalogueGapField.depth},
      declined: {CatalogueGapField.description, CatalogueGapField.hazards},
      actingDiverId: 'd1',
    );

    expect((await stored()).catalogueAnswers.declined, {
      'r1': {'description', 'hazards'},
    });
  });

  test('a site that is gone is reported, not created', () async {
    final write = await fills.applyFill(
      siteId: 'nope',
      record: _record,
      fields: {CatalogueGapField.depth},
      actingDiverId: 'd1',
    );

    expect(write.outcome, CatalogueFillOutcome.missing);
    expect(await sites.getAllSites(), isEmpty);
  });

  group('sync', () {
    test('the site is marked once for one fill', () async {
      await seedBare();
      await clearPendingMarks(db);

      await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: CatalogueGapField.values.toSet(),
        actingDiverId: 'd1',
      );

      expect(await pendingCount(db, 'diveSites', 's1'), 1);
    });

    test('a fill that changes nothing writes nothing', () async {
      await seedBare(link: 'r1');
      await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: CatalogueGapField.values.toSet(),
        actingDiverId: 'd1',
      );
      await clearPendingMarks(db);

      final write = await fills.applyFill(
        siteId: 's1',
        record: _record,
        fields: CatalogueGapField.values.toSet(),
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.applied);
      expect(write.linked, isFalse);
      expect(write.filled, isEmpty);
      expect(await pendingCount(db, 'diveSites', 's1'), 0);
    });
  });

  group('answers', () {
    test('an answer is written and the site marked for sync', () async {
      await seedBare();
      await clearPendingMarks(db);

      await fills.updateAnswers(
        's1',
        (current) => current.withNotSame('r1'),
        actingDiverId: 'd1',
      );

      expect((await stored()).catalogueAnswers.notSame, {'r1'});
      expect(await pendingCount(db, 'diveSites', 's1'), 1);
    });

    test('an answer that changes nothing writes nothing', () async {
      await seedBare();
      await fills.updateAnswers('s1', (current) => current.withNotSame('r1'));
      await clearPendingMarks(db);

      await fills.updateAnswers('s1', (current) => current.withNotSame('r1'));

      expect(await pendingCount(db, 'diveSites', 's1'), 0);
    });

    test('an answer for a site that is gone does nothing', () async {
      await fills.updateAnswers('nope', (current) => current.withNotSame('r1'));

      expect(await sites.getAllSites(), isEmpty);
    });
  });

  group('a shared library site', () {
    Future<void> seedLibrarySite() => sites.createSite(
      const DiveSite(
        id: 'club',
        name: 'Thistlegorm',
        location: GeoPoint(27.8138, 33.9200),
        sharedLibraryId: 'lib1',
      ),
    );

    test('that may be edited has its changed fields stamped', () async {
      await seedLibrarySite();
      final stamper = _Stamper();
      fills = SiteCatalogueFillRepository(stamper: stamper);

      final write = await fills.applyFill(
        siteId: 'club',
        record: _record,
        fields: {CatalogueGapField.depth, CatalogueGapField.siteTypes},
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.applied);
      expect(stamper.stamped.single.siteId, 'club');
      expect(
        stamper.stamped.single.fields,
        containsAll(['minDepth', 'maxDepth', 'siteTypes']),
      );
      expect(stamper.stamped.single.fields, isNot(contains('description')));
    });

    test('that may not be edited takes no answer either', () async {
      await seedLibrarySite();
      fills = SiteCatalogueFillRepository(stamper: _Stamper(allow: false));
      await clearPendingMarks(db);

      final written = await fills.updateAnswers(
        'club',
        (current) => current.withNotSame('r1'),
        actingDiverId: 'd1',
      );

      // Said, so an editing sitting can refuse the Save.
      expect(written, isFalse);

      expect(
        (await stored('club')).catalogueAnswers,
        SiteCatalogueAnswers.empty,
      );
      expect(await pendingCount(db, 'diveSites', 'club'), 0);
    });

    test(
      'is not linked when its link cannot be kept for the profile',
      () async {
        await seedLibrarySite();
        fills = SiteCatalogueFillRepository(stamper: _Stamper(keepFails: true));

        await expectLater(
          fills.applyFill(
            siteId: 'club',
            record: _record,
            fields: {CatalogueGapField.depth},
            actingDiverId: 'd1',
          ),
          throwsStateError,
        );

        // The row and the profile's record are written together or not at
        // all: a link only this device knows would never reach the others.
        final site = await stored('club');
        expect(site.catalogueId, isNull);
        expect(site.maxDepth, isNull);
      },
    );

    test(
      'takes no answer when the answer cannot be kept for the profile',
      () async {
        await seedLibrarySite();
        fills = SiteCatalogueFillRepository(stamper: _Stamper(keepFails: true));

        await expectLater(
          fills.updateAnswers(
            'club',
            (current) => current.withNotSame('r1'),
            actingDiverId: 'd1',
          ),
          throwsStateError,
        );

        expect(
          (await stored('club')).catalogueAnswers,
          SiteCatalogueAnswers.empty,
        );
      },
    );

    test('that may not be edited is left alone', () async {
      await seedLibrarySite();
      final stamper = _Stamper(allow: false);
      fills = SiteCatalogueFillRepository(stamper: stamper);

      final write = await fills.applyFill(
        siteId: 'club',
        record: _record,
        fields: {CatalogueGapField.depth},
        actingDiverId: 'd1',
      );

      expect(write.outcome, CatalogueFillOutcome.notEditable);
      final site = await stored('club');
      expect(site.catalogueId, isNull);
      expect(site.maxDepth, isNull);
      expect(stamper.stamped, isEmpty);
    });
  });
}
