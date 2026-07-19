import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
}
