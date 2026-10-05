import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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

  test('residual CNS decays from the previous dive analysed series, not the '
      'merged samples', () async {
    final previousEntry = DateTime(2026, 9, 1, 9);
    // The merged samples end on another computer's reading (60%).
    await seedDive('previous', previousEntry, [
      for (var i = 0; i < depths.length; i++)
        ProfileSample(
          timestamp: i * 240,
          depth: depths[i],
          cns: i == 0 ? 10.0 : (i == depths.length - 1 ? 60.0 : null),
        ),
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
        // The primary computer's own series ends at 30%.
        diveAnalysisSeriesProvider('previous').overrideWith(
          (ref) async => (
            points: [
              for (var i = 0; i < depths.length; i++)
                DiveProfilePoint(
                  timestamp: i * 240,
                  depth: depths[i],
                  cns: i == 0 ? 10.0 : (i == depths.length - 1 ? 30.0 : null),
                ),
            ],
            sourceProfile: null,
            source: null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final analysis = await container.read(
      profileAnalysisProvider('current').future,
    );

    expect(analysis, isNotNull);
    expect(
      analysis!.o2Exposure.cnsStart,
      closeTo(CnsTable.cnsAfterSurfaceInterval(30.0, 60), 0.001),
    );
  });
}
