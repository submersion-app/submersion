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

  /// A packed series row with no hlc, the shape the v182 migration leaves on
  /// a device that had nothing to publish to, and the shape any series write
  /// that did not reach its `markRecordPending` would leave behind. Every
  /// NOT NULL column without a default is named explicitly.
  Future<void> seedUnstampedSeries() async {
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
      "VALUES ('d-series', 1000, 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id) VALUES ('tank-1', 'd-series')",
    );
    await db.customStatement(
      'INSERT INTO dive_profile_series (id, dive_id, sample_count, '
      'start_timestamp, end_timestamp, max_depth, first_depth, last_depth, '
      'codec_version, samples, created_at, updated_at) '
      "VALUES ('ps-1', 'd-series', 1, 0, 0, 1.0, 1.0, 1.0, 1, X'00', "
      '1000, 1000)',
    );
    await db.customStatement(
      'INSERT INTO tank_pressure_series (id, dive_id, tank_id, sample_count, '
      'start_timestamp, end_timestamp, codec_version, samples, created_at, '
      "updated_at) VALUES ('ts-1', 'd-series', 'tank-1', 1, 0, 0, 1, X'00', "
      '1000, 1000)',
    );
  }

  test('stamps and publishes null-hlc series rows', () async {
    await seedUnstampedSeries();

    await SyncRepository().backfillMissingHlc();

    expect(await hlcOf('dive_profile_series', 'ps-1'), isNotNull);
    expect(await hlcOf('tank_pressure_series', 'ts-1'), isNotNull);
    expect(await pendingIdsFor('diveProfileSeries'), contains('ps-1'));
    expect(await pendingIdsFor('tankPressureSeries'), contains('ts-1'));
  });

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

  /// A species tag written before v195, when media_species had no clock of
  /// its own. The photo and species it points at exist; only the tag's hlc
  /// is missing, exactly as an affected build left it (issue #1638).
  Future<void> seedLegacyMediaSpeciesTag() async {
    await seedLegacyEnrichment('e-tag');
    await db.customStatement(
      "INSERT INTO species (id, common_name, category, is_built_in) "
      "VALUES ('sp-1', 'Grouper', 'fish', 0)",
    );
    await db.customStatement(
      'INSERT INTO media_species (id, media_id, species_id, created_at) '
      "VALUES ('tag-1', 'm1', 'sp-1', 1000)",
    );
  }

  test('stamps and publishes species tags written before v195', () async {
    await seedLegacyMediaSpeciesTag();

    await SyncRepository().backfillMissingHlc();

    // Without this the diver's existing tags stay invisible to the
    // incremental export until the tag is removed and re-added.
    expect(await hlcOf('media_species', 'tag-1'), isNotNull);
    expect(await pendingIdsFor('mediaSpecies'), contains('tag-1'));
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

  // The category/section->section_id migration (issue #3360) clears hlc on
  // every section it backfills and on every item it re-points at one, so
  // these four new table groups need the same self-heal the rest of this
  // file exercises.
  group('checklist sections (#3360)', () {
    test(
      'stamps and publishes null-hlc trip checklist sections and items',
      (() async {
        await db.customStatement(
          "INSERT INTO trips (id, name, start_date, end_date, created_at, "
          "updated_at) VALUES ('trip-1', 'Red Sea', 1000, 2000, 1000, 1000)",
        );
        await db.customStatement(
          'INSERT INTO trip_checklist_sections '
          '(id, trip_id, title, sort_order, created_at, updated_at) '
          "VALUES ('tcs-1', 'trip-1', 'Gear', 0, 1000, 1000)",
        );
        await db.customStatement(
          'INSERT INTO trip_checklist_items '
          '(id, trip_id, title, section_id, sort_order, created_at, '
          "updated_at) VALUES ('tci-1', 'trip-1', 'Mask', 'tcs-1', 0, 1000, "
          '1000)',
        );

        await SyncRepository().backfillMissingHlc();

        expect(await hlcOf('trip_checklist_sections', 'tcs-1'), isNotNull);
        expect(await hlcOf('trip_checklist_items', 'tci-1'), isNotNull);
        expect(await pendingIdsFor('tripChecklistSections'), contains('tcs-1'));
        expect(await pendingIdsFor('tripChecklistItems'), contains('tci-1'));
      }),
    );

    test(
      'stamps and publishes null-hlc checklist template sections and items',
      () async {
        await db.customStatement(
          'INSERT INTO checklist_templates (id, name, created_at, '
          "updated_at) VALUES ('ct-1', 'Packing', 1000, 1000)",
        );
        await db.customStatement(
          'INSERT INTO checklist_template_sections '
          '(id, template_id, title, sort_order, created_at, updated_at) '
          "VALUES ('cts-1', 'ct-1', 'Gear', 0, 1000, 1000)",
        );
        await db.customStatement(
          'INSERT INTO checklist_template_items '
          '(id, template_id, title, section_id, sort_order, created_at, '
          "updated_at) VALUES ('cti-1', 'ct-1', 'Mask', 'cts-1', 0, 1000, "
          '1000)',
        );

        await SyncRepository().backfillMissingHlc();

        expect(await hlcOf('checklist_template_sections', 'cts-1'), isNotNull);
        expect(await hlcOf('checklist_template_items', 'cti-1'), isNotNull);
        expect(
          await pendingIdsFor('checklistTemplateSections'),
          contains('cts-1'),
        );
        expect(
          await pendingIdsFor('checklistTemplateItems'),
          contains('cti-1'),
        );
      },
    );

    test('stamps and publishes null-hlc pre-dive template sections and items, '
        'but leaves a built-in template\'s alone', () async {
      await db.customStatement(
        'INSERT INTO pre_dive_checklist_templates (id, name, is_built_in, '
        "created_at, updated_at) VALUES ('pdt-1', 'Custom', 0, 1000, 1000)",
      );
      await db.customStatement(
        'INSERT INTO pre_dive_checklist_template_sections '
        '(id, template_id, title, sort_order, created_at, updated_at) '
        "VALUES ('pdts-1', 'pdt-1', 'Gear', 0, 1000, 1000)",
      );
      await db.customStatement(
        'INSERT INTO pre_dive_checklist_template_items '
        '(id, template_id, title, section_id, sort_order, created_at, '
        "updated_at) VALUES ('pdti-1', 'pdt-1', 'Mask', 'pdts-1', 0, 1000, "
        '1000)',
      );
      await db.customStatement(
        'INSERT INTO pre_dive_checklist_templates (id, name, is_built_in, '
        "created_at, updated_at) VALUES ('pdt-builtin', 'CCR', 1, 1000, "
        '1000)',
      );
      await db.customStatement(
        'INSERT INTO pre_dive_checklist_template_sections '
        '(id, template_id, title, sort_order, created_at, updated_at) '
        "VALUES ('pdts-builtin', 'pdt-builtin', 'Assembly', 0, 1000, 1000)",
      );
      await db.customStatement(
        'INSERT INTO pre_dive_checklist_template_items '
        '(id, template_id, title, section_id, sort_order, created_at, '
        "updated_at) VALUES ('pdti-builtin', 'pdt-builtin', 'Scrubber', "
        "'pdts-builtin', 0, 1000, 1000)",
      );

      await SyncRepository().backfillMissingHlc();

      expect(
        await hlcOf('pre_dive_checklist_template_sections', 'pdts-1'),
        isNotNull,
      );
      expect(
        await hlcOf('pre_dive_checklist_template_items', 'pdti-1'),
        isNotNull,
      );
      expect(
        await pendingIdsFor('preDiveChecklistTemplateSections'),
        contains('pdts-1'),
      );
      expect(
        await pendingIdsFor('preDiveChecklistTemplateItems'),
        contains('pdti-1'),
      );

      expect(
        await hlcOf('pre_dive_checklist_template_sections', 'pdts-builtin'),
        isNull,
        reason:
            'a built-in template\'s sections are reference data the '
            'export already skips; stamping them only queues a sync '
            'record that publishes nothing',
      );
      expect(
        await hlcOf('pre_dive_checklist_template_items', 'pdti-builtin'),
        isNull,
      );
      expect(
        await pendingIdsFor('preDiveChecklistTemplateSections'),
        isNot(contains('pdts-builtin')),
      );
      expect(
        await pendingIdsFor('preDiveChecklistTemplateItems'),
        isNot(contains('pdti-builtin')),
      );
    });

    test(
      'stamps and publishes null-hlc pre-dive session sections and items',
      (() async {
        await db.customStatement(
          'INSERT INTO pre_dive_sessions (id, template_name, started_at, '
          "created_at, updated_at) VALUES ('pds-1', 'Custom', 1000, 1000, "
          '1000)',
        );
        await db.customStatement(
          'INSERT INTO pre_dive_session_sections '
          '(id, session_id, title, sort_order, created_at, updated_at) '
          "VALUES ('pdss-1', 'pds-1', 'Gear', 0, 1000, 1000)",
        );
        await db.customStatement(
          'INSERT INTO pre_dive_session_items '
          '(id, session_id, title, section_id, sort_order, created_at, '
          "updated_at) VALUES ('pdsi-1', 'pds-1', 'Mask', 'pdss-1', 0, 1000, "
          '1000)',
        );

        await SyncRepository().backfillMissingHlc();

        expect(await hlcOf('pre_dive_session_sections', 'pdss-1'), isNotNull);
        expect(await hlcOf('pre_dive_session_items', 'pdsi-1'), isNotNull);
        expect(
          await pendingIdsFor('preDiveSessionSections'),
          contains('pdss-1'),
        );
        expect(await pendingIdsFor('preDiveSessionItems'), contains('pdsi-1'));
      }),
    );
  });
}
