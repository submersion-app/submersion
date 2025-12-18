import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SiteRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('SiteRepository', () {
    group('createSite', () {
      test('should create a new site with generated ID when ID is empty', () async {
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
      });

      test('should create a site with provided ID', () async {
        const site = DiveSite(
          id: 'custom-id-123',
          name: 'Custom Site',
        );

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
        final site = await repository.createSite(const DiveSite(
          id: '',
          name: 'Find Me Site',
        ),);

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
        await repository.createSite(const DiveSite(id: '', name: 'Alpha Point'));
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
        final site = await repository.createSite(const DiveSite(
          id: '',
          name: 'Original Name',
          description: 'Original description',
        ),);

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
        final site = await repository.createSite(const DiveSite(
          id: '',
          name: 'Moving Site',
        ),);

        final updatedSite = site.copyWith(
          location: const GeoPoint(10.0, 20.0),
        );

        await repository.updateSite(updatedSite);
        final result = await repository.getSiteById(site.id);

        expect(result!.location, isNotNull);
        expect(result.location!.latitude, equals(10.0));
        expect(result.location!.longitude, equals(20.0));
      });
    });

    group('deleteSite', () {
      test('should delete existing site', () async {
        final site = await repository.createSite(const DiveSite(
          id: '',
          name: 'To Be Deleted',
        ),);

        await repository.deleteSite(site.id);
        final result = await repository.getSiteById(site.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent site', () async {
        await expectLater(
          repository.deleteSite('non-existent-id'),
          completes,
        );
      });
    });

    group('searchSites', () {
      setUp(() async {
        await repository.createSite(const DiveSite(
          id: '',
          name: 'Blue Hole',
          country: 'Belize',
          region: 'Lighthouse Reef',
        ),);
        await repository.createSite(const DiveSite(
          id: '',
          name: 'Great White Wall',
          country: 'Fiji',
          region: 'Taveuni',
        ),);
        await repository.createSite(const DiveSite(
          id: '',
          name: 'Coral Garden',
          country: 'Indonesia',
          region: 'Bali',
        ),);
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
        await repository.createSite(const DiveSite(
          id: 'site-1',
          name: 'Empty Site',
        ),);

        final counts = await repository.getDiveCountsBySite();

        expect(counts, isEmpty);
      });
    });

    group('getSitesWithDiveCounts', () {
      test('should return sites with zero counts when no dives exist', () async {
        await repository.createSite(const DiveSite(
          id: '',
          name: 'Site A',
        ),);
        await repository.createSite(const DiveSite(
          id: '',
          name: 'Site B',
        ),);

        final results = await repository.getSitesWithDiveCounts();

        expect(results.length, equals(2));
        expect(results[0].diveCount, equals(0));
        expect(results[1].diveCount, equals(0));
      });
    });
  });
}
