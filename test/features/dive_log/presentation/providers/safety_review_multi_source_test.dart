import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart'
    as divers;
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

late SharedPreferences _prefs;

class _FakeDiverRepository extends divers.DiverRepository {
  @override
  Future<domain.Diver?> getDiverById(String id) async => null;

  @override
  Future<domain.Diver?> getDefaultDiver() async => null;

  @override
  Future<String?> getActiveDiverIdFromSettings() async => null;

  @override
  Future<void> setActiveDiverIdInSettings(String? diverId) async {}
}

class _FakeDiverSettingsRepository extends DiverSettingsRepository {
  @override
  Future<AppSettings> getOrCreateSettingsForDiver(
    String diverId, {
    AppSettings? defaultSettings,
  }) async {
    return const AppSettings(notificationsEnabled: false);
  }

  @override
  Future<void> updateSettingsForDiver(
    String diverId,
    AppSettings settings,
  ) async {}
}

class _SettingsNotifier extends SettingsNotifier {
  _SettingsNotifier(Ref ref) : super(_FakeDiverSettingsRepository(), ref);
}

/// In-memory [SafetyFindingsRepository] with no stored review.
class _FakeFindingsRepo extends SafetyFindingsRepository {
  SafetyReview? saved;

  @override
  Future<SafetyReview?> getReview(String diveId) async => null;

  @override
  Future<SafetyReview> saveReview(SafetyReview review) async => saved = review;
}

/// True depth during a dive that stays within every ascent limit: down to
/// 18 m, 20 minutes there, up to 5 m at 7.8 m/min (under the 9 m/min
/// warning), a 3-minute stop, then a slow ascent.
double _trueDepth(int t) {
  const segments = [
    (18.0, 120),
    (18.0, 1200),
    (5.0, 100),
    (5.0, 180),
    (0.0, 90),
  ];
  var start = 0.0;
  var segmentStart = 0;
  for (final (target, seconds) in segments) {
    if (t <= segmentStart + seconds) {
      return start + (target - start) * (t - segmentStart) / seconds;
    }
    start = target;
    segmentStart += seconds;
  }
  return 0;
}

/// One computer's reading of that dive: a sample every 10 s from
/// [firstSample], stamped by a clock running [clockLag] seconds behind true
/// time, so each sample holds the depth from that much earlier.
List<DiveProfilePoint> _computer({int firstSample = 10, int clockLag = 0}) => [
  for (var t = firstSample; t <= 1700 + firstSample; t += 10)
    DiveProfilePoint(
      timestamp: t,
      depth: _trueDepth(t - clockLag).clamp(0, 100).toDouble(),
    ),
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    // Repository-backed lookups inside the analysis pipeline (surface
    // interval, events, gas switches) need a database to resolve against.
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  DiveDataSource source(String id, String computerId, bool isPrimary) {
    final now = DateTime(2026, 9, 14);
    return DiveDataSource(
      id: id,
      diveId: 'dive-1',
      computerId: computerId,
      isPrimary: isPrimary,
      importedAt: now,
      createdAt: now,
    );
  }

  // Two computers on one diver, neither recording a rapid ascent. Their
  // clocks disagree, as real computers' do, so while the diver ascends the
  // computer whose clock runs behind reads deeper at the same timestamp.
  // Interleaved by timestamp, as the dive-level profile holds them, each step
  // from one computer's sample to the other's is a jump of that difference.
  test('the safety review of a two-computer dive grades the primary '
      "computer's samples, not both computers' interleaved", () async {
    final primary = _computer();
    final secondary = _computer(firstSample: 11, clockLag: 120);
    final interleaved = [...primary, ...secondary]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 9, 14),
      profile: interleaved,
    );
    final repo = _FakeFindingsRepo();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        diverRepositoryProvider.overrideWithValue(_FakeDiverRepository()),
        settingsProvider.overrideWith((ref) => _SettingsNotifier(ref)),
        safetyReviewEnabledProvider.overrideWithValue(true),
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        analysisDiveProvider('dive-1').overrideWith((ref) async => dive),
        diveDataSourcesProvider('dive-1').overrideWith(
          (ref) async => [
            source('src-a', 'dc-a', true),
            source('src-b', 'dc-b', false),
          ],
        ),
        sourceProfilesProvider('dive-1').overrideWith(
          (ref) async => {
            'src-a': SourceProfile(
              sourceId: 'src-a',
              computerId: 'dc-a',
              isEdited: false,
              points: primary,
            ),
            'src-b': SourceProfile(
              sourceId: 'src-b',
              computerId: 'dc-b',
              isEdited: false,
              points: secondary,
            ),
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    List<SafetyFinding> rapidAscents(Iterable<SafetyFinding> findings) => [
      for (final f in findings)
        if (f.ruleId == SafetyRuleId.rapidAscent) f,
    ];

    // Control: the interleaved samples alone produce rapid ascents, so the
    // assertion below is about which samples the review reads.
    final merged = await container.read(
      profileAnalysisProvider('dive-1').future,
    );
    expect(
      rapidAscents(
        const SafetyReviewService().review(
          diveId: 'dive-1',
          analysis: merged!,
          now: DateTime(2026, 9, 14),
        ),
      ),
      isNotEmpty,
      reason: 'the interleaved samples should look like rapid ascents',
    );

    final review = await container.read(safetyReviewProvider('dive-1').future);
    expect(review, isNotNull);
    expect(repo.saved, isNotNull);
    expect(rapidAscents(review!.findings), isEmpty);
  });
}
