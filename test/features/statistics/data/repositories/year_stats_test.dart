import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepository;
  late StatisticsRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    diveRepository = DiveRepository();
    repository = StatisticsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  group('getYearStats', () {
    test('aggregates count, seconds, and max depth for one year', () async {
      await diveRepository.createDive(
        domain.Dive(
          id: 'a',
          dateTime: DateTime(2026, 2, 1, 10),
          bottomTime: const Duration(minutes: 30),
          maxDepth: 18,
        ),
      );
      await diveRepository.createDive(
        domain.Dive(
          id: 'b',
          dateTime: DateTime(2026, 5, 1, 10),
          bottomTime: const Duration(minutes: 40),
          maxDepth: 32,
        ),
      );
      await diveRepository.createDive(
        domain.Dive(
          id: 'c',
          dateTime: DateTime(2026, 7, 1, 10),
          bottomTime: const Duration(minutes: 50),
          maxDepth: 25,
        ),
      );
      await diveRepository.createDive(
        domain.Dive(
          id: 'last-year',
          dateTime: DateTime(2025, 7, 1, 10),
          bottomTime: const Duration(minutes: 60),
          maxDepth: 40,
        ),
      );

      final stats = await repository.getYearStats(2026);
      expect(stats.diveCount, 3);
      expect(stats.totalSeconds, (30 + 40 + 50) * 60);
      expect(stats.maxDepth, 32.0);
    });

    test('year with no dives returns zeros and null maxDepth', () async {
      final stats = await repository.getYearStats(2020);
      expect(stats.diveCount, 0);
      expect(stats.totalSeconds, 0);
      expect(stats.maxDepth, isNull);
    });

    test('scopes by diver id', () async {
      await diveRepository.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime(2026, 6, 2, 10)),
      );
      final stats = await repository.getYearStats(2026, diverId: 'nobody');
      expect(stats.diveCount, 0);
    });
  });
}
