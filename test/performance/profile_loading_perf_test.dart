@Tags(['performance'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

import '../helpers/performance_data_generator.dart';
import '../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late GeneratedDataSummary summary;
  late List<DiveSummary> firstPage;

  setUpAll(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    final generator = PerformanceDataGenerator(DataProfile.realistic);
    summary = await generator.generate();
    // ignore: avoid_print
    print('Generated ${summary.profilePointCount} profile points');

    // Pre-load first page for use in tests
    firstPage = await repository.getDiveSummaries(
      diverId: summary.diverId,
      limit: 50,
    );
  });

  tearDownAll(() async {
    await tearDownTestDatabase();
  });

  setUp(() {
    PerfTimer.reset();
  });

  group('Profile loading benchmarks', () {
    test('single dive profile < 2000ms', () async {
      final profile = await repository.getDiveProfile(firstPage.first.id);
      final ms = PerfTimer.lastResult('getDiveProfile')!.inMilliseconds;
      // ignore: avoid_print
      print('  Single profile (${profile.length} pts): ${ms}ms');
      expect(ms, lessThan(2000));
    });

    test('batch profile summaries (50 dives) < 3000ms', () async {
      final ids = firstPage.map((d) => d.id).toList();

      final profiles = await repository.getBatchProfileSummaries(ids);
      final ms = PerfTimer.lastResult('batchProfileSummaries')!.inMilliseconds;
      final totalPoints = profiles.values.fold<int>(
        0,
        (sum, pts) => sum + pts.length,
      );
      // ignore: avoid_print
      print(
        '  Batch summaries (${profiles.length} dives, '
        '$totalPoints pts): ${ms}ms',
      );
      expect(ms, lessThan(3000));
    });

    test('batch profile summaries (25 dives) < 2000ms', () async {
      final ids = firstPage.take(25).map((d) => d.id).toList();

      await repository.getBatchProfileSummaries(ids);
      final ms = PerfTimer.lastResult('batchProfileSummaries')!.inMilliseconds;
      // ignore: avoid_print
      print('  Batch summaries (${ids.length} dives): ${ms}ms');
      expect(ms, lessThan(2000));
    });
  });
}
