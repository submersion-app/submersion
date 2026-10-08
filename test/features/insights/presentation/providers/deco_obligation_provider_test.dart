import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/analysis_settings_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/insights/data/repositories/deco_classification_cache.dart';
import 'package:submersion/features/insights/data/services/deco_classification_service.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Square profile: descend at 20 m/min, hold [depth] for [bottomMinutes], then
/// ascend at 9 m/min, sampled every 10 s.
///
/// The two fixtures below were chosen by running ProfileAnalysisService over a
/// sweep of depth/duration pairs at the default GF 50/85 and taking one that
/// clears the NDL by a wide margin and one that busts it outright. Do not
/// nudge them without re-running that check: a fixture sitting on the boundary
/// would make these tests assert nothing.
(List<double>, List<int>) _square(double depth, int bottomMinutes) {
  final depths = <double>[];
  final times = <int>[];
  var t = 0;
  final descentSeconds = (depth / 20 * 60).round();
  for (var s = 0; s <= descentSeconds; s += 10) {
    depths.add(depth * s / descentSeconds);
    times.add(t = s);
  }
  final bottomEnd = t + bottomMinutes * 60;
  for (var s = t + 10; s <= bottomEnd; s += 10) {
    depths.add(depth);
    times.add(t = s);
  }
  final ascentSeconds = (depth / 9 * 60).round();
  for (var s = 10; s <= ascentSeconds; s += 10) {
    depths.add(depth * (1 - s / ascentSeconds));
    times.add(t + s);
  }
  return (depths, times);
}

/// A settings notifier whose latest load failed (see the safety review
/// provider test of the same name).
class _FailedLoadSettingsNotifier extends MockSettingsNotifier {
  @override
  Future<void> get settingsLoaded async =>
      throw StateError('settings read failed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalCacheDatabase cacheDb;

  final now = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Writes a series carrying depth only: no deco_type, no ceiling, no
  /// events. This is what MacDive, Shearwater Cloud, generic UDDF, CSV and
  /// OCR imports produce, and it is the shape that made the card report zero.
  Future<void> insertBareProfile(
    String diveId,
    double depth,
    int bottomMinutes,
  ) async {
    final (depths, times) = _square(depth, bottomMinutes);
    await ProfileSeriesRepository().insertSeries(
      diveId: diveId,
      samples: [
        for (var i = 0; i < depths.length; i++)
          ProfileSample(timestamp: times[i], depth: depths[i]),
      ],
      now: now,
    );
  }

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: (await getBaseOverrides()).cast(),
    );
    addTearDown(container.dispose);
    return container;
  }

  test('classifies a bare profile that busts the NDL as a deco dive', () async {
    await insertDive('deep');
    await insertBareProfile('deep', 40, 25);

    final stats = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );

    expect(stats.decoCount, 1);
    expect(stats.noDecoCount, 0);
    expect(stats.unknownCount, 0);
  });

  test('classifies a bare profile inside the NDL as a no-deco dive', () async {
    await insertDive('shallow');
    await insertBareProfile('shallow', 18, 30);

    final stats = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );

    expect(stats.decoCount, 0);
    expect(stats.noDecoCount, 1);
    expect(stats.unknownCount, 0);
  });

  test('reports a mixed library with a real rate', () async {
    await insertDive('deep');
    await insertBareProfile('deep', 40, 25);
    await insertDive('shallow');
    await insertBareProfile('shallow', 18, 30);

    final stats = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );

    expect(stats.decoCount, 1);
    expect(stats.noDecoCount, 1);
    expect(stats.unknownCount, 0);
  });

  test('a dive with no profile stays unclassified', () async {
    await insertDive('manual');

    final stats = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );

    expect(stats.decoCount, 0);
    expect(stats.noDecoCount, 0);
    expect(stats.unknownCount, 1);
  });

  test('recorded deco_type still wins without running the analysis', () async {
    // A shallow profile the model would clear, but whose computer recorded a
    // deco stop. The recorded signal must take priority.
    await insertDive('recorded');
    await insertBareProfile('recorded', 18, 30);
    await ProfileSeriesRepository().insertSeries(
      diveId: 'recorded',
      samples: const [
        ProfileSample(timestamp: 99999, depth: 9.0, decoType: 2, ceiling: 9.0),
      ],
      now: now,
    );

    final stats = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );

    expect(stats.decoCount, 1);
    expect(stats.noDecoCount, 0);
    expect(stats.unknownCount, 0);
  });

  test('a second read is served from the cache', () async {
    await insertDive('deep');
    await insertBareProfile('deep', 40, 25);

    final first = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );
    expect(first.decoCount, 1);

    final cached = await cacheDb.select(cacheDb.decoClassificationCache).get();
    expect(cached, hasLength(1));
    expect(cached.single.diveId, 'deep');
    expect(cached.single.hadDeco, isTrue);

    final second = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );
    expect(second.decoCount, 1);
  });

  test('a cache hit short-circuits the analysis entirely', () async {
    await insertDive('deep');
    await insertBareProfile('deep', 40, 25);

    // Seed an entry that contradicts what the analysis would compute. If the
    // provider reports no-deco, the cached value was used and the profile was
    // never hydrated, which is the whole point of the fingerprint being
    // derivable from the scan alone.
    final container = await makeContainer();
    await DecoClassificationCacheRepository().put(
      'deep',
      hadDeco: false,
      inputsHash: decoInputsHash(
        engineVersion: analysisEngineVersion,
        settingsFingerprint: container
            .read(diverAnalysisSettingsProvider)
            .fingerprint,
        diveUpdatedAt: now,
      ),
    );

    final stats = await container.read(decoObligationStatsProvider.future);

    expect(stats.decoCount, 0);
    expect(stats.noDecoCount, 1);
  });

  // Issue #2592: the entry records every setting the analysis read, not just
  // the gradient factors. One stored under the same GF but another diver
  // setting (here the deco ppO2 limit, which picks the ascent gases) was
  // computed on different inputs and must not be served.
  test('a classification cached on other settings is recomputed', () async {
    await insertDive('deep');
    await insertBareProfile('deep', 40, 25);

    final container = await makeContainer();
    final active = container.read(diverAnalysisSettingsProvider);
    final other = active.copyWith(ppO2MaxDeco: active.ppO2MaxDeco - 0.2);
    expect(other.gfLow, active.gfLow);
    expect(other.gfHigh, active.gfHigh);
    await DecoClassificationCacheRepository().put(
      'deep',
      hadDeco: false,
      inputsHash: decoInputsHash(
        engineVersion: analysisEngineVersion,
        settingsFingerprint: other.fingerprint,
        diveUpdatedAt: now,
      ),
    );

    final stats = await container.read(decoObligationStatsProvider.future);

    expect(stats.decoCount, 1, reason: 'the stale entry was not served');
    final cached = await cacheDb.select(cacheDb.decoClassificationCache).get();
    expect(
      cached.single.inputsHash,
      decoInputsHash(
        engineVersion: analysisEngineVersion,
        settingsFingerprint: active.fingerprint,
        diveUpdatedAt: now,
      ),
      reason: 'the recomputed entry records the settings it ran on',
    );
  });

  test('nothing is cached when the diver settings failed to load', () async {
    await insertDive('deep');
    await insertBareProfile('deep', 40, 25);

    final container = ProviderContainer(
      overrides: (await getBaseOverrides(
        settingsNotifier: _FailedLoadSettingsNotifier(),
      )).cast(),
    );
    addTearDown(container.dispose);

    final stats = await container.read(decoObligationStatsProvider.future);

    expect(stats.decoCount, 1, reason: 'the pass still answers');
    final cached = await cacheDb.select(cacheDb.decoClassificationCache).get();
    expect(cached, isEmpty, reason: 'but keeps nothing under those settings');
  });

  // Copilot review on #2748: an analysis that records no inputs cannot show
  // it ran on the diver's settings.
  test(
    'an analysis that records no inputs is neither reported nor cached',
    () async {
      await insertDive('deep');
      await insertBareProfile('deep', 40, 25);
      final (depths, times) = _square(40, 25);
      final unstamped = ProfileAnalysisService().analyze(
        diveId: 'deep',
        depths: depths,
        timestamps: times,
      );
      expect(unstamped.inputsFingerprint, isNull);

      final container = ProviderContainer(
        overrides: [
          ...(await getBaseOverrides()),
          profileAnalysisProvider(
            'deep',
          ).overrideWith((ref) async => unstamped),
        ].cast(),
      );
      addTearDown(container.dispose);

      final stats = await container.read(decoObligationStatsProvider.future);

      // Like any result from inputs other than its hash (#2746), it is neither
      // reported nor cached: the dive stays unclassified.
      expect(stats.decoCount, 0);
      expect(stats.unknownCount, 1);
      final cached = await cacheDb
          .select(cacheDb.decoClassificationCache)
          .get();
      expect(cached, isEmpty);
    },
  );

  test('editing a dive invalidates its cached classification', () async {
    await insertDive('deep');
    await insertBareProfile('deep', 40, 25);

    final first = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );
    expect(first.decoCount, 1);

    // Replace the profile with one well inside the NDL and bump updated_at,
    // exactly as an edit would. The stale entry must not be served.
    await ProfileSeriesRepository().deleteForDive('deep');
    await insertBareProfile('deep', 18, 30);
    await (db.update(db.dives)..where((t) => t.id.equals('deep'))).write(
      DivesCompanion(updatedAt: Value(now + 1000)),
    );

    final second = await (await makeContainer()).read(
      decoObligationStatsProvider.future,
    );

    expect(second.decoCount, 0);
    expect(second.noDecoCount, 1);
  });
}
