import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  group('getOnThisDayDiveIds', () {
    test('matches month/day from prior years only, newest first', () async {
      await repository.createDive(
        domain.Dive(id: 'match-2023', dateTime: DateTime(2023, 7, 24, 10)),
      );
      await repository.createDive(
        domain.Dive(id: 'match-2024', dateTime: DateTime(2024, 7, 24, 14)),
      );
      await repository.createDive(
        domain.Dive(id: 'this-year', dateTime: DateTime(2026, 7, 24, 9)),
      );
      await repository.createDive(
        domain.Dive(id: 'wrong-day', dateTime: DateTime(2024, 7, 23, 9)),
      );

      final ids = await repository.getOnThisDayDiveIds(
        month: 7,
        day: 24,
        excludeYear: 2026,
      );
      expect(ids, ['match-2024', 'match-2023']);
    });

    test('Feb 29 matches only leap-year dives and does not crash', () async {
      await repository.createDive(
        domain.Dive(id: 'leap', dateTime: DateTime(2024, 2, 29, 10)),
      );
      await repository.createDive(
        domain.Dive(id: 'mar1', dateTime: DateTime(2023, 3, 1, 10)),
      );

      final ids = await repository.getOnThisDayDiveIds(
        month: 2,
        day: 29,
        excludeYear: 2026,
      );
      expect(ids, ['leap']);
    });

    test('respects diverId scoping', () async {
      await repository.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime(2024, 7, 24, 10)),
      );

      final ids = await repository.getOnThisDayDiveIds(
        month: 7,
        day: 24,
        excludeYear: 2026,
        diverId: 'nobody',
      );
      expect(ids, isEmpty);
    });

    test('caps results at limit', () async {
      for (var year = 2016; year < 2026; year++) {
        await repository.createDive(
          domain.Dive(id: 'd$year', dateTime: DateTime(year, 7, 24, 10)),
        );
      }
      final ids = await repository.getOnThisDayDiveIds(
        month: 7,
        day: 24,
        excludeYear: 2026,
        limit: 5,
      );
      expect(ids, hasLength(5));
      expect(ids.first, 'd2025');
    });
  });
}
