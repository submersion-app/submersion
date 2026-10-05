import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The residual CNS carried into a dive starts from the previous dive's last
/// computer CNS reading. On a dive with several computers that must be the
/// reading of the series the previous dive's own analysis replays (the
/// primary's), not of every computer's samples merged, where the last reading
/// may be another computer's (#2545).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(
    String id,
    DateTime entry,
    List<ProfileSample> samples,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entryMs = entry.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(entryMs),
            entryTime: Value(entryMs),
            exitTime: Value(entryMs + samples.last.timestamp * 1000),
            maxDepth: const Value(30.0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await ProfileSeriesRepository().insertSeries(diveId: id, samples: samples);
  }

  const depths = <double>[0, 15, 30, 30, 30, 30, 15, 5, 0];

  /// One computer's samples of the dive, CNS logged at entry (10%) and on the
  /// last sample ([endCns]).
  List<DiveProfilePoint> computer(double endCns) => [
    for (var i = 0; i < depths.length; i++)
      DiveProfilePoint(
        timestamp: i * 240,
        depth: depths[i],
        cns: i == 0 ? 10.0 : (i == depths.length - 1 ? endCns : null),
      ),
  ];

  /// Seeds a previous dive whose merged samples end on a 60% reading and a
  /// current dive 60 minutes after it with no CNS of its own, and returns the
  /// current dive's analysis under [overrides].
  Future<ProfileAnalysis?> analyseCurrent(List<Override> overrides) async {
    final previousEntry = DateTime(2026, 9, 1, 9);
    await seedDive('previous', previousEntry, [
      for (final p in computer(60.0))
        ProfileSample(timestamp: p.timestamp, depth: p.depth, cns: p.cns),
    ]);
    final previousExit = previousEntry.add(
      Duration(seconds: (depths.length - 1) * 240),
    );
    await seedDive('current', previousExit.add(const Duration(minutes: 60)), [
      for (var i = 0; i < depths.length; i++)
        ProfileSample(timestamp: i * 240, depth: depths[i]),
    ]);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container.read(profileAnalysisProvider('current').future);
  }

  test('residual CNS decays from the previous dive analysed series, not the '
      'merged samples', () async {
    final analysis = await analyseCurrent([
      // The primary computer's own series ends at 30%.
      diveAnalysisSeriesProvider('previous').overrideWith(
        (ref) async =>
            (points: computer(30.0), sourceProfile: null, source: null),
      ),
    ]);

    expect(analysis, isNotNull);
    expect(
      analysis!.o2Exposure.cnsStart,
      closeTo(CnsTable.cnsAfterSurfaceInterval(30.0, 60), 0.001),
    );
  });

  // A dive whose computers overlap and whose primary owns no samples has no
  // series to analyse, and no analysis to fall back to either. The residual
  // must not drop to zero there: it takes the highest last reading among the
  // computers, each read from its own samples.
  test('residual CNS without an analysed series takes the highest source '
      'reading', () async {
    final analysis = await analyseCurrent([
      diveAnalysisSeriesProvider('previous').overrideWith((ref) async => null),
      sourceProfilesProvider('previous').overrideWith(
        (ref) async => {
          'a': SourceProfile(
            sourceId: 'a',
            computerId: 'computer-a',
            isEdited: false,
            points: computer(30.0),
          ),
          'b': SourceProfile(
            sourceId: 'b',
            computerId: 'computer-b',
            isEdited: false,
            points: computer(45.0),
          ),
        },
      ),
    ]);

    expect(analysis, isNotNull);
    expect(
      analysis!.o2Exposure.cnsStart,
      closeTo(CnsTable.cnsAfterSurfaceInterval(45.0, 60), 0.001),
    );
  });
}
