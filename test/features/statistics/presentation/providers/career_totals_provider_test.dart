import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/career_totals_provider.dart';

DiveStatistics _stats({
  int totalDives = 0,
  int totalTimeSeconds = 0,
  DateTime? firstDiveDate,
}) => DiveStatistics(
  totalDives: totalDives,
  totalTimeSeconds: totalTimeSeconds,
  maxDepth: 0,
  avgMaxDepth: 0,
  totalSites: 0,
  firstDiveDate: firstDiveDate,
);

Diver _diver({
  int? priorDiveCount,
  int? priorDiveTimeSeconds,
  DateTime? divingSince,
}) => Diver(
  id: '1',
  name: 'Eric Griffin',
  priorDiveCount: priorDiveCount,
  priorDiveTimeSeconds: priorDiveTimeSeconds,
  divingSince: divingSince,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

ProviderContainer _container({
  required DiveStatistics stats,
  required Diver? diver,
}) {
  final container = ProviderContainer(
    overrides: [
      diveStatisticsProvider.overrideWith((ref) async => stats),
      currentDiverProvider.overrideWith((ref) async => diver),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('careerTotalsProvider', () {
    test('combines logged dives with the diver prior-dive offset', () async {
      final container = _container(
        stats: _stats(totalDives: 247, totalTimeSeconds: 669600),
        diver: _diver(priorDiveCount: 125, priorDiveTimeSeconds: 360000),
      );

      final career = await container.read(careerTotalsProvider.future);

      expect(career.loggedDives, 247);
      expect(career.priorDives, 125);
      expect(career.combinedDives, 372);
      expect(career.combinedTimeSeconds, 1029600);
      expect(career.hasPriorDives, isTrue);
    });

    test('falls back to logged totals when the diver has no priors', () async {
      final container = _container(
        stats: _stats(totalDives: 12, totalTimeSeconds: 3600),
        diver: _diver(),
      );

      final career = await container.read(careerTotalsProvider.future);

      expect(career.combinedDives, 12);
      expect(career.combinedTimeSeconds, 3600);
      expect(career.hasPriorDives, isFalse);
    });

    test('treats a null diver as no prior experience', () async {
      final container = _container(
        stats: _stats(totalDives: 5, totalTimeSeconds: 1800),
        diver: null,
      );

      final career = await container.read(careerTotalsProvider.future);

      expect(career.combinedDives, 5);
      expect(career.hasPriorExperience, isFalse);
    });

    test('surfaces prior experience with nothing logged in-app', () async {
      final container = _container(
        stats: _stats(),
        diver: _diver(priorDiveCount: 480, divingSince: DateTime(1998, 6, 1)),
      );

      final career = await container.read(careerTotalsProvider.future);

      expect(career.combinedDives, 480);
      expect(career.divingSinceResolved, DateTime(1998, 6, 1));
    });

    test('clamps divingSince to the first logged dive', () async {
      final container = _container(
        stats: _stats(totalDives: 3, firstDiveDate: DateTime(1995, 4, 2)),
        diver: _diver(priorDiveCount: 10, divingSince: DateTime(1998, 6, 1)),
      );

      final career = await container.read(careerTotalsProvider.future);

      expect(career.divingSinceResolved, DateTime(1995, 4, 2));
    });
  });
}
