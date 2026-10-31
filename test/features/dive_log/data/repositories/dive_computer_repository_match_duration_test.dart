import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/unique_ids.dart';

/// A download's `durationSeconds` is the computer's runtime, so the matcher
/// must compare it with the dive's total time. Bottom time is shorter by the
/// ascent and any stops, and comparing against it cost a second computer's
/// reading of the same dive its auto-consolidate score.
void main() {
  late AppDatabase db;
  late DiveComputerRepository repository;

  final start = DateTime(2026, 6, 1, 9);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> insertDive({
    int? runtime,
    int? bottomTime,
    DateTime? exitTime,
  }) async {
    final id = uniqueTestId('dive');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(start.millisecondsSinceEpoch),
            entryTime: Value(start.millisecondsSinceEpoch),
            exitTime: Value(exitTime?.millisecondsSinceEpoch),
            runtime: Value(runtime),
            bottomTime: Value(bottomTime),
            maxDepth: const Value(20),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  group('findMatchingDiveWithScore duration', () {
    test(
      'compares the download with the runtime, not the bottom time',
      () async {
        await insertDive(runtime: 3540, bottomTime: 2700);

        final match = await repository.findMatchingDiveWithScore(
          profileStartTime: start.add(const Duration(seconds: 22)),
          durationSeconds: 3550,
          maxDepth: 20,
        );

        expect(match?.durationDifferenceSeconds, 10);
        // Time 0.40 * 278/300, depth 0.35, duration 0.25 * 590/600.
        expect(match?.score, closeTo(0.9665, 0.001));
      },
    );

    test('uses exit minus entry when no runtime is stored', () async {
      await insertDive(
        bottomTime: 1800,
        exitTime: start.add(const Duration(seconds: 2400)),
      );

      final match = await repository.findMatchingDiveWithScore(
        profileStartTime: start,
        durationSeconds: 2410,
        maxDepth: 20,
      );

      expect(match?.durationDifferenceSeconds, 10);
    });

    test('ignores an exit time that is not after the entry', () async {
      await insertDive(bottomTime: 1800, exitTime: start);

      final match = await repository.findMatchingDiveWithScore(
        profileStartTime: start,
        durationSeconds: 1810,
        maxDepth: 20,
      );

      expect(match?.durationDifferenceSeconds, 10);
    });

    test('uses the profile span when no runtime or exit is stored', () async {
      final diveId = await insertDive(bottomTime: 1800);
      await ProfileSeriesRepository().insertSeries(
        diveId: diveId,
        samples: [
          for (final t in [0, 1200, 2400])
            ProfileSample(timestamp: t, depth: 20),
        ],
      );

      final match = await repository.findMatchingDiveWithScore(
        profileStartTime: start,
        durationSeconds: 2410,
        maxDepth: 20,
      );

      expect(match?.durationDifferenceSeconds, 10);
    });

    test(
      'falls back to the bottom time when nothing better is stored',
      () async {
        await insertDive(bottomTime: 600);

        final match = await repository.findMatchingDiveWithScore(
          profileStartTime: start,
          durationSeconds: 610,
          maxDepth: 20,
        );

        expect(match?.durationDifferenceSeconds, 10);
      },
    );
  });
}
