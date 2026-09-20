import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<Set<String>> columns(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v222 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 222);
    expect(AppDatabase.migrationVersions, contains(222));
    expect(AppDatabase.migrationStepCount(221), 1);
    // Table-only rung on device-local tables: the sync floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('the derived metrics table has its fingerprint and no hlc', () async {
    final cols = await columns('dive_derived_metrics');
    expect(
      cols,
      containsAll([
        'dive_id',
        'engine_version',
        'source_updated_at',
        'computed_at',
        'final_stop_kind',
        'final_stop_start_s',
        'final_stop_duration_s',
        'final_stop_depth_stddev_m',
        'final_stop_max_excursion_m',
        'sac_mean_bar_min',
        'sac_slope_bar_min_per_min',
        'runtime_s',
        'unsupported_reason',
      ]),
    );
    // Device-local: never synced, so it carries no clock.
    expect(cols, isNot(contains('hlc')));
  });

  test('the bucket table is keyed by dive and index', () async {
    final cols = await columns('dive_sac_buckets');
    expect(cols, containsAll(['dive_id', 'bucket_index', 'sac_bar_min']));
    expect(cols, isNot(contains('hlc')));
  });

  test('deleting a dive cascades to both tables', () async {
    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
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
    await db
        .into(db.diveSacBuckets)
        .insert(
          DiveSacBucketsCompanion.insert(
            diveId: 'd1',
            bucketIndex: 0,
            sacBarMin: 0.6,
          ),
        );

    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();

    expect(await db.select(db.diveDerivedMetricsRows).get(), isEmpty);
    expect(await db.select(db.diveSacBuckets).get(), isEmpty);
  });

  test('the schema assert is idempotent', () async {
    // It runs from the rung AND from beforeOpen, so a second call on an
    // already-migrated database must not throw.
    await db.assertDerivedMetricsSchemaForTest();
    await db.assertDerivedMetricsSchemaForTest();
    expect(await columns('dive_derived_metrics'), isNotEmpty);
  });
}
