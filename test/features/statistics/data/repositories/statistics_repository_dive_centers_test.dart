import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late StatisticsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = StatisticsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> insertDiveCenter({
    String? id,
    required String name,
    String? city,
    String? stateProvince,
    String? country,
  }) async {
    final centerId = id ?? 'center-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion(
            id: Value(centerId),
            name: Value(name),
            city: Value(city),
            stateProvince: Value(stateProvince),
            country: Value(country),
            notes: const Value(''),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return centerId;
  }

  Future<String> insertDiveWithCenter({
    String? id,
    String? diverId,
    required String diveCenterId,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diverId: Value(diverId),
            diveCenterId: Value(diveCenterId),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  Future<String> insertDive({String? id}) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  // ---------------------------------------------------------------------------
  // getTopDiveCenters — regression for issue #235
  // ---------------------------------------------------------------------------

  group('getTopDiveCenters', () {
    test(
      'returns city, state, country as subtitle when all three are set',
      () async {
        final centerId = await insertDiveCenter(
          id: 'dc-full',
          name: 'Blue Abyss Diving',
          city: 'Koh Tao',
          stateProvince: 'Surat Thani',
          country: 'Thailand',
        );
        await insertDiveWithCenter(diveCenterId: centerId);

        final results = await repository.getTopDiveCenters();

        expect(results, hasLength(1));
        expect(results.first.name, equals('Blue Abyss Diving'));
        expect(results.first.count, equals(1));
        expect(
          results.first.subtitle,
          equals('Koh Tao, Surat Thani, Thailand'),
        );
      },
    );

    test('returns city, country as subtitle when state is null', () async {
      final centerId = await insertDiveCenter(
        id: 'dc-city-country',
        name: 'Reef Divers',
        city: 'Koh Tao',
        stateProvince: null,
        country: 'Thailand',
      );
      await insertDiveWithCenter(diveCenterId: centerId);

      final results = await repository.getTopDiveCenters();

      expect(results, hasLength(1));
      expect(results.first.subtitle, equals('Koh Tao, Thailand'));
    });

    test('returns city, state as subtitle when country is null', () async {
      final centerId = await insertDiveCenter(
        id: 'dc-city-state',
        name: 'Bay Divers',
        city: 'Miami',
        stateProvince: 'Florida',
        country: null,
      );
      await insertDiveWithCenter(diveCenterId: centerId);

      final results = await repository.getTopDiveCenters();

      expect(results, hasLength(1));
      expect(results.first.subtitle, equals('Miami, Florida'));
    });

    test('returns state, country as subtitle when city is null', () async {
      final centerId = await insertDiveCenter(
        id: 'dc-state-country',
        name: 'Reef Riders',
        city: null,
        stateProvince: 'Queensland',
        country: 'Australia',
      );
      await insertDiveWithCenter(diveCenterId: centerId);

      final results = await repository.getTopDiveCenters();

      expect(results, hasLength(1));
      expect(results.first.subtitle, equals('Queensland, Australia'));
    });

    test(
      'uses city alone as subtitle when state and country are null',
      () async {
        final centerId = await insertDiveCenter(
          id: 'dc-city-only',
          name: 'City Divers',
          city: 'Miami',
          stateProvince: null,
          country: null,
        );
        await insertDiveWithCenter(diveCenterId: centerId);

        final results = await repository.getTopDiveCenters();

        expect(results, hasLength(1));
        expect(results.first.subtitle, equals('Miami'));
      },
    );

    test(
      'uses state alone as subtitle when city and country are null',
      () async {
        final centerId = await insertDiveCenter(
          id: 'dc-state-only',
          name: 'State Divers',
          city: null,
          stateProvince: 'Florida',
          country: null,
        );
        await insertDiveWithCenter(diveCenterId: centerId);

        final results = await repository.getTopDiveCenters();

        expect(results, hasLength(1));
        expect(results.first.subtitle, equals('Florida'));
      },
    );

    test(
      'uses country alone as subtitle when city and state are null',
      () async {
        final centerId = await insertDiveCenter(
          id: 'dc-country-only',
          name: 'Reef Riders',
          city: null,
          stateProvince: null,
          country: 'Australia',
        );
        await insertDiveWithCenter(diveCenterId: centerId);

        final results = await repository.getTopDiveCenters();

        expect(results, hasLength(1));
        expect(results.first.subtitle, equals('Australia'));
      },
    );

    test(
      'subtitle is null when city, state, and country are all null',
      () async {
        final centerId = await insertDiveCenter(
          id: 'dc-no-location',
          name: 'Mystery Divers',
          city: null,
          stateProvince: null,
          country: null,
        );
        await insertDiveWithCenter(diveCenterId: centerId);

        final results = await repository.getTopDiveCenters();

        expect(results, hasLength(1));
        expect(results.first.subtitle, isNull);
      },
    );

    group('empty and whitespace strings are treated as absent', () {
      test(
        'subtitle is null when all three fields are empty strings',
        () async {
          final centerId = await insertDiveCenter(
            id: 'dc-all-empty',
            name: 'Empty Divers',
            city: '',
            stateProvince: '',
            country: '',
          );
          await insertDiveWithCenter(diveCenterId: centerId);

          final results = await repository.getTopDiveCenters();

          expect(results, hasLength(1));
          expect(results.first.subtitle, isNull);
        },
      );

      test(
        'subtitle is null when all three fields are space-only strings',
        () async {
          final centerId = await insertDiveCenter(
            id: 'dc-all-whitespace',
            name: 'Whitespace Divers',
            city: '   ',
            stateProvince: '  ',
            country: '  ',
          );
          await insertDiveWithCenter(diveCenterId: centerId);

          final results = await repository.getTopDiveCenters();

          expect(results, hasLength(1));
          expect(results.first.subtitle, isNull);
        },
      );

      test('empty city is skipped; state and country are used', () async {
        final centerId = await insertDiveCenter(
          id: 'dc-empty-city',
          name: 'No City Divers',
          city: '',
          stateProvince: 'Queensland',
          country: 'Australia',
        );
        await insertDiveWithCenter(diveCenterId: centerId);

        final results = await repository.getTopDiveCenters();

        expect(results, hasLength(1));
        expect(results.first.subtitle, equals('Queensland, Australia'));
      });

      test(
        'whitespace city is skipped; real city is not trimmed away',
        () async {
          final centerId = await insertDiveCenter(
            id: 'dc-real-city',
            name: 'Real City Divers',
            city: '  Miami  ',
            stateProvince: null,
            country: null,
          );
          await insertDiveWithCenter(diveCenterId: centerId);

          final results = await repository.getTopDiveCenters();

          expect(results, hasLength(1));
          expect(results.first.subtitle, equals('Miami'));
        },
      );
    });

    test('ranks centers by dive count descending', () async {
      final center1 = await insertDiveCenter(
        id: 'dc-rank-1',
        name: 'Top Center',
        city: 'Cairns',
        country: 'Australia',
      );
      final center2 = await insertDiveCenter(
        id: 'dc-rank-2',
        name: 'Second Center',
        city: 'Sydney',
        country: 'Australia',
      );

      await insertDiveWithCenter(id: 'dive-a1', diveCenterId: center1);
      await insertDiveWithCenter(id: 'dive-a2', diveCenterId: center1);
      await insertDiveWithCenter(id: 'dive-a3', diveCenterId: center1);
      await insertDiveWithCenter(id: 'dive-b1', diveCenterId: center2);

      final results = await repository.getTopDiveCenters();

      expect(results.first.name, equals('Top Center'));
      expect(results.first.count, equals(3));
      expect(results[1].name, equals('Second Center'));
      expect(results[1].count, equals(1));
    });

    test('returns empty list when no dives are linked to any center', () async {
      await insertDiveCenter(
        id: 'dc-unused',
        name: 'Unlinked Center',
        city: 'Paris',
        country: 'France',
      );
      await insertDive(id: 'dive-unlinked');

      final results = await repository.getTopDiveCenters();

      expect(results, isEmpty);
    });
  });
}
