import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// Covers [DiveComputerRepository.findComputerDivesContainingTime]: the
/// same-computer containment check that backs the "second half of an
/// already-merged dive" duplicate detection in [DiveImportService].
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insertOnConflictUpdate(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<String> insertComputer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: 'Mares Quad',
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// A 30-minute dive on [computerId] starting at [entryTime], sampled every
  /// 30 seconds -- mirrors how [DiveImportService]'s contained-segment pass
  /// reads a candidate's recorded window.
  Future<String> insertDiveWithProfile({
    required String computerId,
    required DateTime entryTime,
    int durationSeconds = 1800,
    String? diverId,
  }) async {
    return repository.importProfile(
      computerId: computerId,
      profileStartTime: entryTime,
      points: [
        for (var t = 0; t <= durationSeconds; t += 30)
          ProfilePointData(timestamp: t, depth: 10.0),
      ],
      durationSeconds: durationSeconds,
      maxDepth: 10.0,
      diverId: diverId,
    );
  }

  test(
    'finds a dive whose recorded profile window contains the given time',
    () async {
      final computerId = await insertComputer('comp-1');
      final entryTime = DateTime(2026, 4, 10, 19, 52);
      final diveId = await insertDiveWithProfile(
        computerId: computerId,
        entryTime: entryTime,
      );

      // 20 minutes into the 30-minute recorded window.
      final probe = entryTime.add(const Duration(minutes: 20));

      final result = await repository.findComputerDivesContainingTime(
        computerId: computerId,
        time: probe,
      );

      expect(result.map((c) => c.diveId).toList(), [diveId]);
    },
  );

  test('excludes a time outside every recorded window', () async {
    final computerId = await insertComputer('comp-1');
    final entryTime = DateTime(2026, 4, 10, 19, 52);
    await insertDiveWithProfile(computerId: computerId, entryTime: entryTime);

    // 5 minutes after the 30-minute recording ends.
    final probe = entryTime.add(const Duration(minutes: 35));

    final result = await repository.findComputerDivesContainingTime(
      computerId: computerId,
      time: probe,
    );

    expect(result, isEmpty);
  });

  test('is scoped to the given computer', () async {
    final computerA = await insertComputer('comp-a');
    final computerB = await insertComputer('comp-b');
    final entryTime = DateTime(2026, 4, 10, 19, 52);
    await insertDiveWithProfile(computerId: computerA, entryTime: entryTime);

    final probe = entryTime.add(const Duration(minutes: 10));

    expect(
      await repository.findComputerDivesContainingTime(
        computerId: computerB,
        time: probe,
      ),
      isEmpty,
    );
    expect(
      await repository.findComputerDivesContainingTime(
        computerId: computerA,
        time: probe,
      ),
      isNotEmpty,
    );
  });

  test('is scoped to the given diver when one is provided', () async {
    final computerId = await insertComputer('comp-1');
    await insertDiver('diver-a');
    final entryTime = DateTime(2026, 4, 10, 19, 52);
    await insertDiveWithProfile(
      computerId: computerId,
      entryTime: entryTime,
      diverId: 'diver-a',
    );

    final probe = entryTime.add(const Duration(minutes: 10));

    expect(
      await repository.findComputerDivesContainingTime(
        computerId: computerId,
        time: probe,
        diverId: 'diver-b',
      ),
      isEmpty,
    );
    expect(
      await repository.findComputerDivesContainingTime(
        computerId: computerId,
        time: probe,
        diverId: 'diver-a',
      ),
      isNotEmpty,
    );
  });

  test('returns the boundary instants of the recorded window', () async {
    final computerId = await insertComputer('comp-1');
    final entryTime = DateTime(2026, 4, 10, 19, 52);
    final diveId = await insertDiveWithProfile(
      computerId: computerId,
      entryTime: entryTime,
      durationSeconds: 600,
    );

    expect(
      (await repository.findComputerDivesContainingTime(
        computerId: computerId,
        time: entryTime,
      )).map((c) => c.diveId).toList(),
      [diveId],
      reason: 'the first sample itself must count as inside the window',
    );
    expect(
      (await repository.findComputerDivesContainingTime(
        computerId: computerId,
        time: entryTime.add(const Duration(seconds: 600)),
      )).map((c) => c.diveId).toList(),
      [diveId],
      reason: 'the last sample itself must count as inside the window',
    );
    expect(
      await repository.findComputerDivesContainingTime(
        computerId: computerId,
        time: entryTime.add(const Duration(seconds: 601)),
      ),
      isEmpty,
    );
  });

  test(
    'returns the series id that satisfied the window, not just the dive',
    () async {
      final computerId = await insertComputer('comp-1');
      final entryTime = DateTime(2026, 4, 10, 19, 52);
      final diveId = await insertDiveWithProfile(
        computerId: computerId,
        entryTime: entryTime,
      );

      final result = await repository.findComputerDivesContainingTime(
        computerId: computerId,
        time: entryTime.add(const Duration(minutes: 20)),
      );

      expect(result, hasLength(1));
      final series = await repository.getProfileSeriesById(
        result.single.seriesId,
      );
      expect(
        series,
        isNotNull,
        reason:
            'the returned seriesId must resolve to a real series, so the '
            'caller can compare against that exact recording instead of '
            'the dive\'s merged, all-sources profile',
      );
      expect(series!.diveId, diveId);
      expect(series.computerId, computerId);
    },
  );

  test('matches a file-imported series via its source\'s computer id '
      '(Copilot review on #1852)', () async {
    // A file-imported series carries no computer_id of its own -- that
    // identity lives on the dive_data_sources row it came from instead
    // (DiveRepository.createDive never stamps the series directly).
    final computerId = await insertComputer('comp-1');
    final now = DateTime.now().millisecondsSinceEpoch;
    final entryTime = DateTime(2026, 4, 10, 19, 52);
    final entryTimeMs = entryTime.millisecondsSinceEpoch;
    const diveId = 'file-imported-dive';

    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: entryTimeMs,
            entryTime: Value(entryTimeMs),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-1',
            diveId: diveId,
            computerId: Value(computerId),
            importedAt: DateTime.fromMillisecondsSinceEpoch(now),
            createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          ),
        );
    await ProfileSeriesRepository().insertSeries(
      id: 'series-file-1',
      diveId: diveId,
      sourceId: 'src-1',
      samples: [
        for (var t = 0; t <= 1800; t += 30)
          ProfileSample(timestamp: t, depth: 10.0),
      ],
    );

    final result = await repository.findComputerDivesContainingTime(
      computerId: computerId,
      time: entryTime.add(const Duration(minutes: 20)),
    );

    expect(result.map((c) => c.diveId).toList(), [diveId]);
    expect(result.single.seriesId, 'series-file-1');
  });
}
