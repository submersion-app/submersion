import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Rows written before their table was HLC-capable carry `hlc = NULL` and are
/// invisible to the incremental export (`NULL > watermark` is not true). Two
/// ways a table ends up in that state: it gained the column late
/// (media_enrichment, schema v130) or it had the column all along but its
/// entity type was never registered in `hlcTargets`, so nothing stamped it
/// (issue #1144). The backfill stamps a fresh HLC either way so the rows
/// replicate on the next sync.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<String?> hlcOf(String table, String id) async {
    final row = await db
        .customSelect(
          'SELECT hlc FROM "$table" WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.read<String?>('hlc');
  }

  Future<Set<String>> pendingIdsFor(String entityType) async {
    final rows = await (db.select(
      db.syncRecords,
    )..where((t) => t.entityType.equals(entityType))).get();
    return rows.map((r) => r.recordId).toSet();
  }

  // A dive + media so the enrichment row's FKs resolve, then an enrichment row
  // with NO hlc, exactly as a pre-v130 build wrote it.
  Future<void> seedLegacyEnrichment(String enrichmentId) async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await SyncDataSerializer().upsertRecord('media', {
      'id': 'm1',
      'diveId': 'd1',
      'filePath': '/p.jpg',
      'fileType': 'photo',
      'sourceType': 'platformGallery',
      'isFavorite': false,
      'isOrphaned': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await db.customStatement(
      "INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, "
      "match_confidence, created_at) "
      "VALUES ('$enrichmentId', 'm1', 'd1', 12.5, 'exact', 1000)",
    );
  }

  // Rows in the five tables that declared an hlc column but were missing from
  // hlcTargets until #1144, written the way an affected build wrote them: no
  // hlc, because _stampHlc silently no-opped for their entity types.
  Future<void> seedUnstampedEntities() async {
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('eq-1', 'Reg', 'regulator', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO equipment_sets (id, name, created_at, updated_at) "
      "VALUES ('set-1', 'Cold water', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO equipment_set_geofences "
      "(id, set_id, latitude, longitude, radius_meters, created_at, updated_at)"
      " VALUES ('fence-1', 'set-1', 36.62, -121.9, 24000, 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO service_kinds (id, name, created_at, updated_at) "
      "VALUES ('kind-1', 'Annual service', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO service_kinds (id, name, is_built_in, created_at, "
      "updated_at) VALUES ('kind-builtin', 'Hydro', 1, 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO service_schedules "
      "(id, equipment_id, service_kind_id, created_at, updated_at) "
      "VALUES ('sched-1', 'eq-1', 'kind-1', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO cylinder_configs (id, name, created_at, updated_at) "
      "VALUES ('cfg-1', 'Trimix', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO cylinder_config_items "
      "(id, config_id, tank_role, created_at, updated_at) "
      "VALUES ('item-1', 'cfg-1', 'backGas', 1000, 1000)",
    );
  }

  test(
    'stamps hlc + a pending sync record on null-hlc enrichment rows',
    () async {
      await seedLegacyEnrichment('e1');

      await SyncRepository().backfillMissingHlc();

      expect(await hlcOf('media_enrichment', 'e1'), isNotNull);
      expect(await pendingIdsFor('mediaEnrichment'), contains('e1'));
    },
  );

  test('is a no-op the second time (self-limiting)', () async {
    await seedLegacyEnrichment('e1');

    await SyncRepository().backfillMissingHlc();
    final first = await hlcOf('media_enrichment', 'e1');
    await SyncRepository().backfillMissingHlc();
    final second = await hlcOf('media_enrichment', 'e1');

    expect(second, first, reason: 'row already had an hlc; not re-stamped');
  });

  test('stamps rows in every table registered late by #1144', () async {
    await seedUnstampedEntities();

    await SyncRepository().backfillMissingHlc();

    expect(await hlcOf('service_kinds', 'kind-1'), isNotNull);
    expect(await hlcOf('service_schedules', 'sched-1'), isNotNull);
    expect(await hlcOf('cylinder_configs', 'cfg-1'), isNotNull);
    expect(await hlcOf('cylinder_config_items', 'item-1'), isNotNull);
    expect(await hlcOf('equipment_set_geofences', 'fence-1'), isNotNull);
  });

  test('marks the backfilled rows pending so they publish', () async {
    await seedUnstampedEntities();

    await SyncRepository().backfillMissingHlc();

    expect(await pendingIdsFor('serviceKinds'), contains('kind-1'));
    expect(await pendingIdsFor('serviceSchedules'), contains('sched-1'));
    expect(await pendingIdsFor('cylinderConfigs'), contains('cfg-1'));
    expect(await pendingIdsFor('cylinderConfigItems'), contains('item-1'));
    expect(await pendingIdsFor('equipmentSetGeofences'), contains('fence-1'));
  });

  test('leaves built-in service kinds unstamped', () async {
    await seedUnstampedEntities();

    await SyncRepository().backfillMissingHlc();

    expect(
      await hlcOf('service_kinds', 'kind-builtin'),
      isNull,
      reason:
          'built-ins are reference data the export skips; stamping them '
          'would queue a sync record that never publishes anything',
    );
    expect(
      await pendingIdsFor('serviceKinds'),
      isNot(contains('kind-builtin')),
    );
  });

  test('does not re-stamp a row that already carries an hlc', () async {
    await seedUnstampedEntities();
    await db.customStatement(
      "UPDATE cylinder_configs SET hlc = 'preset-hlc' WHERE id = 'cfg-1'",
    );

    await SyncRepository().backfillMissingHlc();

    expect(await hlcOf('cylinder_configs', 'cfg-1'), 'preset-hlc');
  });
}
