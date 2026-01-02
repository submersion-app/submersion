import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveCenterRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveCenterRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  DiveCenter createTestCenter({
    String id = '',
    String name = 'Test Dive Center',
    String? location,
    double? latitude,
    double? longitude,
    String? country,
    String? phone,
    String? email,
    String? website,
    List<String> affiliations = const [],
    double? rating,
    String notes = '',
  }) {
    final now = DateTime.now();
    return DiveCenter(
      id: id,
      name: name,
      location: location,
      latitude: latitude,
      longitude: longitude,
      country: country,
      phone: phone,
      email: email,
      website: website,
      affiliations: affiliations,
      rating: rating,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('DiveCenterRepository', () {
    group('createDiveCenter', () {
      test('should create a new center with generated ID when ID is empty',
          () async {
        final center = createTestCenter(name: 'Ocean Adventures');

        final createdCenter = await repository.createDiveCenter(center);

        expect(createdCenter.id, isNotEmpty);
        expect(createdCenter.name, equals('Ocean Adventures'));
      });

      test('should create a center with provided ID', () async {
        final center =
            createTestCenter(id: 'custom-center-id', name: 'Reef Divers');

        final createdCenter = await repository.createDiveCenter(center);

        expect(createdCenter.id, equals('custom-center-id'));
      });

      test('should create a center with all fields', () async {
        final center = createTestCenter(
          name: 'Complete Dive Shop',
          location: 'Downtown Marina',
          latitude: 25.7617,
          longitude: -80.1918,
          country: 'USA',
          phone: '+1-305-555-0100',
          email: 'info@completedive.com',
          website: 'https://completedive.com',
          affiliations: ['PADI', 'SSI'],
          rating: 4.8,
          notes: 'Best shop in town',
        );

        final createdCenter = await repository.createDiveCenter(center);
        final fetchedCenter =
            await repository.getDiveCenterById(createdCenter.id);

        expect(fetchedCenter, isNotNull);
        expect(fetchedCenter!.name, equals('Complete Dive Shop'));
        expect(fetchedCenter.location, equals('Downtown Marina'));
        expect(fetchedCenter.latitude, closeTo(25.7617, 0.0001));
        expect(fetchedCenter.longitude, closeTo(-80.1918, 0.0001));
        expect(fetchedCenter.country, equals('USA'));
        expect(fetchedCenter.phone, equals('+1-305-555-0100'));
        expect(fetchedCenter.email, equals('info@completedive.com'));
        expect(fetchedCenter.website, equals('https://completedive.com'));
        expect(fetchedCenter.affiliations, containsAll(['PADI', 'SSI']));
        expect(fetchedCenter.rating, equals(4.8));
        expect(fetchedCenter.notes, equals('Best shop in town'));
      });
    });

    group('getDiveCenterById', () {
      test('should return center when found', () async {
        final center = await repository.createDiveCenter(
          createTestCenter(name: 'Find Me Center'),
        );

        final result = await repository.getDiveCenterById(center.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Find Me Center'));
      });

      test('should return null when center not found', () async {
        final result = await repository.getDiveCenterById('non-existent-id');

        expect(result, isNull);
      });
    });

    group('getAllDiveCenters', () {
      test('should return empty list when no centers exist', () async {
        final result = await repository.getAllDiveCenters();

        expect(result, isEmpty);
      });

      test('should return all centers ordered by name', () async {
        await repository
            .createDiveCenter(createTestCenter(name: 'Zephyr Divers'));
        await repository
            .createDiveCenter(createTestCenter(name: 'Aqua Adventures'));
        await repository
            .createDiveCenter(createTestCenter(name: 'Marine Explorers'));

        final result = await repository.getAllDiveCenters();

        expect(result.length, equals(3));
        expect(result[0].name, equals('Aqua Adventures'));
        expect(result[1].name, equals('Marine Explorers'));
        expect(result[2].name, equals('Zephyr Divers'));
      });
    });

    group('updateDiveCenter', () {
      test('should update center fields', () async {
        final center = await repository.createDiveCenter(
          createTestCenter(name: 'Original Center', location: 'Old Location'),
        );

        final updatedCenter = center.copyWith(
          name: 'Updated Center',
          location: 'New Location',
          rating: 5.0,
        );

        await repository.updateDiveCenter(updatedCenter);
        final result = await repository.getDiveCenterById(center.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Updated Center'));
        expect(result.location, equals('New Location'));
        expect(result.rating, equals(5.0));
      });

      test('should update affiliations', () async {
        final center = await repository.createDiveCenter(
          createTestCenter(name: 'Affiliations Center', affiliations: ['PADI']),
        );

        final updatedCenter =
            center.copyWith(affiliations: ['PADI', 'SSI', 'NAUI']);

        await repository.updateDiveCenter(updatedCenter);
        final result = await repository.getDiveCenterById(center.id);

        expect(result!.affiliations, containsAll(['PADI', 'SSI', 'NAUI']));
      });
    });

    group('deleteDiveCenter', () {
      test('should delete existing center', () async {
        final center = await repository.createDiveCenter(
          createTestCenter(name: 'To Delete'),
        );

        await repository.deleteDiveCenter(center.id);
        final result = await repository.getDiveCenterById(center.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent center', () async {
        await expectLater(
          repository.deleteDiveCenter('non-existent-id'),
          completes,
        );
      });
    });

    group('searchDiveCenters', () {
      setUp(() async {
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Ocean Blue Diving',
            location: 'Miami Beach',
            country: 'USA',
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Coral Reef Adventures',
            location: 'Key Largo',
            country: 'USA',
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Pacific Explorers',
            location: 'Sydney Harbor',
            country: 'Australia',
          ),
        );
      });

      test('should find centers by name', () async {
        final results = await repository.searchDiveCenters('Ocean');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Ocean Blue Diving'));
      });

      test('should find centers by location', () async {
        final results = await repository.searchDiveCenters('Key Largo');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Coral Reef Adventures'));
      });

      test('should find centers by country', () async {
        final results = await repository.searchDiveCenters('Australia');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Pacific Explorers'));
      });

      test('should return empty list for no matches', () async {
        final results = await repository.searchDiveCenters('NonExistent');

        expect(results, isEmpty);
      });

      test('should be case insensitive', () async {
        final results = await repository.searchDiveCenters('CORAL');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Coral Reef Adventures'));
      });
    });

    group('getDiveCentersByCountry', () {
      setUp(() async {
        await repository.createDiveCenter(
          createTestCenter(
            name: 'USA Center 1',
            country: 'USA',
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'USA Center 2',
            country: 'USA',
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Australia Center',
            country: 'Australia',
          ),
        );
      });

      test('should return centers for specified country', () async {
        final results = await repository.getDiveCentersByCountry('USA');

        expect(results.length, equals(2));
        expect(results.every((c) => c.country == 'USA'), isTrue);
      });

      test('should return empty list when no centers in country', () async {
        final results = await repository.getDiveCentersByCountry('Japan');

        expect(results, isEmpty);
      });
    });

    group('getDiveCentersWithCoordinates', () {
      setUp(() async {
        await repository.createDiveCenter(
          createTestCenter(
            name: 'With Coords',
            latitude: 25.0,
            longitude: -80.0,
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Without Coords',
          ),
        );
      });

      test('should return only centers with coordinates', () async {
        final results = await repository.getDiveCentersWithCoordinates();

        expect(results.length, equals(1));
        expect(results[0].name, equals('With Coords'));
        expect(results[0].hasCoordinates, isTrue);
      });
    });

    group('getDiveCountForCenter', () {
      test('should return 0 when center has no dives', () async {
        final center = await repository.createDiveCenter(
          createTestCenter(name: 'New Center'),
        );

        final count = await repository.getDiveCountForCenter(center.id);

        expect(count, equals(0));
      });
    });

    group('getCountries', () {
      test('should return empty list when no centers exist', () async {
        final countries = await repository.getCountries();

        expect(countries, isEmpty);
      });

      test('should return unique countries ordered alphabetically', () async {
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Center 1',
            country: 'USA',
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Center 2',
            country: 'Australia',
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Center 3',
            country: 'USA', // duplicate
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'Center 4',
            country: 'Mexico',
          ),
        );

        final countries = await repository.getCountries();

        expect(countries, equals(['Australia', 'Mexico', 'USA']));
      });

      test('should exclude null and empty countries', () async {
        await repository.createDiveCenter(
          createTestCenter(
            name: 'With Country',
            country: 'USA',
          ),
        );
        await repository.createDiveCenter(
          createTestCenter(
            name: 'No Country',
            country: null,
          ),
        );

        final countries = await repository.getCountries();

        expect(countries, equals(['USA']));
      });
    });
  });
}
