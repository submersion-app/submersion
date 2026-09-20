import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/derived_metrics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  DerivedMetricsRepository fakeRepo() => DerivedMetricsRepository(
    runner: (input) async => DiveDerivedMetrics(
      diveId: input.diveId,
      engineVersion: DerivedMetricsService.version,
      sourceUpdatedAt: input.sourceUpdatedAt,
      computedAt: input.computedAtMs,
      finalStopKind: FinalStopKind.safety,
    ),
  );

  test('the provider computes through to a stored row', () async {
    await insertDive('d1');
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(
      overrides: [
        ...overrides,
        derivedMetricsRepositoryProvider.overrideWithValue(fakeRepo()),
      ],
    );
    addTearDown(container.dispose);

    final metrics = await container.read(
      diveDerivedMetricsProvider('d1').future,
    );
    expect(metrics!.finalStopKind, FinalStopKind.safety);

    // Computed through means stored: a second reader sees the row without
    // the engine running again.
    final stored = await DerivedMetricsRepository().getMetrics('d1');
    expect(stored!.finalStopKind, FinalStopKind.safety);
  });

  test('a dive that does not exist resolves to null', () async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(
      overrides: [
        ...overrides,
        derivedMetricsRepositoryProvider.overrideWithValue(fakeRepo()),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(diveDerivedMetricsProvider('missing').future),
      isNull,
    );
  });

  test('the detail tick covers the derived tables', () async {
    // The sweep writes them outside any notifier, so an open dive page needs
    // this stream to carry them or it shows stale numbers until a restart.
    await insertDive('d1');
    final repo = DiveRepository();
    final ticks = <void>[];
    final sub = repo.watchDiveDetailChanges().listen(ticks.add);
    await db
        .into(db.diveDerivedMetricsRows)
        .insert(
          DiveDerivedMetricsRowsCompanion.insert(
            diveId: 'd1',
            engineVersion: 1,
            sourceUpdatedAt: now,
            computedAt: now,
          ),
        );
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    expect(ticks, isNotEmpty, reason: 'dive_derived_metrics');

    ticks.clear();
    await db
        .into(db.diveSacBuckets)
        .insert(
          DiveSacBucketsCompanion.insert(
            diveId: 'd1',
            bucketIndex: 0,
            sacBarMin: 0.5,
          ),
        );
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    await sub.cancel();
    expect(ticks, isNotEmpty, reason: 'dive_sac_buckets');
  });
}
