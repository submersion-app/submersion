import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3066: the profile editor can start from a computer that is not
/// primary. The saved edit is a correction of that computer's samples, so it
/// belongs to that source, and the source becomes the dive's primary.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();

    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final (id, isPrimary, maxDepth) in [
      ('src-a', true, 20.0),
      ('src-b', false, 30.0),
    ]) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(id),
              diveId: const Value('dive-1'),
              isPrimary: Value(isPrimary),
              maxDepth: Value(maxDepth),
              importedAt: Value(DateTime(2026, 1, 1)),
              createdAt: Value(DateTime(2026, 1, 1)),
            ),
          );
      await ProfileSeriesRepository().insertSeries(
        diveId: 'dive-1',
        sourceId: id,
        isPrimary: isPrimary,
        samples: [
          const ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 60, depth: maxDepth),
          const ProfileSample(timestamp: 120, depth: 0),
        ],
        now: now,
      );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const edited = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 60, depth: 28),
    DiveProfilePoint(timestamp: 120, depth: 0),
  ];

  Future<bool> isPrimarySource(String id) async => (await (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle()).isPrimary;

  test('an edit of a non-primary source promotes that source', () async {
    await repository.saveEditedProfileWithKind(
      diveId: 'dive-1',
      editedPoints: edited,
      editKind: 'profile_editor',
      sourceId: 'src-b',
    );

    expect(await isPrimarySource('src-b'), isTrue);
    expect(await isPrimarySource('src-a'), isFalse);

    final profiles = await repository.getProfilesByDataSource('dive-1');
    expect(profiles.keys.first, 'src-b');
    expect(profiles['src-b']!.isEdited, isTrue);
    expect([for (final p in profiles['src-b']!.points) p.depth], [0, 28, 0]);
    // The other computer keeps its own untouched samples.
    expect([for (final p in profiles['src-a']!.points) p.depth], [0, 20, 0]);

    final dive = await repository.getDiveById('dive-1');
    expect(dive!.maxDepth, 28);
  });

  test('the edit series is a child of the chosen source series', () async {
    await repository.saveEditedProfileWithKind(
      diveId: 'dive-1',
      editedPoints: edited,
      editKind: 'profile_editor',
      sourceId: 'src-b',
    );

    final seriesRepo = ProfileSeriesRepository();
    final series = await seriesRepo.getSeriesForDive('dive-1');
    final primary = series.singleWhere((s) => s.isPrimary);
    final parentId = await seriesRepo.parentSeriesIdOf(primary.id);
    final parent = series.singleWhere((s) => s.id == parentId);
    expect(primary.sourceId, 'src-b');
    expect(parent.sourceId, 'src-b');
  });

  test('an edit naming the primary source leaves the primary alone', () async {
    await repository.saveEditedProfileWithKind(
      diveId: 'dive-1',
      editedPoints: edited,
      editKind: 'profile_editor',
      sourceId: 'src-a',
    );

    expect(await isPrimarySource('src-a'), isTrue);
    expect(await isPrimarySource('src-b'), isFalse);
    final profiles = await repository.getProfilesByDataSource('dive-1');
    expect(profiles['src-a']!.isEdited, isTrue);
    expect([for (final p in profiles['src-b']!.points) p.depth], [0, 30, 0]);
  });

  test('a demoted source that was edited reads as its edit alone', () async {
    // Edit src-a while it is primary, then make src-b primary. src-a now
    // owns its original and its edit, both demoted; the editor and the
    // chart must see the edit, not both generations interleaved.
    await repository.saveEditedProfileWithKind(
      diveId: 'dive-1',
      editedPoints: edited,
      editKind: 'profile_editor',
    );
    await repository.setPrimaryDataSource(
      diveId: 'dive-1',
      computerReadingId: 'src-b',
    );

    final profiles = await repository.getProfilesByDataSource('dive-1');
    expect(profiles.keys.first, 'src-b');
    expect(
      [for (final p in profiles['src-a']!.points) (p.timestamp, p.depth)],
      [(0, 0.0), (60, 28.0), (120, 0.0)],
    );
  });

  test('promoting an edited file import back restores its edit', () async {
    // Neither series of src-a names a computer, so the edit cannot win on
    // the null-computer rank; it has to win as the newer generation.
    await repository.saveEditedProfileWithKind(
      diveId: 'dive-1',
      editedPoints: edited,
      editKind: 'profile_editor',
    );
    await repository.setPrimaryDataSource(
      diveId: 'dive-1',
      computerReadingId: 'src-b',
    );
    await repository.setPrimaryDataSource(
      diveId: 'dive-1',
      computerReadingId: 'src-a',
    );

    final profile = await repository.getDiveProfile('dive-1');
    expect(
      [for (final p in profile) (p.timestamp, p.depth)],
      [(0, 0.0), (60, 28.0), (120, 0.0)],
    );
  });
}
