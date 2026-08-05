import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Exercises [SyncDataSerializer.upsertRecord] and [upsertRecords] across every
/// syncable entity type -- the write side of the per-record sync merge. This
/// guards the `<Type>.fromJson(...)` (+ `.toCompanion(false)` on HLC-bearing
/// entities) switch cases: a dropped/renamed case, or a clockless case wrongly
/// switched to `.toCompanion(false)`, is exercised here.
///
/// For each entity a minimal row is seeded via raw SQL, read back through
/// `fetchRecord` (which yields exactly the `row.toJson()` map the upsert path
/// consumes), then applied through both upsert entry points. A round-trip that
/// throws -- or silently drops the row -- fails the test.
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

  /// Inserts one minimal row into [table]: the single-column primary key is set
  /// to [id]; every other NOT NULL column with no default gets a
  /// type-appropriate placeholder. Throws for composite-PK tables.
  Future<void> seedMinimalRow(String table, String id) async {
    final cols = await db
        .customSelect(
          'SELECT * FROM pragma_table_info(?)',
          variables: [Variable.withString(table)],
        )
        .get();
    final pkCols = cols.where((c) => (c.data['pk'] as int? ?? 0) > 0).toList();
    if (pkCols.length != 1) {
      throw StateError('table $table does not have a single-column PK');
    }
    final pkName = pkCols.first.read<String>('name');

    final names = <String>[];
    final placeholders = <String>[];
    final values = <Object?>[];
    for (final c in cols) {
      final name = c.read<String>('name');
      final notNull = (c.data['notnull'] as int? ?? 0) == 1;
      final hasDefault = c.data['dflt_value'] != null;
      final type = (c.data['type'] as String? ?? '').toUpperCase();
      if (name == pkName) {
        names.add('"$name"');
        placeholders.add('?');
        values.add(id);
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

  test(
    'upsertRecord + upsertRecords round-trip every single-PK entity',
    () async {
      // Placeholder rows carry unsatisfiable FK values; turn enforcement off so
      // this exercises the row mapping + upsert switch, not referential integrity.
      await db.customStatement('PRAGMA foreign_keys = OFF');

      // entityType -> live SQL table name (avoids snake_case guessing).
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
        (type: 'buddyRoles', table: db.buddyRoles.actualTableName),
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
        (type: 'settings', table: db.settings.actualTableName),
        (type: 'species', table: db.species.actualTableName),
        (type: 'sightings', table: db.sightings.actualTableName),
        (
          type: 'diveProfileEvents',
          table: db.diveProfileEvents.actualTableName,
        ),
        (type: 'gasSwitches', table: db.gasSwitches.actualTableName),
        (type: 'diveCustomFields', table: db.diveCustomFields.actualTableName),
        (type: 'diveDataSources', table: db.diveDataSources.actualTableName),
        (type: 'siteSpecies', table: db.siteSpecies.actualTableName),
        (type: 'csvPresets', table: db.csvPresets.actualTableName),
        (type: 'viewConfigs', table: db.viewConfigs.actualTableName),
        (type: 'fieldPresets', table: db.fieldPresets.actualTableName),
      ];

      var applied = 0;
      final failures = <String>[];
      for (final t in targets) {
        final id = 'seed-${t.type}';
        try {
          await seedMinimalRow(t.table, id);
        } catch (_) {
          // Composite-PK / CHECK-constrained tables resist a trivial insert.
          continue;
        }
        final row = await serializer.fetchRecord(t.type, id);
        if (row == null) continue;
        try {
          // Both entry points: single (import/adopt path) and batched (merge).
          await serializer.upsertRecord(t.type, row);
          await serializer.upsertRecords(t.type, [row]);
          expect(
            await serializer.fetchRecord(t.type, id),
            isNotNull,
            reason: '${t.type} row must survive an upsert round-trip',
          );
          applied++;
        } catch (e) {
          failures.add('${t.type}: $e');
        }
      }

      expect(
        failures,
        isEmpty,
        reason: 'every seeded entity must upsert cleanly',
      );
      expect(
        applied,
        greaterThanOrEqualTo(30),
        reason: 'most entity types should seed + upsert through both paths',
      );
    },
  );

  test('upsertRecords composite-key junctions apply without a PK id', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    // diveEquipment / equipmentSetItems are keyed by (a, b), not a surrogate id.
    await serializer.upsertRecords('diveEquipment', [
      {'diveId': 'd1', 'equipmentId': 'e1'},
    ]);
    await serializer.upsertRecords('equipmentSetItems', [
      {'setId': 's1', 'equipmentId': 'e1'},
    ]);

    expect(
      await serializer.fetchRecord('diveEquipment', 'd1|e1'),
      isNotNull,
      reason: 'composite-key junction row must round-trip',
    );
    expect(
      await serializer.fetchRecord('equipmentSetItems', 's1|e1'),
      isNotNull,
    );
  });
}
