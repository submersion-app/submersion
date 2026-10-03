import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/analysis_pipeline_overrides.dart';
import '../../../../helpers/test_database.dart';

late SharedPreferences _prefs;

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

  List<SafetyFinding> rapidAscents(Iterable<SafetyFinding> findings) => [
    for (final f in findings)
      if (f.ruleId == SafetyRuleId.rapidAscent) f,
  ];

  /// A dive whose `dive.profile` holds [primary] and [secondary] interleaved
  /// by timestamp, recorded by [sources].
  ProviderContainer diveWith({
    required List<DiveProfilePoint> primary,
    required List<DiveProfilePoint> secondary,
    required List<DiveDataSource> sources,
    required SafetyFindingsRepository repo,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...analysisPipelineOverrides(_prefs),
        safetyReviewEnabledProvider.overrideWithValue(true),
        safetyFindingsRepositoryProvider.overrideWithValue(repo),
        analysisDiveProvider('dive-1').overrideWith(
          (ref) async => Dive(
            id: 'dive-1',
            dateTime: DateTime(2026, 9, 14),
            profile: [...primary, ...secondary]
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
          ),
        ),
        diveDataSourcesProvider('dive-1').overrideWith((ref) async => sources),
        sourceProfilesProvider('dive-1').overrideWith(
          (ref) async => {
            'src-a': SourceProfile(
              sourceId: 'src-a',
              computerId: 'dc-a',
              isEdited: false,
              points: primary,
            ),
            if (sources.length > 1)
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
    return container;
  }

  // Two computers on one diver, neither recording a rapid ascent. Their
  // clocks disagree, as real computers' do, so while the diver ascends the
  // computer whose clock runs behind reads deeper at the same timestamp.
  // Interleaved by timestamp, as dive.profile holds them, each step from one
  // computer's sample to the other's is a jump of that difference.
  final primary = _computer();
  final secondary = _computer(firstSample: 11, clockLag: 120);

  test('the interleaved samples of two computers read as rapid ascents '
      '(control)', () async {
    // One source row: the chart draws dive.profile, so the analysis replays
    // it, interleaving included. This is what the next test is not.
    final container = diveWith(
      primary: primary,
      secondary: secondary,
      sources: [source('src-a', 'dc-a', true)],
      repo: _FakeFindingsRepo(),
    );

    final review = await container.read(safetyReviewProvider('dive-1').future);

    expect(review, isNotNull);
    expect(rapidAscents(review!.findings), isNotEmpty);
  });

  test('the safety review of a two-computer dive grades the primary '
      "computer's samples, not both computers' interleaved", () async {
    final repo = _FakeFindingsRepo();
    final container = diveWith(
      primary: primary,
      secondary: secondary,
      sources: [source('src-a', 'dc-a', true), source('src-b', 'dc-b', false)],
      repo: repo,
    );

    final review = await container.read(safetyReviewProvider('dive-1').future);

    expect(review, isNotNull);
    expect(repo.saved, isNotNull);
    expect(rapidAscents(review!.findings), isEmpty);
  });
}
