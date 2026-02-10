import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

import 'performance_data_generator.dart';
import 'test_database.dart';

void main() {
  late DiveRepository diveRepository;
  late SiteRepository siteRepository;

  setUp(() async {
    await setUpTestDatabase();
    diveRepository = DiveRepository();
    siteRepository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('PerformanceDataGenerator', () {
    test('light preset generates correct counts', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();

      expect(summary.diveCount, equals(100));
      expect(summary.siteCount, equals(30));
      expect(summary.profilePointCount, greaterThan(80000));

      final dives = await diveRepository.getAllDives(diverId: summary.diverId);
      expect(dives.length, equals(100));

      final sites = await siteRepository.getAllSites(diverId: summary.diverId);
      expect(sites.length, equals(30));
    });

    test('light preset creates diver', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();
      expect(summary.diverId, isNotEmpty);
    });

    test('light preset generates sites with GPS coordinates', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();
      final sites = await siteRepository.getAllSites(diverId: summary.diverId);
      final withGps = sites.where((s) => s.hasCoordinates).length;
      expect(withGps, greaterThanOrEqualTo(20));
    });

    test('light preset generates tanks for dives', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();
      expect(summary.tankCount, greaterThan(0));
      expect(summary.tankCount, greaterThanOrEqualTo(100));
    });

    test('light preset generates tags', () async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      final summary = await generator.generate();
      expect(summary.tagCount, greaterThan(0));
    });

    test('generation time is under 10 seconds for light', () async {
      final sw = Stopwatch()..start();
      final generator = PerformanceDataGenerator(DataProfile.light);
      await generator.generate();
      sw.stop();
      expect(sw.elapsed.inSeconds, lessThan(10));
    });
  });
}
