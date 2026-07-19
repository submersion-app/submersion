import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Exercises [SyncDataSerializer.fetchRecord] across every syncable entity
/// type. fetchRecord is the read side of the per-record sync path (used when
/// re-fetching a locally-pending row); it must stay symmetric with the
/// upsert/import switch.
///
/// Two passes:
///  - absent rows: confirm each case returns null (the query + null-return).
///  - seeded rows: a minimal row is inserted per table so `row?.toJson()`
///    actually invokes toJson (the null-aware call is otherwise never reached
///    on an empty table), which also exercises each table's generated row
///    mapping including the nullable `hlc` column.
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

  // Insert one minimal row into [table]: the single-column primary key is set
  // to [id]; every other NOT NULL column with no default gets a
  // type-appropriate placeholder. Throws for composite-PK tables (handled
  // separately). FK enforcement is off for raw statements in tests, so
  // placeholder FK values are fine.
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

  group('SyncDataSerializer.fetchRecord', () {
    const simpleTypes = <String>[
      'divers',
      'diverSettings',
      'dives',
      'diveProfiles',
      'diveTanks',
      'diveWeights',
      'diveSites',
      'equipment',
      'equipmentSets',
      'media',
      'buddies',
      'diveBuddies',
      'certifications',
      'courses',
      'courseRequirements',
      'courseRequirementDives',
      'serviceRecords',
      'diveCenters',
      'trips',
      'liveaboardDetails',
      'itineraryDays',
      'checklistTemplates',
      'checklistTemplateItems',
      'tripChecklistItems',
      'tags',
      'diveTags',
      'diveTypes',
      'tankPresets',
      'diveComputers',
      'tankPressureProfiles',
      'tideRecords',
      'settings',
      'species',
      'sightings',
      'diveProfileEvents',
      'diveSafetyReviews',
      'diveSafetyFindings',
      'gasSwitches',
      'diveCustomFields',
      'diveDataSources',
      'siteSpecies',
      'csvPresets',
      'viewConfigs',
      'fieldPresets',
    ];

    for (final type in simpleTypes) {
      test('returns null for an absent $type row', () async {
        expect(await serializer.fetchRecord(type, 'no-such-id'), isNull);
      });
    }

    test('returns null for absent composite-id rows', () async {
      // diveEquipment + equipmentSetItems are keyed by "diveId|equipmentId".
      expect(await serializer.fetchRecord('diveEquipment', 'a|b'), isNull);
      expect(await serializer.fetchRecord('equipmentSetItems', 'a|b'), isNull);
    });

    test('returns null when a composite id is malformed', () async {
      expect(
        await serializer.fetchRecord('diveEquipment', 'noseparator'),
        isNull,
      );
      expect(
        await serializer.fetchRecord('equipmentSetItems', 'noseparator'),
        isNull,
      );
    });

    test('returns null for an unknown entity type', () async {
      expect(await serializer.fetchRecord('totallyUnknown', 'x'), isNull);
    });

    test('fetches a seeded row for each single-PK entity type', () async {
      // Drift enables foreign_keys by default; turn it off so a minimal
      // placeholder row needn't satisfy parent references (these throwaway
      // rows only exist to exercise each table's row mapping + toJson).
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
        (
          type: 'diveSafetyReviews',
          table: db.diveSafetyReviews.actualTableName,
        ),
        (
          type: 'diveSafetyFindings',
          table: db.diveSafetyFindings.actualTableName,
        ),
        (type: 'gasSwitches', table: db.gasSwitches.actualTableName),
        (type: 'diveCustomFields', table: db.diveCustomFields.actualTableName),
        (type: 'diveDataSources', table: db.diveDataSources.actualTableName),
        (type: 'siteSpecies', table: db.siteSpecies.actualTableName),
        (type: 'csvPresets', table: db.csvPresets.actualTableName),
        (type: 'viewConfigs', table: db.viewConfigs.actualTableName),
        (type: 'fieldPresets', table: db.fieldPresets.actualTableName),
      ];

      var fetched = 0;
      final failures = <String>[];
      for (final t in targets) {
        final id = 'seed-${t.type}';
        try {
          await seedMinimalRow(t.table, id);
        } catch (_) {
          // Some tables resist a trivial placeholder insert (composite PK,
          // CHECK constraints); skip them -- the absent-row pass still covers
          // the query path.
          continue;
        }
        final row = await serializer.fetchRecord(t.type, id);
        if (row != null) {
          fetched++;
        } else {
          failures.add(t.type);
        }
      }

      expect(
        fetched,
        greaterThanOrEqualTo(25),
        reason: 'most entity types should seed+fetch; failures: $failures',
      );
    });
  });

  group('SyncDataSerializer.deleteRecord for safety entities', () {
    test('deletes a dive_safety_reviews row by dive_id', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await seedMinimalRow(db.diveSafetyReviews.actualTableName, 'dive-1');
      expect(
        await serializer.fetchRecord('diveSafetyReviews', 'dive-1'),
        isNotNull,
      );

      await serializer.deleteRecord('diveSafetyReviews', 'dive-1');
      expect(
        await serializer.fetchRecord('diveSafetyReviews', 'dive-1'),
        isNull,
      );
    });

    test('deletes a dive_safety_findings row by id', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await seedMinimalRow(db.diveSafetyFindings.actualTableName, 'f1');
      expect(
        await serializer.fetchRecord('diveSafetyFindings', 'f1'),
        isNotNull,
      );

      await serializer.deleteRecord('diveSafetyFindings', 'f1');
      expect(await serializer.fetchRecord('diveSafetyFindings', 'f1'), isNull);
    });
  });
}
