import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
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
  // The revision of a seeded dive: its own stamp plus its one profile series.
  final seededRevision = now * 2;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id, {int? at}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at ?? now),
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

  test('the deco ids are the dives the counts came from (#3805)', () async {
    await insertDive('deep');
    await insertBareProfile('deep', 40, 25);
    await insertDive('shallow');
    await insertBareProfile('shallow', 18, 30);
    await insertDive('no-profile');

    final container = await makeContainer();
    final ids = await container.read(decoDiveIdsProvider.future);
    final stats = await container.read(decoObligationStatsProvider.future);

    expect(ids.deco, ['deep']);
    expect(ids.noDeco, ['shallow']);
    expect(ids.unknown, ['no-profile']);
    expect(stats.decoCount, ids.deco.length);
    expect(stats.noDecoCount, ids.noDeco.length);
    expect(stats.unknownCount, ids.unknown.length);
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
        diveRevision: seededRevision,
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
        diveRevision: seededRevision,
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
        diveRevision: seededRevision,
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

  // Issue #3807: the residual lookback reads the previous dive's analysis with
  // nobody listening to it, so invalidating that analysis mid-load stranded
  // the lookback and with it the whole pass.
  test(
    'a lookback analysis invalidated mid-load does not strand the pass',
    () async {
      final twoHours = const Duration(hours: 2).inMilliseconds;
      await insertDive('later', at: now + twoHours);
      await insertBareProfile('later', 18, 30);
      // A recorded deco signal keeps this dive out of the pass, so the only
      // reader of its analysis is the later dive's lookback.
      await insertDive('earlier');
      await ProfileSeriesRepository().insertSeries(
        diveId: 'earlier',
        samples: const [
          ProfileSample(timestamp: 0, depth: 9.0, decoType: 2, ceiling: 9.0),
        ],
        now: now,
      );
      final (depths, times) = _square(18, 30);
      final previous = ProfileAnalysisService().analyze(
        diveId: 'earlier',
        depths: depths,
        timestamps: times,
      );

      final gate = Completer<void>();
      final started = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          ...(await getBaseOverrides()),
          profileAnalysisProvider('earlier').overrideWith((ref) async {
            if (!started.isCompleted) started.complete();
            await gate.future;
            return previous.copyWith(
              inputsFingerprint: ref
                  .read(diverAnalysisSettingsProvider)
                  .fingerprint,
            );
          }),
        ].cast(),
      );
      addTearDown(container.dispose);

      final result = container.read(decoObligationStatsProvider.future);
      await started.future.timeout(const Duration(seconds: 5));
      container.invalidate(profileAnalysisProvider('earlier'));
      await pumpEventQueue();
      gate.complete();

      final stats = await result.timeout(const Duration(seconds: 10));
      expect(stats.decoCount + stats.noDecoCount, 2);
    },
  );

  // Issue #3807: a first pass runs for minutes on a phone, so the counts are
  // published as they are worked out instead of arriving all at the end.
  group('progress', () {
    Future<List<DecoClassificationProgress?>> runPass(
      ProviderContainer container,
    ) async {
      final seen = <DecoClassificationProgress?>[];
      final sub = container.listen(
        decoClassificationProgressProvider,
        (_, next) => seen.add(next),
      );
      addTearDown(sub.close);
      await container.read(decoObligationStatsProvider.future);
      return seen;
    }

    test('counts what is already known before analyzing anything', () async {
      await insertDive('recorded');
      await ProfileSeriesRepository().insertSeries(
        diveId: 'recorded',
        samples: const [
          ProfileSample(timestamp: 0, depth: 9.0, decoType: 2, ceiling: 9.0),
        ],
        now: now,
      );
      await insertDive('manual');
      await insertDive('cached');
      await insertBareProfile('cached', 40, 25);
      await insertDive('shallow');
      await insertBareProfile('shallow', 18, 30);

      final container = await makeContainer();
      await DecoClassificationCacheRepository().put(
        'cached',
        hadDeco: false,
        inputsHash: decoInputsHash(
          engineVersion: analysisEngineVersion,
          settingsFingerprint: container
              .read(diverAnalysisSettingsProvider)
              .fingerprint,
          diveRevision: seededRevision,
        ),
      );

      final seen = await runPass(container);

      final first = seen.first!;
      expect(first.stats.decoCount, 1, reason: 'the recorded dive');
      expect(first.stats.noDecoCount, 1, reason: 'the cached dive');
      expect(first.stats.unknownCount, 1, reason: 'the dive with no profile');
      expect(first.analyzed, 1, reason: 'the cached dive needs no analysis');
      expect(first.total, 2);
    });

    test('moves on after each dive and clears when the pass ends', () async {
      await insertDive('deep');
      await insertBareProfile('deep', 40, 25);
      await insertDive('shallow');
      await insertBareProfile('shallow', 18, 30);

      final seen = await runPass(await makeContainer());

      expect(seen.last, isNull, reason: 'the card takes the final result');
      final steps = seen.whereType<DecoClassificationProgress>().toList();
      expect(steps.map((p) => p.analyzed), [0, 1]);
      expect(steps.last.total, 2);
      expect(
        steps.last.stats.decoCount + steps.last.stats.noDecoCount,
        1,
        reason: 'the first dive is counted, the second is still to do',
      );
    });

    test('a dive that yields nothing counts as unknown, not pending', () async {
      await insertDive('one');
      await insertBareProfile('one', 40, 25);
      await insertDive('two');
      await insertBareProfile('two', 18, 30);
      final container = ProviderContainer(
        overrides: [
          ...(await getBaseOverrides()),
          profileAnalysisProvider('one').overrideWith((ref) async => null),
          profileAnalysisProvider('two').overrideWith((ref) async => null),
        ].cast(),
      );
      addTearDown(container.dispose);

      final seen = await runPass(container);

      final steps = seen.whereType<DecoClassificationProgress>().toList();
      expect(steps.last.stats.unknownCount, 1);
      expect(steps.last.analyzed, 1);
    });

    test('a new pass clears what a replaced pass left behind', () async {
      await insertDive('deep');
      await insertBareProfile('deep', 40, 25);
      final container = await makeContainer();
      container.read(decoClassificationProgressProvider.notifier).state = (
        stats: (decoCount: 7, noDecoCount: 0, unknownCount: 0),
        analyzed: 7,
        total: 99,
      );

      final seen = await runPass(container);

      expect(
        seen.first,
        isNull,
        reason: 'the card must not show the previous pass as this one',
      );
    });

    test('nothing is published when there is nothing to analyze', () async {
      await insertDive('manual');

      expect(await runPass(await makeContainer()), everyElement(isNull));
    });
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
