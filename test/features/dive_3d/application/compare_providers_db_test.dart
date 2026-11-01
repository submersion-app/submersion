import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../helpers/test_database.dart';

/// The comparison against a real database: the fakes in
/// compare_providers_test.dart cannot tell whether its tick names real tables,
/// or whether the writes that change what it shows reach it.
void main() {
  const now = 1750000000000;

  late AppDatabase db;
  late ProfileSeriesRepository series;
  late ProviderContainer container;

  var counter = 0;

  Future<void> insertSite(String id, String name) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(name),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertDive(String id, {String? siteId, int? diveNumber}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          siteId: Value(siteId),
          diveNumber: Value(diveNumber),
          diveDateTime: const Value(now),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertProfile(
    String diveId, {
    double maxDepth = 20,
    String? sourceId,
    bool isPrimary = true,
  }) => series.insertSeries(
    id: 'series-${counter++}',
    diveId: diveId,
    sourceId: sourceId,
    isPrimary: isPrimary,
    now: now,
    samples: [
      const ProfileSample(timestamp: 0, depth: 0),
      ProfileSample(timestamp: 60, depth: maxDepth),
      const ProfileSample(timestamp: 120, depth: 0),
    ],
  );

  /// Holds the comparison of [key] as the page does and completes with the
  /// first result [matches] accepts.
  Future<DiveComparison> whenComparison(
    DiveIdSet key,
    bool Function(DiveComparison) matches,
  ) {
    final found = Completer<DiveComparison>();
    final subscription = container.listen(diveComparisonProfilesProvider(key), (
      _,
      next,
    ) {
      final value = next.value;
      if (value != null && matches(value) && !found.isCompleted) {
        found.complete(value);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);
    return found.future.timeout(const Duration(seconds: 10));
  }

  setUp(() async {
    db = await setUpTestDatabase();
    series = ProfileSeriesRepository();
    counter = 0;
    container = ProviderContainer(
      overrides: [diveRepositoryProvider.overrideWithValue(DiveRepository())],
    );
    addTearDown(container.dispose);
  });

  tearDown(tearDownTestDatabase);

  test('compares the first usable dives of a selection', () async {
    await insertSite('site', 'Blue Hole');
    await insertDive('manual');
    await insertDive('d0', siteId: 'site', diveNumber: 1);
    await insertProfile('d0', maxDepth: 31);
    final rest = [for (var i = 1; i < 10; i++) 'd$i'];
    for (final (index, id) in rest.indexed) {
      await insertDive(id, diveNumber: index + 2);
      await insertProfile(id);
    }

    final comparison = await whenComparison(
      DiveIdSet(['manual', 'd0', ...rest]),
      (_) => true,
    );

    expect(comparison.comparableCount, 10);
    expect(comparison.profiles.map((p) => p.id), [
      'd0',
      ...rest.take(kMaxComparisonProfiles - 1),
    ]);
    final reference = comparison.profiles.first;
    expect(reference.label, 'Blue Hole');
    expect(reference.times, [0, 60, 120]);
    expect(reference.depths, [0, 31, 0]);
    expect(reference.maxDepthMeters, 31);
    expect(comparison.profiles[1].label, '#2');
  });

  test('a renamed site relabels the comparison', () async {
    await insertSite('site', 'Old name');
    await insertDive('a', siteId: 'site');
    await insertDive('b');
    await insertProfile('a');
    await insertProfile('b');
    final key = DiveIdSet(['a', 'b']);
    await whenComparison(key, (c) => c.profiles.first.label == 'Old name');

    await (db.update(db.diveSites)..where((t) => t.id.equals('site'))).write(
      const DiveSitesCompanion(name: Value('New name')),
    );

    await whenComparison(key, (c) => c.profiles.first.label == 'New name');
  });

  test('a primary source swap shows the new primary profile', () async {
    await insertDive('a');
    await insertDive('b');
    await insertProfile('b');
    final importedAt = DateTime.utc(2026);
    for (final (id, isPrimary) in [('first', true), ('second', false)]) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(id),
              diveId: const Value('a'),
              isPrimary: Value(isPrimary),
              importedAt: Value(importedAt),
              createdAt: Value(importedAt),
            ),
          );
    }
    await insertProfile('a', sourceId: 'first', maxDepth: 12, isPrimary: true);
    await insertProfile(
      'a',
      sourceId: 'second',
      maxDepth: 44,
      isPrimary: false,
    );
    final key = DiveIdSet(['a', 'b']);
    await whenComparison(key, (c) => c.profiles.first.maxDepthMeters == 12);

    // Only the source rows change, as a swap of the primary flag does.
    await (db.update(db.diveDataSources)..where((t) => t.diveId.equals('a')))
        .write(const DiveDataSourcesCompanion(isPrimary: Value(false)));
    await (db.update(db.diveDataSources)..where((t) => t.id.equals('second')))
        .write(const DiveDataSourcesCompanion(isPrimary: Value(true)));

    await whenComparison(key, (c) => c.profiles.first.maxDepthMeters == 44);
  });

  test('a renumbered dive relabels the comparison', () async {
    await insertDive('a', diveNumber: 1);
    await insertDive('b');
    await insertProfile('a');
    await insertProfile('b');
    final key = DiveIdSet(['a', 'b']);
    await whenComparison(key, (c) => c.profiles.first.label == '#1');

    await (db.update(db.dives)..where((t) => t.id.equals('a'))).write(
      const DivesCompanion(diveNumber: Value(2)),
    );

    await whenComparison(key, (c) => c.profiles.first.label == '#2');
  });

  test('a deleted dive leaves the comparison', () async {
    for (final id in ['a', 'b', 'c']) {
      await insertDive(id);
      await insertProfile(id);
    }
    final key = DiveIdSet(['a', 'b', 'c']);
    await whenComparison(key, (c) => c.comparableCount == 3);

    await (db.delete(db.dives)..where((t) => t.id.equals('b'))).go();

    final comparison = await whenComparison(key, (c) => c.comparableCount == 2);
    expect(comparison.profiles.map((p) => p.id), ['a', 'c']);
  });

  test('a dive gaining a profile joins the comparison', () async {
    await insertDive('a');
    await insertDive('b');
    await insertDive('later');
    await insertProfile('a');
    await insertProfile('b');
    final key = DiveIdSet(['a', 'b', 'later']);
    await whenComparison(key, (c) => c.comparableCount == 2);

    await insertProfile('later');

    final comparison = await whenComparison(key, (c) => c.comparableCount == 3);
    expect(comparison.profiles.map((p) => p.id), ['a', 'b', 'later']);
  });
}
