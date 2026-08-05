import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Coverage for the batched [SyncDataSerializer.upsertRecords] across every
/// syncable entity type. This is the throughput path the streaming
/// Replace-adopt uses (one Drift `batch()` write per table instead of a per-row
/// loop, #358); each `case` arm must stay symmetric with the per-record
/// `upsertRecord` switch.
///
/// Strategy: seed a minimal placeholder row per table (FK enforcement off),
/// read it back through the serializer (so blob columns use the same
/// `_syncBlobSerializer` in both directions), feed that JSON through
/// `upsertRecords` (a conflict-update on the row it came from), and assert the
/// row still reads back. Drift's generated `toJson`/`fromJson` are inverses for
/// a given table, so this exercises every arm with real, valid data.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // Insert one placeholder row into [table]: every NOT NULL column without a
  // default gets a type-appropriate placeholder (the boolean CHECK columns all
  // accept 0). Pass [pkId] for a single-PK table to set a known id; the
  // composite-PK junctions take no id and are read back via Drift. FK
  // enforcement is off in tests, so placeholder FK values are fine.
  Future<void> insertPlaceholderRow(String table, {String? pkId}) async {
    final cols = await db
        .customSelect(
          'SELECT * FROM pragma_table_info(?)',
          variables: [Variable.withString(table)],
        )
        .get();
    final pkCols = cols.where((c) => (c.data['pk'] as int? ?? 0) > 0).toList();
    final singlePkName = (pkId != null && pkCols.length == 1)
        ? pkCols.first.read<String>('name')
        : null;

    final names = <String>[];
    final placeholders = <String>[];
    final values = <Object?>[];
    for (final c in cols) {
      final name = c.read<String>('name');
      final notNull = (c.data['notnull'] as int? ?? 0) == 1;
      final hasDefault = c.data['dflt_value'] != null;
      final type = (c.data['type'] as String? ?? '').toUpperCase();
      if (name == singlePkName) {
        names.add('"$name"');
        placeholders.add('?');
        values.add(pkId);
      } else if (notNull && !hasDefault) {
        names.add('"$name"');
        placeholders.add('?');
        if (type.contains('INT')) {
          values.add(0);
        } else if (type.contains('REAL') ||
            type.contains('FLOA') ||
            type.contains('DOUB')) {
          values.add(0.0);
        } else if (type.contains('BLOB')) {
          values.add(Uint8List(0));
        } else {
          values.add('x');
        }
      }
    }
    await db.customStatement(
      'INSERT INTO "$table" (${names.join(",")}) VALUES (${placeholders.join(",")})',
      values,
    );
  }

  group('batched upsertRecords', () {
    test(
      'every single-PK entity round-trips fetchRecord -> upsertRecords -> fetchRecords',
      () async {
        // Minimal placeholder rows need not satisfy parent references.
        await db.customStatement('PRAGMA foreign_keys = OFF');

        // entityType -> live SQL table name (mirrors the upsert switch;
        // actualTableName avoids snake_case guessing).
        final targets = <({String type, String table})>[
          (type: 'divers', table: db.divers.actualTableName),
          (type: 'diverSettings', table: db.diverSettings.actualTableName),
          (type: 'dives', table: db.dives.actualTableName),
          (type: 'diveProfiles', table: db.diveProfiles.actualTableName),
          (type: 'diveTanks', table: db.diveTanks.actualTableName),
          (type: 'diveWeights', table: db.diveWeights.actualTableName),
          (type: 'diveSites', table: db.diveSites.actualTableName),
          (type: 'equipment', table: db.equipment.actualTableName),
          (type: 'equipmentSets', table: db.equipmentSets.actualTableName),
          (type: 'media', table: db.media.actualTableName),
          (type: 'buddies', table: db.buddies.actualTableName),
          (type: 'diveBuddies', table: db.diveBuddies.actualTableName),
          (type: 'certifications', table: db.certifications.actualTableName),
          (type: 'courses', table: db.courses.actualTableName),
          (
            type: 'courseRequirements',
            table: db.courseRequirements.actualTableName,
          ),
          (
            type: 'courseRequirementDives',
            table: db.courseRequirementDives.actualTableName,
          ),
          (type: 'serviceRecords', table: db.serviceRecords.actualTableName),
          (type: 'diveCenters', table: db.diveCenters.actualTableName),
          (type: 'trips', table: db.trips.actualTableName),
          (
            type: 'liveaboardDetails',
            table: db.liveaboardDetailRecords.actualTableName,
          ),
          (type: 'itineraryDays', table: db.tripItineraryDays.actualTableName),
          (
            type: 'checklistTemplates',
            table: db.checklistTemplates.actualTableName,
          ),
          (
            type: 'checklistTemplateItems',
            table: db.checklistTemplateItems.actualTableName,
          ),
          (
            type: 'tripChecklistItems',
            table: db.tripChecklistItems.actualTableName,
          ),
          (type: 'tags', table: db.tags.actualTableName),
          (type: 'diveTags', table: db.diveTags.actualTableName),
          (type: 'diveDiveTypes', table: db.diveDiveTypes.actualTableName),
          (type: 'diveTypes', table: db.diveTypes.actualTableName),
          (type: 'tankPresets', table: db.tankPresets.actualTableName),
          (type: 'diveComputers', table: db.diveComputers.actualTableName),
          (
            type: 'tankPressureProfiles',
            table: db.tankPressureProfiles.actualTableName,
          ),
          (type: 'tideRecords', table: db.tideRecords.actualTableName),
          (type: 'species', table: db.species.actualTableName),
          (type: 'sightings', table: db.sightings.actualTableName),
          (
            type: 'diveProfileEvents',
            table: db.diveProfileEvents.actualTableName,
          ),
          (type: 'gasSwitches', table: db.gasSwitches.actualTableName),
          (
            type: 'diveCustomFields',
            table: db.diveCustomFields.actualTableName,
          ),
          (type: 'diveDataSources', table: db.diveDataSources.actualTableName),
          (type: 'siteSpecies', table: db.siteSpecies.actualTableName),
          (type: 'csvPresets', table: db.csvPresets.actualTableName),
          (type: 'viewConfigs', table: db.viewConfigs.actualTableName),
          (type: 'fieldPresets', table: db.fieldPresets.actualTableName),
        ];

        for (final t in targets) {
          final id = 'seed-${t.type}';
          await insertPlaceholderRow(t.table, pkId: id);

          final json = await serializer.fetchRecord(t.type, id);
          expect(json, isNotNull, reason: 'fetchRecord(${t.type}) after seed');

          // Batched write: feed the row's own JSON back (a conflict-update).
          await serializer.upsertRecords(t.type, [json!]);

          // Batched read: every entity arm, matching the per-id read and
          // dropping absent ids.
          final got = await serializer.fetchRecords(t.type, [id, 'absent-id']);
          expect(got.keys.toSet(), {
            id,
          }, reason: 'fetchRecords(${t.type}) keys');
          expect(
            got[id],
            await serializer.fetchRecord(t.type, id),
            reason: 'batched read == per-id read for ${t.type}',
          );
        }
      },
    );

    test('composite-key junctions upsert through their batch arms', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      // diveEquipment is keyed by "diveId|equipmentId".
      await insertPlaceholderRow(db.diveEquipment.actualTableName);
      final de = (await db.select(db.diveEquipment).get()).single;
      await serializer.upsertRecords('diveEquipment', [de.toJson()]);
      expect(await serializer.recordIdsFor('diveEquipment'), isNotEmpty);

      // equipmentSetItems is keyed by "setId|equipmentId".
      await insertPlaceholderRow(db.equipmentSetItems.actualTableName);
      final esi = (await db.select(db.equipmentSetItems).get()).single;
      await serializer.upsertRecords('equipmentSetItems', [esi.toJson()]);
      expect(await serializer.recordIdsFor('equipmentSetItems'), isNotEmpty);
    });

    test('settings: device-local keys are never written; an all-local batch is '
        'a no-op', () async {
      // active_diver_id is device-local -> filtered out; theme is normal.
      await serializer.upsertRecords('settings', [
        {'key': 'active_diver_id', 'value': 'diver-7', 'updatedAt': 1},
        {'key': 'theme', 'value': 'dark', 'updatedAt': 1},
      ]);
      expect(
        await serializer.fetchRecord('settings', 'active_diver_id'),
        isNull,
      );
      expect(
        (await serializer.fetchRecord('settings', 'theme'))?['value'],
        'dark',
      );

      // A batch of only device-local keys filters to empty -> early return.
      await serializer.upsertRecords('settings', [
        {'key': 'active_diver_id', 'value': 'diver-9', 'updatedAt': 2},
      ]);
      expect(
        await serializer.fetchRecord('settings', 'active_diver_id'),
        isNull,
      );
    });

    test('diveProfileEvents defaults a missing source to "imported"', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await insertPlaceholderRow(
        db.diveProfileEvents.actualTableName,
        pkId: 'evt-1',
      );
      final seeded = await serializer.fetchRecord('diveProfileEvents', 'evt-1');
      expect(seeded, isNotNull);

      // source present -> kept as-is (the false branch).
      await serializer.upsertRecords('diveProfileEvents', [
        {...seeded!, 'source': 'manual'},
      ]);
      expect(
        (await serializer.fetchRecord('diveProfileEvents', 'evt-1'))?['source'],
        'manual',
      );

      // source missing -> defaulted to 'imported' (the true branch).
      await serializer.upsertRecords('diveProfileEvents', [
        {...seeded}..remove('source'),
      ]);
      expect(
        (await serializer.fetchRecord('diveProfileEvents', 'evt-1'))?['source'],
        'imported',
      );
    });

    test('upsertRecords is a no-op for an empty list', () async {
      // Early return before the switch.
      await serializer.upsertRecords('divers', const []);
      expect(await serializer.recordIdsFor('divers'), isEmpty);
    });

    test(
      'upsertRecords throws ArgumentError for an unknown entity type',
      () async {
        await expectLater(
          serializer.upsertRecords('totallyUnknown', [
            {'id': 'x'},
          ]),
          throwsArgumentError,
        );
      },
    );
  });
}
