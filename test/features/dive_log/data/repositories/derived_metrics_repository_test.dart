import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  var runs = 0;

  DerivedMetricsRepository repo({DiveDerivedMetrics? result}) {
    runs = 0;
    return DerivedMetricsRepository(
      runner: (input) async {
        runs++;
        return result ??
            DiveDerivedMetrics(
              diveId: input.diveId,
              engineVersion: DerivedMetricsService.version,
              sourceUpdatedAt: input.sourceUpdatedAt,
              computedAt: input.computedAtMs,
              finalStopKind: FinalStopKind.safety,
              finalStopDurationSeconds: 180,
              finalStopMaxExcursionMeters: 1.4,
              sacMeanBarPerMin: 0.6,
              sacSlopeBarPerMinPerMin: 0.05,
              sacChangePercent: 25,
              sacBuckets: const [
                SacBucket(index: 0, sacBarPerMin: 0.5),
                SacBucket(index: 1, sacBarPerMin: 0.7),
              ],
            );
      },
    );
  }

  Future<void> insertDive(String id, {int? updatedAt}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(updatedAt ?? now),
        ),
      );

  test('ensureCurrent computes, stores and returns the metrics', () async {
    await insertDive('d1');
    final r = repo();
    final metrics = await r.ensureCurrent('d1');
    expect(metrics, isNotNull);
    expect(runs, 1);
    expect(metrics!.finalStopKind, FinalStopKind.safety);

    final stored = await r.getMetrics('d1');
    expect(stored!.sacMeanBarPerMin, 0.6);
    expect(stored.sacChangePercent, 25);
    expect(stored.sacTrend, SacTrend.rising);
    expect(stored.finalStopState, FinalStopState.unstable);
    expect(stored.finalStopDurationSeconds, 180);
    expect(stored.unsupportedReason, isNull);
    // Buckets are the engine's working, never stored.
    expect(stored.sacBuckets, isEmpty);
  });

  test('the query columns hold the names the dive fields list', () async {
    await insertDive('d1');
    await repo().ensureCurrent('d1');
    final row = await db.select(db.diveDerivedMetricsRows).getSingle();
    expect(row.sacTrend, 'rising');
    expect(row.finalStopState, 'unstable');
    expect(row.sacChangePct, 25);
  });

  test(
    'an unsupported reason round-trips and leaves the fields empty',
    () async {
      await insertDive('d1');
      final r = repo(
        result: DiveDerivedMetrics(
          diveId: 'd1',
          engineVersion: DerivedMetricsService.version,
          sourceUpdatedAt: now,
          computedAt: now,
          unsupportedReason: UnsupportedReason.gaugeMode,
        ),
      );
      await r.ensureCurrent('d1');
      final stored = await r.getMetrics('d1');
      expect(stored!.unsupportedReason, UnsupportedReason.gaugeMode);
      expect(stored.finalStopKind, FinalStopKind.none);
      final row = await db.select(db.diveDerivedMetricsRows).getSingle();
      expect(row.sacTrend, isNull);
      expect(row.finalStopState, isNull);
    },
  );

  test('a second call reads the stored row without recomputing', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1');
    expect(runs, 1);
  });

  test('force recomputes even when the row is current', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1', force: true);
    expect(runs, 2);
  });

  test('a dive that does not exist yields null and no work', () async {
    final r = repo();
    expect(await r.ensureCurrent('missing'), isNull);
    expect(runs, 0);
  });

  group('staleDiveIds', () {
    test('lists a dive with no row', () async {
      await insertDive('d1');
      expect(await repo().staleDiveIds(), ['d1']);
    });

    test('lists a dive whose engine version is older', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await db.customStatement(
        'UPDATE dive_derived_metrics SET engine_version = 0',
      );
      expect(await r.staleDiveIds(), ['d1']);
    });

    test('lists a dive whose source stamp drifted', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        DivesCompanion(updatedAt: Value(now + 1)),
      );
      expect(await r.staleDiveIds(), ['d1']);
    });

    test('omits a dive that is current', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      expect(await r.staleDiveIds(), isEmpty);
    });

    test('returns the newest dive first', () async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('new'),
              diveDateTime: Value(now + 1000),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await insertDive('old');
      // The dives a diver searches most are the recent ones.
      expect(await repo().staleDiveIds(), ['new', 'old']);
    });

    test('a diver filter narrows the work list', () async {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value('diver1'),
              name: const Value('Ada'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('mine'),
              diverId: const Value('diver1'),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await insertDive('theirs');
      expect(await repo().staleDiveIds(diverId: 'diver1'), ['mine']);
    });
  });

  test('the change tick fires on a metrics write', () async {
    await insertDive('d1');
    final r = repo();
    final ticks = <void>[];
    final sub = r.watchChanges().listen(ticks.add);
    await r.ensureCurrent('d1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(ticks, isNotEmpty);
  });
}
