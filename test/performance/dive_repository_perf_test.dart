@Tags(['performance'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../helpers/performance_data_generator.dart';
import '../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late GeneratedDataSummary summary;

  setUpAll(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    final generator = PerformanceDataGenerator(DataProfile.realistic);
    summary = await generator.generate();
    // ignore: avoid_print
    print(
      'Generated ${summary.diveCount} dives, '
      '${summary.profilePointCount} profile points in '
      '${summary.generationTime.inSeconds}s',
    );
  });

  tearDownAll(() async {
    await tearDownTestDatabase();
  });

  setUp(() {
    PerfTimer.reset();
  });

  group('Dive repository benchmarks (5000 dives)', () {
    test('getDiveSummaries first page < 500ms', () async {
      await repository.getDiveSummaries(diverId: summary.diverId, limit: 50);
      final ms = PerfTimer.lastResult('getDiveSummaries')!.inMilliseconds;
      // ignore: avoid_print
      print('  getDiveSummaries: ${ms}ms');
      expect(ms, lessThan(500));
    });

    test('getDiveCount < 200ms', () async {
      await repository.getDiveCount(diverId: summary.diverId);
      final ms = PerfTimer.lastResult('getDiveCount')!.inMilliseconds;
      // ignore: avoid_print
      print('  getDiveCount: ${ms}ms');
      expect(ms, lessThan(200));
    });

    test('getDiveCount with filter < 200ms', () async {
      await repository.getDiveCount(
        diverId: summary.diverId,
        filter: const DiveFilterState(minRating: 3),
      );
      final ms = PerfTimer.lastResult('getDiveCount')!.inMilliseconds;
      // ignore: avoid_print
      print('  getDiveCount (filtered): ${ms}ms');
      expect(ms, lessThan(200));
    });

    test('getDiveById < 2000ms', () async {
      final page = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 1,
      );
      PerfTimer.reset();

      await repository.getDiveById(page.first.id);
      final ms = PerfTimer.lastResult('getDiveById')!.inMilliseconds;
      // ignore: avoid_print
      print('  getDiveById: ${ms}ms');
      if (ms > 500) {
        // ignore: avoid_print
        print('  WARNING: getDiveById exceeds 500ms ideal threshold');
      }
      // Hard ceiling -- full dive load touches many related tables
      expect(ms, lessThan(2000));
    });

    test('getDiveProfile < 300ms', () async {
      final page = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      PerfTimer.reset();

      final profile = await repository.getDiveProfile(page.first.id);
      final ms = PerfTimer.lastResult('getDiveProfile')!.inMilliseconds;
      // ignore: avoid_print
      print('  getDiveProfile (${profile.length} points): ${ms}ms');
      expect(ms, lessThan(300));
    });

    test('batchProfileSummaries (50 dives) < 2000ms', () async {
      final page = await repository.getDiveSummaries(
        diverId: summary.diverId,
        limit: 50,
      );
      final ids = page.map((d) => d.id).toList();
      PerfTimer.reset();

      await repository.getBatchProfileSummaries(ids);
      final ms = PerfTimer.lastResult('batchProfileSummaries')!.inMilliseconds;
      // ignore: avoid_print
      print('  batchProfileSummaries (50): ${ms}ms');
      if (ms > 500) {
        // ignore: avoid_print
        print('  WARNING: batchProfileSummaries exceeds 500ms ideal threshold');
      }
      // Hard ceiling -- scans millions of profile points across 50 dives
      expect(ms, lessThan(2000));
    });

    test('getAllDives (legacy) warns if > 500ms', () async {
      await repository.getAllDives(diverId: summary.diverId);
      final ms = PerfTimer.lastResult('getAllDives')!.inMilliseconds;
      // ignore: avoid_print
      print('  getAllDives (legacy): ${ms}ms');
      if (ms > 500) {
        // ignore: avoid_print
        print('  WARNING: getAllDives exceeds 500ms threshold');
      }
      // Soft threshold -- warn but don't fail
      expect(ms, lessThan(5000));
    });
  });
}
