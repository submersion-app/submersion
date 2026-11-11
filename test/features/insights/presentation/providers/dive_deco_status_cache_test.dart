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

  test('while an Insights Deco filter waits on the first analysis, the deco '
      'card shows its progress', () async {
    await insertDive('deep');
    await insertProfile('deep', _square(40, 25));
    await insertDive('shallow', dayOffset: 1);
    await insertProfile('shallow', _square(18, 30));

    final container = await makeContainer();
    container.read(insightsFilterProvider.notifier).state =
        const DiveFilterState(decoOnly: true);
    final seen = <({int analyzed, int total})?>[];
    final progress = container.listen(
      decoClassificationProgressProvider,
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
    expect(container.read(decoClassificationProgressProvider), isNull);
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
    },
  );

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
