@Tags(['performance'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

import '../helpers/performance_data_generator.dart';
import '../helpers/test_database.dart';

void main() {
  late SiteRepository repository;
  late GeneratedDataSummary summary;

  setUpAll(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
    final generator = PerformanceDataGenerator(DataProfile.realistic);
    summary = await generator.generate();
    // ignore: avoid_print
    print(
      'Generated ${summary.siteCount} sites, '
      '${summary.diveCount} dives in '
      '${summary.generationTime.inSeconds}s',
    );
  });

  tearDownAll(() async {
    await tearDownTestDatabase();
  });

  setUp(() {
    PerfTimer.reset();
  });

  group('Site repository benchmarks (2000 sites)', () {
    test('getAllSites < 300ms', () async {
      await repository.getAllSites(diverId: summary.diverId);
      final ms = PerfTimer.lastResult('getAllSites')!.inMilliseconds;
      // ignore: avoid_print
      print('  getAllSites: ${ms}ms');
      expect(ms, lessThan(300));
    });

    test('getSitesWithDiveCounts < 500ms', () async {
      await repository.getSitesWithDiveCounts(diverId: summary.diverId);
      final ms = PerfTimer.lastResult('getSitesWithDiveCounts')!.inMilliseconds;
      // ignore: avoid_print
      print('  getSitesWithDiveCounts: ${ms}ms');
      expect(ms, lessThan(500));
    });

    test('searchSites < 150ms', () async {
      await repository.searchSites('reef', diverId: summary.diverId);
      final ms = PerfTimer.lastResult('searchSites')!.inMilliseconds;
      // ignore: avoid_print
      print('  searchSites: ${ms}ms');
      expect(ms, lessThan(150));
    });

    test('getDiveCountsBySite < 200ms', () async {
      final sw = Stopwatch()..start();
      await repository.getDiveCountsBySite();
      sw.stop();
      final ms = sw.elapsedMilliseconds;
      // ignore: avoid_print
      print('  getDiveCountsBySite: ${ms}ms');
      expect(ms, lessThan(200));
    });
  });
}
