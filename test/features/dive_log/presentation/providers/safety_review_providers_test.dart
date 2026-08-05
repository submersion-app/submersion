import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../domain/services/safety_review_fixtures.dart';

/// In-memory [SafetyFindingsRepository] with no database.
class _FakeRepo extends SafetyFindingsRepository {
  _FakeRepo({this.stored});

  SafetyReview? stored;
  SafetyReview? saved;

  @override
  Future<SafetyReview?> getReview(String diveId) async => stored;

  @override
  Future<void> saveReview(SafetyReview review) async => saved = review;
}

void main() {
  final now = DateTime.utc(2026, 7, 16);

  // A real in-memory DB backs every test: the provider self-invalidates on the
  // dive repository's detail-change stream, which resolves diveRepositoryProvider
  // -> DiveRepository -> DatabaseService.instance. Without a wired database that
  // watch would throw on build.
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final ts = now.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(ts),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  });

  tearDown(() => tearDownTestDatabase());

  SafetyReview storedReview(int version) => SafetyReview(
    diveId: 'd1',
    engineVersion: version,
    reviewedAt: now,
    findings: const [],
  );

  test('returns the stored review when its engineVersion is current', () async {
    final repo = _FakeRepo(
      stored: storedReview(SafetyReviewService.engineVersion),
    );
    final container = ProviderContainer(
      overrides: [safetyFindingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final result = await container.read(safetyReviewProvider('d1').future);
    expect(result, isNotNull);
    expect(repo.saved, isNull, reason: 'a current review is not recomputed');
  });

  test(
    'returns stored without computing when the master toggle is off',
    () async {
      final repo = _FakeRepo();
      final container = ProviderContainer(
        overrides: [
          safetyFindingsRepositoryProvider.overrideWithValue(repo),
          safetyReviewEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(safetyReviewProvider('d1').future);
      expect(result, isNull);
      expect(repo.saved, isNull);
    },
  );

  test('returns stored when the profile analysis is unavailable', () async {
    final repo = _FakeRepo();
    final container = ProviderContainer(
      overrides: [
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        safetyReviewEnabledProvider.overrideWithValue(true),
        profileAnalysisProvider('d1').overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(safetyReviewProvider('d1').future);
    expect(result, isNull);
    expect(repo.saved, isNull);
  });

  test(
    'computes, saves, and returns a fresh review when none is stored',
    () async {
      final repo = _FakeRepo();
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
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(safetyReviewProvider('d1').future);
      expect(result, isNotNull);
      expect(result!.engineVersion, SafetyReviewService.engineVersion);
      expect(result.findings, isNotEmpty);
      expect(repo.saved, isNotNull, reason: 'a computed review is persisted');
    },
  );

  // Regression: a freshly synced library imports safety review/finding rows
  // straight into their tables (SyncDataSerializer.insertOnConflictUpdate),
  // bypassing every local notifier. The one-shot safetyReviewProvider must
  // still pick them up without an app restart -- it did not before the
  // self-invalidation hook on the dive detail-change stream (which now
  // includes the safety tables) was added.
  test(
    'a synced safety review row refreshes the provider without a restart',
    () async {
      // A real repository over the in-memory DB, not the fake: the point is
      // that a raw table write becomes visible through the provider.
      final repo = SafetyFindingsRepository(db: db);
      final container = ProviderContainer(
        overrides: [
          safetyFindingsRepositoryProvider.overrideWithValue(repo),
          safetyReviewEnabledProvider.overrideWithValue(true),
          // No profile: the compute path returns null, so the first read
          // caches null exactly like opening a dive mid-sync.
          profileAnalysisProvider('d1').overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      // Keep the provider alive like an on-screen detail widget so an
      // invalidation actually rebuilds it.
      final sub = container.listen(safetyReviewProvider('d1'), (_, _) {});
      addTearDown(sub.close);

      expect(
        await container.read(safetyReviewProvider('d1').future),
        isNull,
        reason: 'nothing analyzed and no profile yet',
      );

      // Simulate the sync import writing the review + one finding directly.
      final ts = now.millisecondsSinceEpoch;
      await db
          .into(db.diveSafetyReviews)
          .insertOnConflictUpdate(
            DiveSafetyReviewsCompanion.insert(
              diveId: 'd1',
              engineVersion: SafetyReviewService.engineVersion,
              reviewedAt: ts,
            ),
          );
      await db
          .into(db.diveSafetyFindings)
          .insert(
            DiveSafetyFindingsCompanion.insert(
              id: 'f1',
              diveId: 'd1',
              ruleId: SafetyRuleId.sawtoothProfile.dbValue,
              severity: SafetySeverity.caution.dbValue,
              engineVersion: SafetyReviewService.engineVersion,
              createdAt: ts,
              value: const Value(3),
              startTimestamp: const Value(578),
              endTimestamp: const Value(2582),
            ),
          );

      // Wait past the change-tick debounce so invalidateSelfWhen fires.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await pumpEventQueue();

      final refreshed = await container.read(safetyReviewProvider('d1').future);
      expect(
        refreshed,
        isNotNull,
        reason: 'the synced review must be visible without an app restart',
      );
      expect(refreshed!.findings, hasLength(1));
      expect(refreshed.findings.single.ruleId, SafetyRuleId.sawtoothProfile);
    },
  );
}
