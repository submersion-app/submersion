import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../domain/services/safety_review_fixtures.dart';

/// Records every review handed to it, so the sweep's coverage can be asserted
/// without inspecting the database.
class _RecordingRepo extends SafetyFindingsRepository {
  final saved = <String>[];

  @override
  Future<SafetyReview?> getReview(String diveId) async => null;

  @override
  Future<void> saveReview(SafetyReview review) async =>
      saved.add(review.diveId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 8);
  late AppDatabase db;

  /// Inserts the owning diver. Required: the test database enforces foreign
  /// keys, so a dive referencing a missing diver fails with SQLITE_CONSTRAINT.
  Future<void> insertDiver(String id) async {
    final ts = now.millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  }

  /// Inserts a dive owned by [diverId].
  Future<void> insertDive(String id, String diverId) async {
    final ts = now.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(ts),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver('diver-a');
    await insertDiver('diver-b');
    await insertDive('d1', 'diver-a');
    await insertDive('d2', 'diver-b');
  });

  tearDown(() => tearDownTestDatabase());

  /// A container whose analysis always yields a rapid-ascent fixture, so every
  /// dive produces a persistable review.
  ProviderContainer makeContainer(_RecordingRepo repo) {
    final profile = rapidAscentProfile();
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    final container = ProviderContainer(
      overrides: [
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        safetyReviewEnabledProvider.overrideWithValue(true),
        profileAnalysisProvider('d1').overrideWith((ref) async => analysis),
        profileAnalysisProvider('d2').overrideWith((ref) async => analysis),
        profileAnalysisProvider(
          'd-newer',
        ).overrideWith((ref) async => analysis),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sweeps every diver when diverId is null', () async {
    final repo = _RecordingRepo();
    final result = await makeContainer(
      repo,
    ).read(safetyReviewSweepProvider).run();

    expect(repo.saved, containsAll(<String>['d1', 'd2']));
    expect(result.swept, 2);
    expect(result.failed, 0);
    expect(result.cancelled, isFalse);
  });

  test('scopes to a single diver when diverId is supplied', () async {
    final repo = _RecordingRepo();
    final result = await makeContainer(
      repo,
    ).read(safetyReviewSweepProvider).run(diverId: 'diver-a');

    expect(repo.saved, <String>['d1']);
    expect(result.swept, 1);
  });

  test('sweeps oldest first so residual analysis is already cached', () async {
    final newer = now.add(const Duration(days: 1)).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d-newer'),
            diverId: const Value('diver-a'),
            diveDateTime: Value(newer),
            createdAt: Value(newer),
            updatedAt: Value(newer),
          ),
        );
    final repo = _RecordingRepo();

    await makeContainer(
      repo,
    ).read(safetyReviewSweepProvider).run(diverId: 'diver-a');

    expect(
      repo.saved,
      <String>['d1', 'd-newer'],
      reason:
          'newer profile analysis recursively awaits older dives, so the '
          'sweep must warm that cache in chronological order',
    );
  });

  test('reports progress ending at the total', () async {
    final repo = _RecordingRepo();
    final seen = <(int, int)>[];
    await makeContainer(repo)
        .read(safetyReviewSweepProvider)
        .run(onProgress: (done, total) => seen.add((done, total)));

    expect(seen.first, (0, 2), reason: 'an initial 0-of-N sizes the bar');
    expect(seen.last, (2, 2));
  });

  test('stops early and reports cancelled when isCancelled fires', () async {
    final repo = _RecordingRepo();
    final result = await makeContainer(
      repo,
    ).read(safetyReviewSweepProvider).run(isCancelled: () => true);

    expect(repo.saved, isEmpty);
    expect(result.cancelled, isTrue);
    expect(result.swept, 0);
  });

  test('an empty logbook sweeps nothing and reports a zero total', () async {
    await db.delete(db.dives).go();
    final repo = _RecordingRepo();
    final seen = <(int, int)>[];

    final result = await makeContainer(repo)
        .read(safetyReviewSweepProvider)
        .run(onProgress: (done, total) => seen.add((done, total)));

    expect(result.swept, 0);
    expect(result.failed, 0);
    expect(result.cancelled, isFalse);
    expect(seen, <(int, int)>[(0, 0)]);
  });

  test('does nothing when the master toggle is off', () async {
    final repo = _RecordingRepo();
    final container = ProviderContainer(
      overrides: [
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        safetyReviewEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(safetyReviewSweepProvider).run();

    expect(repo.saved, isEmpty);
    expect(result.swept, 0);
    expect(result.cancelled, isFalse);
  });

  test('counts a failing dive and still sweeps the rest', () async {
    final repo = _RecordingRepo();
    final profile = rapidAscentProfile();
    final analysis = analyzeFixture(
      depths: profile.depths,
      timestamps: profile.timestamps,
    );
    final container = ProviderContainer(
      overrides: [
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        safetyReviewEnabledProvider.overrideWithValue(true),
        profileAnalysisProvider(
          'd1',
        ).overrideWith((ref) async => throw StateError('corrupt profile')),
        profileAnalysisProvider('d2').overrideWith((ref) async => analysis),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(safetyReviewSweepProvider).run();

    expect(result.failed, 1);
    expect(
      result.swept,
      2,
      reason: 'swept counts dives visited, not successes',
    );
    expect(repo.saved, <String>['d2']);
  });
}
