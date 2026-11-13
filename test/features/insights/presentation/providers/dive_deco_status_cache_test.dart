import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/data/repositories/dive_deco_status_repository.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/providers/query_cache_awaits.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Square profile sampled every 10 s, as in deco_obligation_provider_test:
/// 40 m for 25 min busts the NDL at the default GF, 18 m for 30 min does
/// not, each by a wide margin.
List<ProfileSample> _square(double depth, int bottomMinutes) {
  final samples = <ProfileSample>[];
  var t = 0;
  final descent = (depth / 20 * 60).round();
  for (var s = 0; s <= descent; s += 10) {
    samples.add(ProfileSample(timestamp: t = s, depth: depth * s / descent));
  }
  final bottomEnd = t + bottomMinutes * 60;
  for (var s = t + 10; s <= bottomEnd; s += 10) {
    samples.add(ProfileSample(timestamp: t = s, depth: depth));
  }
  final ascent = (depth / 9 * 60).round();
  for (var s = 10; s <= ascent; s += 10) {
    samples.add(
      ProfileSample(timestamp: t + s, depth: depth * (1 - s / ascent)),
    );
  }
  return samples;
}

/// The real repository, with [onScan] run at each deco signal scan.
class _ScanHook extends InsightsRepository {
  _ScanHook(this.onScan);

  final void Function() onScan;

  @override
  Future<DecoSignalScan> scanRecordedDecoSignals({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    bool statsScoped = true,
    Set<String>? onlyDiveIds,
  }) async {
    final scan = await super.scanRecordedDecoSignals(
      diverId: diverId,
      filter: filter,
      statsScoped: statsScoped,
      onlyDiveIds: onlyDiveIds,
    );
    onScan();
    await pumpEventQueue();
    return scan;
  }
}

/// A settings notifier whose latest load failed (see the deco obligation
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

  Future<void> insertDive(String id, {int dayOffset = 0}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          // A day apart, so no dive's residual load reaches another's.
          diveDateTime: Value(now + dayOffset * 86400000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> insertProfile(String diveId, List<ProfileSample> samples) =>
      ProfileSeriesRepository().insertSeries(
        diveId: diveId,
        samples: samples,
        now: now,
      );

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: (await getBaseOverrides()).cast(),
    );
    addTearDown(container.dispose);
    return container;
  }

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  final parser = QueryParser(
    appQueryRegistry,
    dives,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 6, 2),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> sqlIds(String text) async {
    final node = (parser.parse(text) as ParseOk).node;
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  test(
    'a deco search finds the dives the Insights deco card counts (#4461)',
    () async {
      // No deco columns: only the analysis can classify these two.
      await insertDive('deep');
      await insertProfile('deep', _square(40, 25));
      await insertDive('shallow', dayOffset: 1);
      await insertProfile('shallow', _square(18, 30));
      // The computer recorded a deco stop.
      await insertDive('recorded', dayOffset: 2);
      await insertProfile('recorded', [
        const ProfileSample(timestamp: 0, depth: 30, decoType: 2),
      ]);
      await insertDive('no-profile', dayOffset: 3);

      final container = await makeContainer();
      // Readers hold the writer while they wait, as awaitQueryCachesIfRead
      // does; an unheld pass is disposed before it can write.
      final sub = container.listen(diveDecoStatusCacheProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(diveDecoStatusCacheProvider.future);

      // Only the dives the recorded data cannot answer are mirrored.
      expect(await DiveDecoStatusRepository().verdicts(), {
        'deep': true,
        'shallow': false,
      });

      final card = await container.read(decoDiveIdsProvider.future);
      expect(await sqlIds('deco = true'), card.deco.toSet());
      expect(await sqlIds('deco = false'), card.noDeco.toSet());
      expect(await sqlIds('deco = true'), {'deep', 'recorded'});
    },
  );

  test(
    'the dive list Deco filter waits for the analysis rather than reading an '
    'empty cache',
    () async {
      await insertDive('deep');
      await insertProfile('deep', _square(40, 25));
      await insertDive('shallow', dayOffset: 1);
      await insertProfile('shallow', _square(18, 30));

      // Nothing else holds the writer: the id set itself must wait.
      final container = await makeContainer();
      const filter = DiveFilterState(decoOnly: true);
      final sub = container.listen(
        queryFilteredDiveIdsProvider(filter),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(queryFilteredDiveIdsProvider(filter).future),
        {'deep'},
      );
    },
  );

  test(
    'an Insights card under a Deco filter computes once the verdicts are in',
    () async {
      await insertDive('deep');
      await insertProfile('deep', _square(40, 25));
      await insertDive('shallow', dayOffset: 1);
      await insertProfile('shallow', _square(18, 30));

      final container = await makeContainer();
      container.read(insightsFilterProvider.notifier).state =
          const DiveFilterState(decoOnly: true);
      final sub = container.listen(decoObligationStatsProvider, (_, _) {});
      addTearDown(sub.close);

      // The first answer, not one corrected later by a tick.
      final stats = await container.read(decoObligationStatsProvider.future);
      expect(stats.decoCount, 1);
      expect(stats.noDecoCount, 0);
    },
  );

  test('while a Deco filter waits on the first analysis, the analysis '
      'publishes its progress', () async {
    await insertDive('deep');
    await insertProfile('deep', _square(40, 25));
    await insertDive('shallow', dayOffset: 1);
    await insertProfile('shallow', _square(18, 30));

    final container = await makeContainer();
    container.read(insightsFilterProvider.notifier).state =
        const DiveFilterState(decoOnly: true);
    final seen = <({int analyzed, int total})?>[];
    final progress = container.listen(
      diveDecoStatusProgressProvider,
      (_, next) => seen.add(
        next == null ? null : (analyzed: next.analyzed, total: next.total),
      ),
    );
    addTearDown(progress.close);
    final sub = container.listen(decoObligationStatsProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(decoObligationStatsProvider.future);

    // Both bare dives needed the analysis; the bar was cleared after.
    expect(seen, contains((analyzed: 1, total: 2)));
    expect(container.read(diveDecoStatusProgressProvider), isNull);
  });

  test('a pass released part way through clears its progress', () async {
    await insertDive('deep');
    await insertProfile('deep', _square(40, 25));
    await insertDive('shallow', dayOffset: 1);
    await insertProfile('shallow', _square(18, 30));

    final container = await makeContainer();
    final shown = Completer<void>();
    final cleared = Completer<void>();
    final progress = container.listen(diveDecoStatusProgressProvider, (
      _,
      next,
    ) {
      if (next != null && !shown.isCompleted) shown.complete();
      if (next == null && shown.isCompleted && !cleared.isCompleted) {
        cleared.complete();
      }
    });
    addTearDown(progress.close);
    final writer = container.listen(diveDecoStatusCacheProvider, (_, _) {});
    await shown.future;
    // The last reader leaves while the analysis is still running: the list
    // must not keep showing the abandoned pass's count.
    writer.close();
    await cleared.future.timeout(const Duration(seconds: 30));
    expect(container.read(diveDecoStatusProgressProvider), isNull);
  });

  test(
    'a dive excluded from statistics is still classified for a search',
    () async {
      // The card leaves it out of its rate; the dive list still shows it,
      // and a deco search must still find it.
      await insertDive('excluded');
      await (db.update(db.dives)..where((t) => t.id.equals('excluded'))).write(
        const DivesCompanion(excludedFromStats: Value(true)),
      );
      await insertProfile('excluded', _square(40, 25));

      final container = await makeContainer();
      final sub = container.listen(diveDecoStatusCacheProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(diveDecoStatusCacheProvider.future);

      expect(await sqlIds('deco = true'), {'excluded'});
    },
  );

  test(
    'another profile\'s dives are judged under that profile\'s own settings',
    () async {
      // An agent query or a multi-diver import's rules name a profile that
      // is not the active one. Same 18 m, 30 min dive for both: inside the
      // NDL at the default GF, past it at the other profile's GF 10/10.
      final ms = now;
      for (final id in ['me', 'other']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: ms,
                updatedAt: ms,
              ),
            );
      }
      await DiverSettingsRepository().createSettingsForDiver(
        'other',
        settings: const AppSettings(gfLow: 10, gfHigh: 10),
      );
      for (final (id, diver) in [('mine', 'me'), ('theirs', 'other')]) {
        await insertDive(id);
        await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
          DivesCompanion(diverId: Value(diver)),
        );
        await insertProfile(id, _square(18, 30));
      }

      final container = ProviderContainer(
        overrides: [
          ...(await getBaseOverrides()).cast(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
          logFileServiceProvider.overrideWithValue(
            LogFileService(
              logDirectory: p.join(Directory.systemTemp.path, 'submersion'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final ref = container.read(Provider((ref) => ref));

      await prepareQueryCachesFor(ref, 'other', {kDiveDecoStatusTable});
      await prepareQueryCachesFor(
        ref,
        'me',
        {kDiveDecoStatusTable},
        diveIds: {'mine'},
      );

      expect(await DiveDecoStatusRepository().verdicts(), {
        'mine': false,
        'theirs': true,
      });

      // A repeat query on that profile, with nothing written since, does not
      // re-scan it: the row removed behind its back stays removed.
      await db.customStatement(
        "DELETE FROM dive_deco_status WHERE dive_id = 'theirs'",
      );
      await prepareQueryCachesFor(ref, 'other', {kDiveDecoStatusTable});
      expect(await DiveDecoStatusRepository().verdicts(), {'mine': false});

      // An edit to that profile's settings (its gradient factors) re-scans.
      await db.customStatement(
        "DELETE FROM dive_deco_status WHERE dive_id = 'theirs'",
      );
      await db.customStatement(
        "UPDATE diver_settings SET updated_at = updated_at + 1 "
        "WHERE diver_id = 'other'",
      );
      await prepareQueryCachesFor(ref, 'other', {kDiveDecoStatusTable});
      expect(await DiveDecoStatusRepository().verdicts(), {
        'mine': false,
        'theirs': true,
      });
      await db.customStatement(
        "DELETE FROM dive_deco_status WHERE dive_id = 'theirs'",
      );

      // A dive write moves the input count, so the next query re-scans.
      await (db.update(db.dives)..where((t) => t.id.equals('theirs'))).write(
        const DivesCompanion(notes: Value('edited')),
      );
      await pumpEventQueue();
      await prepareQueryCachesFor(ref, 'other', {kDiveDecoStatusTable});
      expect(await DiveDecoStatusRepository().verdicts(), {
        'mine': false,
        'theirs': true,
      });
    },
  );

  test('a profile with a dive the analysis could not judge is re-scanned by '
      'the next query on it', () async {
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    for (final (id, samples) in [
      ('deep', _square(40, 25)),
      ('blip', _square(40, 25)),
    ]) {
      await insertDive(id, dayOffset: id == 'deep' ? 0 : 3);
      await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
        const DivesCompanion(diverId: Value('other')),
      );
      await insertProfile(id, samples);
    }
    // A recording that no longer decodes: a profile row the scan sees, and
    // nothing the analysis can judge.
    await db.customStatement(
      "UPDATE dive_profile_series SET samples = x'00' WHERE dive_id = 'blip'",
    );
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides()).cast(),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
        logFileServiceProvider.overrideWithValue(
          LogFileService(
            logDirectory: p.join(Directory.systemTemp.path, 'submersion'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final ref = container.read(Provider((ref) => ref));

    await prepareQueryCachesFor(ref, 'other', {kDiveDecoStatusTable});
    expect(await DiveDecoStatusRepository().verdicts(), {'deep': true});

    // Nothing written since, but the pass was incomplete: no memo.
    await db.customStatement(
      "DELETE FROM dive_deco_status WHERE dive_id = 'deep'",
    );
    await prepareQueryCachesFor(ref, 'other', {kDiveDecoStatusTable});
    expect(await DiveDecoStatusRepository().verdicts(), {'deep': true});
  });

  test('a targeted refresh judges again when an input is written while it '
      'analyzes', () async {
    // A rule run's refresh has no tick to re-run it: a dive edit that lands
    // mid-analysis must not leave the verdict from before the edit.
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await insertDive('deep');
    await (db.update(db.dives)..where((t) => t.id.equals('deep'))).write(
      const DivesCompanion(diverId: Value('me')),
    );
    await insertProfile('deep', _square(40, 25));
    final writes = StreamController<void>();
    addTearDown(writes.close);
    var scans = 0;
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides()).cast(),
        diveDecoInputWritesProvider.overrideWith(
          (ref) => DecoInputWritesCounter(writes.stream),
        ),
        insightsRepositoryProvider.overrideWith(
          (ref) => _ScanHook(() {
            // The first scan is overtaken by a write.
            if (scans++ == 0) writes.add(null);
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    final ref = container.read(Provider((ref) => ref));

    await refreshDiveDecoStatusFor(ref, 'me', {'deep'}, isActive: true);

    expect(scans, 2);
    expect(await DiveDecoStatusRepository().verdicts(), {'deep': true});
  });

  test('a plan nobody has dived is not analyzed for a search', () async {
    // The search classifies the dives the diver logged; a saved plan is not
    // one, and analyzing every plan would lengthen a cold first pass.
    await insertDive('plan');
    await (db.update(db.dives)..where((t) => t.id.equals('plan'))).write(
      const DivesCompanion(isPlanned: Value(true)),
    );
    await insertProfile('plan', _square(40, 25));

    final container = await makeContainer();
    final sub = container.listen(diveDecoStatusCacheProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(diveDecoStatusCacheProvider.future);

    expect(await DiveDecoStatusRepository().verdicts(), isEmpty);
  });

  test('a refresh whose service was rebuilt mid-analysis raises rather '
      'than leave the caller unprepared', () async {
    await insertDive('deep');
    await insertProfile('deep', _square(40, 25));
    var builds = 0;
    final service = Provider((ref) {
      builds++;
      return ref;
    });
    final container = await makeContainer();
    final sub = container.listen(service, (_, _) {});
    addTearDown(sub.close);
    final ref = container.read(service);

    // The rule engine provider rebuilds part way through the analysis.
    final refresh = refreshDiveDecoStatusFor(ref, 'me', {
      'deep',
    }, isActive: true);
    container.invalidate(service);
    container.read(service);

    await expectLater(refresh, throwsA(isA<StateError>()));
    expect(builds, 2);
  });

  test(
    'an edit no verdict can depend on does not re-scan the logbook',
    () async {
      // With a Deco filter on, a rating or a note must not cost a whole-
      // logbook scan; a gradient factor must.
      await insertDive('deep');
      await insertProfile('deep', _square(40, 25));
      var scans = 0;
      final container = ProviderContainer(
        overrides: [
          ...(await getBaseOverrides()).cast(),
          insightsRepositoryProvider.overrideWith(
            (ref) => _ScanHook(() => scans++),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(diveDecoStatusCacheProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(diveDecoStatusCacheProvider.future);
      expect(scans, 1);

      await (db.update(db.dives)..where((t) => t.id.equals('deep'))).write(
        const DivesCompanion(rating: Value(4), notes: Value('lovely')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await container.read(diveDecoStatusCacheProvider.future);
      expect(scans, 1);

      await (db.update(db.dives)..where((t) => t.id.equals('deep'))).write(
        const DivesCompanion(gradientFactorLow: Value(30)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await container.read(diveDecoStatusCacheProvider.future);
      expect(scans, 2);
    },
  );

  test('verdicts judged on fallback settings after a failed load are not '
      'mirrored', () async {
    // The classification answers on the defaults when the diver's settings
    // fail to load, and keeps none of it; the search must not either.
    await insertDive('deep');
    await insertProfile('deep', _square(40, 25));
    final container = ProviderContainer(
      overrides: (await getBaseOverrides(
        settingsNotifier: _FailedLoadSettingsNotifier(),
      )).cast(),
    );
    addTearDown(container.dispose);
    final sub = container.listen(diveDecoStatusCacheProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(diveDecoStatusCacheProvider.future);

    expect(await DiveDecoStatusRepository().verdicts(), isEmpty);
  });

  test('a targeted refresh judges again when the settings change while it '
      'analyzes', () async {
    // A gradient factor edit is not an input write; the refresh must still
    // not hand a rule run verdicts judged on the old settings.
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await DiverSettingsRepository().createSettingsForDiver('me');
    await insertDive('deep');
    await (db.update(db.dives)..where((t) => t.id.equals('deep'))).write(
      const DivesCompanion(diverId: Value('me')),
    );
    await insertProfile('deep', _square(40, 25));
    var scans = 0;
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides()).cast(),
        insightsRepositoryProvider.overrideWith(
          (ref) => _ScanHook(() {
            if (scans++ == 0) {
              db.customStatement(
                "UPDATE diver_settings SET updated_at = updated_at + 1 "
                "WHERE diver_id = 'me'",
              );
            }
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    final ref = container.read(Provider((ref) => ref));

    await refreshDiveDecoStatusFor(ref, 'me', {'deep'}, isActive: true);

    expect(scans, 2);
  });

  test('a dive whose analysis fails keeps its last verdict', () async {
    // A transient failure must not drop a verdict the search relied on.
    await insertDive('deep');
    await insertProfile('deep', _square(40, 25));
    final container = await makeContainer();
    final sub = container.listen(diveDecoStatusCacheProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(diveDecoStatusCacheProvider.future);
    expect(await DiveDecoStatusRepository().verdicts(), {'deep': true});

    // The recording no longer decodes, and its stamp moved, so the
    // classification cache cannot answer for it either.
    await db.customStatement(
      "UPDATE dive_profile_series SET samples = x'00', "
      "updated_at = updated_at + 1 WHERE dive_id = 'deep'",
    );
    // A fresh container: no analysis held in memory from the first pass.
    final next = await makeContainer();
    final nextSub = next.listen(diveDecoStatusCacheProvider, (_, _) {});
    addTearDown(nextSub.close);
    await next.read(diveDecoStatusCacheProvider.future);

    expect(await DiveDecoStatusRepository().verdicts(), {'deep': true});
  });

  test('the write counter follows a database reopened in place', () async {
    // A storage-location move installs a new database without a restart:
    // a counter still on the old connection would stop counting, and a
    // pass from before would read as current.
    final container = await makeContainer();
    final sub = container.listen(diveDecoInputWritesProvider, (_, _) {});
    addTearDown(sub.close);
    final before = container.read(diveDecoInputWritesProvider);

    final reopened = await setUpTestDatabase();
    db = reopened;
    await pumpEventQueue();
    final afterReopen = container.read(diveDecoInputWritesProvider);
    expect(afterReopen, isNot(before));

    await insertDive('fresh');
    await pumpEventQueue();
    expect(container.read(diveDecoInputWritesProvider), isNot(afterReopen));
  });

  test('a dive written later is classified on the next pass', () async {
    await insertDive('shallow');
    await insertProfile('shallow', _square(18, 30));

    final container = await makeContainer();
    final sub = container.listen(diveDecoStatusCacheProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(diveDecoStatusCacheProvider.future);
    expect(await sqlIds('deco = true'), isEmpty);

    await insertDive('deep', dayOffset: 1);
    await insertProfile('deep', _square(40, 25));
    // The writer follows dive and profile writes, debounced.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await container.read(diveDecoStatusCacheProvider.future);

    expect(await sqlIds('deco = true'), {'deep'});
  });
}
