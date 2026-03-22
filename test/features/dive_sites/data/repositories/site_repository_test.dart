import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/performance_data_generator.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late SiteRepository repository;
  late SpeciesRepository speciesRepository;
  late MediaRepository mediaRepository;
  late db.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
    speciesRepository = SpeciesRepository();
    mediaRepository = MediaRepository();
    database = DatabaseService.instance.database;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('SiteRepository', () {
    group('createSite', () {
      test(
        'should create a new site with generated ID when ID is empty',
        () async {
          const site = DiveSite(
            id: '',
            name: 'Test Reef',
            description: 'A beautiful reef',
            country: 'Australia',
            region: 'Great Barrier Reef',
          );

          final createdSite = await repository.createSite(site);

          expect(createdSite.id, isNotEmpty);
          expect(createdSite.name, equals('Test Reef'));
          expect(createdSite.description, equals('A beautiful reef'));
          expect(createdSite.country, equals('Australia'));
          expect(createdSite.region, equals('Great Barrier Reef'));
        },
      );

      test('should create a site with provided ID', () async {
        const site = DiveSite(id: 'custom-id-123', name: 'Custom Site');

        final createdSite = await repository.createSite(site);

        expect(createdSite.id, equals('custom-id-123'));
        expect(createdSite.name, equals('Custom Site'));
      });

      test('should create a site with coordinates', () async {
        const site = DiveSite(
          id: '',
          name: 'GPS Site',
          location: GeoPoint(-16.9186, 145.7781),
        );

        final createdSite = await repository.createSite(site);
        final fetchedSite = await repository.getSiteById(createdSite.id);

        expect(fetchedSite, isNotNull);
        expect(fetchedSite!.location, isNotNull);
        expect(fetchedSite.location!.latitude, closeTo(-16.9186, 0.0001));
        expect(fetchedSite.location!.longitude, closeTo(145.7781, 0.0001));
      });

      test('should create a site with all fields', () async {
        const site = DiveSite(
          id: '',
          name: 'Complete Site',
          description: 'Full description',
          location: GeoPoint(25.0, -80.0),
          maxDepth: 30.0,
          country: 'USA',
          region: 'Florida Keys',
          rating: 4.5,
          notes: 'Great for beginners',
        );

        final createdSite = await repository.createSite(site);
        final fetchedSite = await repository.getSiteById(createdSite.id);

        expect(fetchedSite, isNotNull);
        expect(fetchedSite!.name, equals('Complete Site'));
        expect(fetchedSite.description, equals('Full description'));
        expect(fetchedSite.maxDepth, equals(30.0));
        expect(fetchedSite.country, equals('USA'));
        expect(fetchedSite.region, equals('Florida Keys'));
        expect(fetchedSite.rating, equals(4.5));
        expect(fetchedSite.notes, equals('Great for beginners'));
      });
    });

    group('getSiteById', () {
      test('should return site when found', () async {
        final site = await repository.createSite(
          const DiveSite(id: '', name: 'Find Me Site'),
        );

        final result = await repository.getSiteById(site.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Find Me Site'));
      });

      test('should return null when site not found', () async {
        final result = await repository.getSiteById('non-existent-id');

        expect(result, isNull);
      });
    });

    group('getAllSites', () {
      test('should return empty list when no sites exist', () async {
        final result = await repository.getAllSites();

        expect(result, isEmpty);
      });

      test('should return all sites ordered by name', () async {
        await repository.createSite(const DiveSite(id: '', name: 'Zebra Reef'));
        await repository.createSite(
          const DiveSite(id: '', name: 'Alpha Point'),
        );
        await repository.createSite(const DiveSite(id: '', name: 'Manta Bay'));

        final result = await repository.getAllSites();

        expect(result.length, equals(3));
        expect(result[0].name, equals('Alpha Point'));
        expect(result[1].name, equals('Manta Bay'));
        expect(result[2].name, equals('Zebra Reef'));
      });
    });

    group('updateSite', () {
      test('should update site fields', () async {
        final site = await repository.createSite(
          const DiveSite(
            id: '',
            name: 'Original Name',
            description: 'Original description',
          ),
        );

        final updatedSite = site.copyWith(
          name: 'Updated Name',
          description: 'Updated description',
          maxDepth: 25.0,
        );

        await repository.updateSite(updatedSite);
        final result = await repository.getSiteById(site.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Updated Name'));
        expect(result.description, equals('Updated description'));
        expect(result.maxDepth, equals(25.0));
      });

      test('should update site coordinates', () async {
        final site = await repository.createSite(
          const DiveSite(id: '', name: 'Moving Site'),
        );

        final updatedSite = site.copyWith(location: const GeoPoint(10.0, 20.0));

        await repository.updateSite(updatedSite);
        final result = await repository.getSiteById(site.id);

        expect(result!.location, isNotNull);
        expect(result.location!.latitude, equals(10.0));
        expect(result.location!.longitude, equals(20.0));
      });
    });

    group('deleteSite', () {
      test('should delete existing site', () async {
        final site = await repository.createSite(
          const DiveSite(id: '', name: 'To Be Deleted'),
        );

        await repository.deleteSite(site.id);
        final result = await repository.getSiteById(site.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent site', () async {
        await expectLater(repository.deleteSite('non-existent-id'), completes);
      });
    });

    group('mergeSites', () {
      test(
        'should update survivor, re-link dependent records, union expected species, and delete duplicates',
        () async {
          final site1 = await repository.createSite(
            const DiveSite(
              id: 'site-1',
              name: 'Siet',
              description: 'Original description',
            ),
          );
          final site2 = await repository.createSite(
            const DiveSite(
              id: 'site-2',
              name: 'Site',
              country: 'Belize',
              region: 'Turneffe',
              location: GeoPoint(17.288, -87.812),
            ),
          );
          final site3 = await repository.createSite(
            const DiveSite(
              id: 'site-3',
              name: 'Site Prime',
              notes: 'Bring SMB',
            ),
          );

          await _insertDive(database, id: 'dive-1', siteId: site2.id);
          await _insertDive(database, id: 'dive-2', siteId: site3.id);

          await mediaRepository.createMedia(
            _testMedia(id: 'media-1', siteId: site2.id),
          );
          await mediaRepository.createMedia(
            _testMedia(id: 'media-2', siteId: site3.id),
          );

          final turtle = await speciesRepository.createSpecies(
            commonName: 'Green Sea Turtle',
            category: SpeciesCategory.turtle,
          );
          final ray = await speciesRepository.createSpecies(
            commonName: 'Spotted Eagle Ray',
            category: SpeciesCategory.fish,
          );
          final shark = await speciesRepository.createSpecies(
            commonName: 'Nurse Shark',
            category: SpeciesCategory.fish,
          );

          await speciesRepository.addExpectedSpecies(
            siteId: site1.id,
            speciesId: turtle.id,
          );
          await speciesRepository.addExpectedSpecies(
            siteId: site2.id,
            speciesId: ray.id,
            notes: 'Seen near mooring',
          );
          await speciesRepository.addExpectedSpecies(
            siteId: site3.id,
            speciesId: ray.id,
          );
          await speciesRepository.addExpectedSpecies(
            siteId: site3.id,
            speciesId: shark.id,
          );

          final mergedSite = site1.copyWith(
            name: 'Site',
            country: 'Belize',
            region: 'Turneffe',
            location: const GeoPoint(17.288, -87.812),
            notes: 'Bring SMB',
          );

          await repository.mergeSites(
            mergedSite: mergedSite,
            siteIds: [site1.id, site2.id, site3.id],
          );

          final survivor = await repository.getSiteById(site1.id);
          final removed2 = await repository.getSiteById(site2.id);
          final removed3 = await repository.getSiteById(site3.id);

          expect(survivor, isNotNull);
          expect(survivor!.name, equals('Site'));
          expect(survivor.country, equals('Belize'));
          expect(survivor.region, equals('Turneffe'));
          expect(survivor.location, equals(const GeoPoint(17.288, -87.812)));
          expect(survivor.notes, equals('Bring SMB'));
          expect(removed2, isNull);
          expect(removed3, isNull);

          final diveRows = await (database.select(
            database.dives,
          )..where((t) => t.id.isIn(['dive-1', 'dive-2']))).get();
          expect(diveRows.map((row) => row.siteId).toSet(), equals({site1.id}));

          final relinkedMedia1 = await mediaRepository.getMediaById('media-1');
          final relinkedMedia2 = await mediaRepository.getMediaById('media-2');
          expect(relinkedMedia1!.siteId, equals(site1.id));
          expect(relinkedMedia2!.siteId, equals(site1.id));

          final expectedSpecies = await speciesRepository
              .getExpectedSpeciesForSite(site1.id);
          expect(
            expectedSpecies.map((entry) => entry.speciesId).toSet(),
            equals({turtle.id, ray.id, shark.id}),
          );
          expect(
            expectedSpecies.where((entry) => entry.speciesId == ray.id),
            hasLength(1),
          );
          expect(
            expectedSpecies
                .firstWhere((entry) => entry.speciesId == ray.id)
                .notes,
            equals('Seen near mooring'),
          );

          expect(
            await speciesRepository.getExpectedSpeciesForSite(site2.id),
            isEmpty,
          );
          expect(
            await speciesRepository.getExpectedSpeciesForSite(site3.id),
            isEmpty,
          );
        },
      );
    });

    group('getSitesByIds', () {
      test('should return matching sites', () async {
        await repository.createSite(const DiveSite(id: 'a', name: 'Alpha'));
        await repository.createSite(const DiveSite(id: 'b', name: 'Bravo'));
        await repository.createSite(const DiveSite(id: 'c', name: 'Charlie'));

        final results = await repository.getSitesByIds(['a', 'c']);

        expect(results.length, equals(2));
        expect(results.map((s) => s.id).toSet(), equals({'a', 'c'}));
      });

      test('should return empty list for empty input', () async {
        final results = await repository.getSitesByIds([]);
        expect(results, isEmpty);
      });
    });

    group('bulkDeleteSites', () {
      test('should delete multiple sites', () async {
        await repository.createSite(const DiveSite(id: 'x', name: 'X Site'));
        await repository.createSite(const DiveSite(id: 'y', name: 'Y Site'));
        await repository.createSite(const DiveSite(id: 'z', name: 'Z Site'));

        await repository.bulkDeleteSites(['x', 'z']);

        expect(await repository.getSiteById('x'), isNull);
        expect(await repository.getSiteById('y'), isNotNull);
        expect(await repository.getSiteById('z'), isNull);
      });

      test('should no-op for empty list', () async {
        await repository.createSite(
          const DiveSite(id: 'keep', name: 'Keep Me'),
        );

        await repository.bulkDeleteSites([]);

        expect(await repository.getSiteById('keep'), isNotNull);
      });
    });

    group('mergeSites - edge cases', () {
      test('should no-op when fewer than 2 site IDs', () async {
        final site = await repository.createSite(
          const DiveSite(id: 'only', name: 'Only Site'),
        );

        await repository.mergeSites(
          mergedSite: site.copyWith(name: 'Renamed'),
          siteIds: ['only'],
        );

        final result = await repository.getSiteById('only');
        expect(result!.name, equals('Only Site'));
      });

      test('should no-op when all IDs are duplicates of one', () async {
        final site = await repository.createSite(
          const DiveSite(id: 'dup', name: 'Dup Site'),
        );

        await repository.mergeSites(
          mergedSite: site.copyWith(name: 'Renamed'),
          siteIds: ['dup', 'dup', 'dup'],
        );

        final result = await repository.getSiteById('dup');
        expect(result!.name, equals('Dup Site'));
      });

      test('should merge two sites with no dives, media, or species', () async {
        await repository.createSite(
          const DiveSite(id: 'site-a', name: 'Site A'),
        );
        await repository.createSite(
          const DiveSite(id: 'site-b', name: 'Site B', country: 'Mexico'),
        );

        await repository.mergeSites(
          mergedSite: const DiveSite(id: '', name: 'Merged', country: 'Mexico'),
          siteIds: ['site-a', 'site-b'],
        );

        final survivor = await repository.getSiteById('site-a');
        expect(survivor, isNotNull);
        expect(survivor!.name, equals('Merged'));
        expect(survivor.country, equals('Mexico'));
        expect(await repository.getSiteById('site-b'), isNull);
      });

      test(
        'should merge expected species when primary already on survivor (note update only)',
        () async {
          await repository.createSite(
            const DiveSite(id: 'ms-1', name: 'Main Site'),
          );
          await repository.createSite(
            const DiveSite(id: 'ms-2', name: 'Dupe Site'),
          );

          final species = await speciesRepository.createSpecies(
            commonName: 'Hammerhead',
            category: SpeciesCategory.fish,
          );

          // Add species to survivor with no notes
          await speciesRepository.addExpectedSpecies(
            siteId: 'ms-1',
            speciesId: species.id,
          );
          // Add same species to duplicate with notes
          await speciesRepository.addExpectedSpecies(
            siteId: 'ms-2',
            speciesId: species.id,
            notes: 'Seen at cleaning station',
          );

          await repository.mergeSites(
            mergedSite: const DiveSite(id: '', name: 'Main Site'),
            siteIds: ['ms-1', 'ms-2'],
          );

          final expected = await speciesRepository.getExpectedSpeciesForSite(
            'ms-1',
          );
          expect(expected, hasLength(1));
          expect(expected.first.notes, equals('Seen at cleaning station'));
        },
      );

      test('should handle merge with dives but no media', () async {
        await repository.createSite(
          const DiveSite(id: 'dm-1', name: 'Site One'),
        );
        await repository.createSite(
          const DiveSite(id: 'dm-2', name: 'Site Two'),
        );

        await _insertDive(database, id: 'dive-a', siteId: 'dm-2');

        await repository.mergeSites(
          mergedSite: const DiveSite(id: '', name: 'Site One'),
          siteIds: ['dm-1', 'dm-2'],
        );

        final diveRows = await (database.select(
          database.dives,
        )..where((t) => t.id.equals('dive-a'))).get();
        expect(diveRows.first.siteId, equals('dm-1'));
        expect(await repository.getSiteById('dm-2'), isNull);
      });

      test('should handle merge with media but no dives', () async {
        await repository.createSite(
          const DiveSite(id: 'mm-1', name: 'Media Site A'),
        );
        await repository.createSite(
          const DiveSite(id: 'mm-2', name: 'Media Site B'),
        );

        await mediaRepository.createMedia(
          _testMedia(id: 'med-1', siteId: 'mm-2'),
        );

        await repository.mergeSites(
          mergedSite: const DiveSite(id: '', name: 'Media Site A'),
          siteIds: ['mm-1', 'mm-2'],
        );

        final relinkedMedia = await mediaRepository.getMediaById('med-1');
        expect(relinkedMedia!.siteId, equals('mm-1'));
        expect(await repository.getSiteById('mm-2'), isNull);
      });
    });

    group('undoMerge', () {
      test(
        'should fully reverse a merge including sites, dives, media, and species',
        () async {
          final site1 = await repository.createSite(
            const DiveSite(
              id: 'undo-1',
              name: 'Original Alpha',
              country: 'Mexico',
            ),
          );
          final site2 = await repository.createSite(
            const DiveSite(
              id: 'undo-2',
              name: 'Original Beta',
              country: 'Belize',
            ),
          );

          await _insertDive(database, id: 'undo-dive-1', siteId: 'undo-2');
          await mediaRepository.createMedia(
            _testMedia(id: 'undo-media-1', siteId: 'undo-2'),
          );

          final turtle = await speciesRepository.createSpecies(
            commonName: 'Loggerhead',
            category: SpeciesCategory.turtle,
          );
          await speciesRepository.addExpectedSpecies(
            siteId: 'undo-1',
            speciesId: turtle.id,
          );
          await speciesRepository.addExpectedSpecies(
            siteId: 'undo-2',
            speciesId: turtle.id,
            notes: 'Common here',
          );

          final snapshot = await repository.mergeSites(
            mergedSite: site1.copyWith(
              name: 'Merged Result',
              country: 'Belize',
            ),
            siteIds: [site1.id, site2.id],
          );

          // Verify merge happened
          expect(await repository.getSiteById('undo-2'), isNull);
          final merged = await repository.getSiteById('undo-1');
          expect(merged!.name, equals('Merged Result'));

          // Undo the merge
          await repository.undoMerge(snapshot!);

          // Verify sites restored
          final restored1 = await repository.getSiteById('undo-1');
          final restored2 = await repository.getSiteById('undo-2');
          expect(restored1, isNotNull);
          expect(restored1!.name, equals('Original Alpha'));
          expect(restored1.country, equals('Mexico'));
          expect(restored2, isNotNull);
          expect(restored2!.name, equals('Original Beta'));
          expect(restored2.country, equals('Belize'));

          // Verify dive re-linked back
          final diveRows = await (database.select(
            database.dives,
          )..where((t) => t.id.equals('undo-dive-1'))).get();
          expect(diveRows.first.siteId, equals('undo-2'));

          // Verify media re-linked back
          final media = await mediaRepository.getMediaById('undo-media-1');
          expect(media!.siteId, equals('undo-2'));

          // Verify species restored to both sites
          final species1 = await speciesRepository.getExpectedSpeciesForSite(
            'undo-1',
          );
          final species2 = await speciesRepository.getExpectedSpeciesForSite(
            'undo-2',
          );
          expect(species1, hasLength(1));
          expect(species2, hasLength(1));
          expect(species2.first.notes, equals('Common here'));
        },
      );

      test('should return snapshot with correct structure', () async {
        await repository.createSite(
          const DiveSite(id: 'snap-1', name: 'Snap A'),
        );
        await repository.createSite(
          const DiveSite(id: 'snap-2', name: 'Snap B'),
        );
        await repository.createSite(
          const DiveSite(id: 'snap-3', name: 'Snap C'),
        );

        await _insertDive(database, id: 'snap-dive', siteId: 'snap-2');

        final snapshot = await repository.mergeSites(
          mergedSite: const DiveSite(id: '', name: 'Snap A'),
          siteIds: ['snap-1', 'snap-2', 'snap-3'],
        );

        expect(snapshot, isNotNull);
        expect(snapshot!.originalSurvivor.name, equals('Snap A'));
        expect(snapshot.deletedSites.length, equals(2));
        expect(
          snapshot.deletedSites.map((s) => s.id).toSet(),
          equals({'snap-2', 'snap-3'}),
        );
        expect(snapshot.diveOriginalSiteIds, equals({'snap-dive': 'snap-2'}));
      });

      test('should return null for no-op merge', () async {
        await repository.createSite(const DiveSite(id: 'noop', name: 'Solo'));

        final snapshot = await repository.mergeSites(
          mergedSite: const DiveSite(id: '', name: 'Solo'),
          siteIds: ['noop'],
        );

        expect(snapshot, isNull);
      });
    });

    group('searchSites', () {
      setUp(() async {
        await repository.createSite(
          const DiveSite(
            id: '',
            name: 'Blue Hole',
            country: 'Belize',
            region: 'Lighthouse Reef',
          ),
        );
        await repository.createSite(
          const DiveSite(
            id: '',
            name: 'Great White Wall',
            country: 'Fiji',
            region: 'Taveuni',
          ),
        );
        await repository.createSite(
          const DiveSite(
            id: '',
            name: 'Coral Garden',
            country: 'Indonesia',
            region: 'Bali',
          ),
        );
      });

      test('should find sites by name', () async {
        final results = await repository.searchSites('Blue');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Blue Hole'));
      });

      test('should find sites by country', () async {
        final results = await repository.searchSites('Fiji');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Great White Wall'));
      });

      test('should find sites by region', () async {
        final results = await repository.searchSites('Bali');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Coral Garden'));
      });

      test('should return empty list for no matches', () async {
        final results = await repository.searchSites('NonExistent');

        expect(results, isEmpty);
      });

      test('should be case insensitive', () async {
        final results = await repository.searchSites('blue');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Blue Hole'));
      });
    });

    group('getDiveCountsBySite', () {
      test('should return empty map when no dives exist', () async {
        await repository.createSite(
          const DiveSite(id: 'site-1', name: 'Empty Site'),
        );

        final counts = await repository.getDiveCountsBySite();

        expect(counts, isEmpty);
      });
    });

    group('getSitesWithDiveCounts', () {
      test(
        'should return sites with zero counts when no dives exist',
        () async {
          await repository.createSite(const DiveSite(id: '', name: 'Site A'));
          await repository.createSite(const DiveSite(id: '', name: 'Site B'));

          final results = await repository.getSitesWithDiveCounts();

          expect(results.length, equals(2));
          expect(results[0].diveCount, equals(0));
          expect(results[1].diveCount, equals(0));
        },
      );
    });
  });

  group('Performance smoke tests (light preset)', () {
    late GeneratedDataSummary summary;

    setUp(() async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      summary = await generator.generate();
    });

    test('getAllSites loads in under 50ms', () async {
      PerfTimer.reset();
      await repository.getAllSites(diverId: summary.diverId);
      final duration = PerfTimer.lastResult('getAllSites');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, lessThan(50));
    });

    test('getSitesWithDiveCounts loads in under 100ms', () async {
      PerfTimer.reset();
      await repository.getSitesWithDiveCounts(diverId: summary.diverId);
      final duration = PerfTimer.lastResult('getSitesWithDiveCounts');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, lessThan(100));
    });

    test('searchSites returns in under 50ms', () async {
      PerfTimer.reset();
      await repository.searchSites('reef', diverId: summary.diverId);
      final duration = PerfTimer.lastResult('searchSites');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, lessThan(50));
    });
  });
}

Future<void> _insertDive(
  db.AppDatabase database, {
  required String id,
  required String siteId,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          siteId: Value(siteId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

MediaItem _testMedia({required String id, required String siteId}) {
  final now = DateTime.now();
  return MediaItem(
    id: id,
    siteId: siteId,
    filePath: '/tmp/$id.jpg',
    mediaType: MediaType.photo,
    takenAt: now,
    createdAt: now,
    updatedAt: now,
  );
}
