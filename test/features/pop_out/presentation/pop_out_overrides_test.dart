import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/pop_out/presentation/pop_out_overrides.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/fake_pop_out_windows.dart';
import '../../../helpers/test_database.dart';
import 'pop_out_client_test.dart' show launchOn;

class _CountingSafetyFindings extends SafetyFindingsRepository {
  _CountingSafetyFindings(this.stored);

  final SafetyReview? stored;
  int saves = 0;

  @override
  Future<SafetyReview?> getReview(String diveId) async => stored;

  @override
  Future<SafetyReview> saveReview(SafetyReview review) async {
    saves++;
    return review;
  }
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test(
    'pop-out overrides show the stored safety review without saving',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Stale: from an old engine, so the main window would recompute and
      // save. The pop-out shows it as stored.
      final stored = SafetyReview(
        diveId: 'd1',
        engineVersion: 0,
        reviewedAt: DateTime.utc(2020),
        findings: const [],
      );
      final repo = _CountingSafetyFindings(stored);
      // The main window's provider reads the analysis before it can compute
      // and save a review; the pop-out's never does.
      var analysisReads = 0;
      final container = ProviderContainer(
        overrides: [
          ...popOutProviderOverrides(
            prefs: prefs,
            logFileService: LogFileService(logDirectory: 'unused'),
            channel: FakePopOutChannel(),
            launch: launchOn('d1'),
          ).cast(),
          safetyFindingsRepositoryProvider.overrideWithValue(repo),
          safetyReviewEnabledProvider.overrideWithValue(true),
          profileAnalysisProvider('d1').overrideWith((ref) async {
            analysisReads++;
            return null;
          }),
        ],
      );
      addTearDown(container.dispose);

      final review = await container.read(safetyReviewProvider('d1').future);

      expect(review, stored);
      expect(repo.saves, 0);
      expect(analysisReads, 0);
    },
  );
}
