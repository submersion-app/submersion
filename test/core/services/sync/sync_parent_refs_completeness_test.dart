import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Guards `SyncService.parentRefs` against the live schema. The merge applies
/// remote records inside a deferred-FK transaction; if a synced child has a
/// foreign key to a deletable parent that is NOT listed in `parentRefs`, a
/// peer's live child of a locally-deleted parent dangles its FK and the whole
/// sync fails at COMMIT (SqliteException 787). This test fails the moment such
/// an FK exists without a guard, or with the wrong nullability (skip vs.
/// clear-the-reference).
void main() {
  // SQL table name -> sync entityType, for every entity the merge applies
  // (mirrors SyncService's mergeOrder).
  const syncedTables = <String, String>{
    'divers': 'divers',
    'dives': 'dives',
    'diver_settings': 'diverSettings',
    'buddies': 'buddies',
    'buddy_roles': 'buddyRoles',
    'dive_centers': 'diveCenters',
    'trips': 'trips',
    'liveaboard_detail_records': 'liveaboardDetails',
    'trip_itinerary_days': 'itineraryDays',
    'checklist_templates': 'checklistTemplates',
    'checklist_template_items': 'checklistTemplateItems',
    'trip_checklist_items': 'tripChecklistItems',
    'equipment': 'equipment',
    'equipment_sets': 'equipmentSets',
    'equipment_set_items': 'equipmentSetItems',
    'equipment_set_geofences': 'equipmentSetGeofences',
    'dive_types': 'diveTypes',
    'tank_presets': 'tankPresets',
    'dive_computers': 'diveComputers',
    'species': 'species',
    'tags': 'tags',
    'courses': 'courses',
    'dive_sites': 'diveSites',
    'dive_tanks': 'diveTanks',
    'dive_weights': 'diveWeights',
    'dive_equipment': 'diveEquipment',
    'dive_tags': 'diveTags',
    'dive_buddies': 'diveBuddies',
    'dive_profiles': 'diveProfiles',
    'dive_profile_events': 'diveProfileEvents',
    'gas_switches': 'gasSwitches',
    'dive_custom_fields': 'diveCustomFields',
    'dive_data_sources': 'diveDataSources',
    'site_species': 'siteSpecies',
    'csv_presets': 'csvPresets',
    'view_configs': 'viewConfigs',
    'field_presets': 'fieldPresets',
    'tank_pressure_profiles': 'tankPressureProfiles',
    'tide_records': 'tideRecords',
    'sightings': 'sightings',
    'certifications': 'certifications',
    'service_records': 'serviceRecords',
    'settings': 'settings',
    'media': 'media',
    'course_requirements': 'courseRequirements',
    'course_requirement_dives': 'courseRequirementDives',
  };

  // Parent table -> entityType for parents a user can delete (and thus
  // tombstone). Divers are excluded: diver deletion goes through
  // DiverMergeRepository, which repoints FKs rather than orphaning rows.
  const deletableParents = <String, String>{
    'dives': 'dives',
    'dive_sites': 'diveSites',
    'trips': 'trips',
    'courses': 'courses',
    'equipment': 'equipment',
    'equipment_sets': 'equipmentSets',
    'buddies': 'buddies',
    'tags': 'tags',
    'dive_types': 'diveTypes',
    'tank_presets': 'tankPresets',
    'dive_centers': 'diveCenters',
    'species': 'species',
    'dive_computers': 'diveComputers',
    'checklist_templates': 'checklistTemplates',
  };

  String camel(String snake) {
    final parts = snake.split('_');
    return parts.first +
        parts
            .skip(1)
            .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
            .join();
  }

  test('parentRefs covers every synced FK to a deletable parent', () async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    final missing = <String>[];
    final wrongNullable = <String>[];

    for (final entry in syncedTables.entries) {
      final table = entry.key;
      final childEntity = entry.value;

      final cols = await db
          .customSelect(
            'SELECT * FROM pragma_table_info(?)',
            variables: [Variable.withString(table)],
          )
          .get();
      expect(
        cols,
        isNotEmpty,
        reason: 'synced table "$table" does not exist (typo in this test?)',
      );
      final notNull = {
        for (final c in cols)
          c.read<String>('name'): (c.data['notnull'] as int? ?? 0) == 1,
      };

      final fks = await db
          .customSelect(
            'SELECT * FROM pragma_foreign_key_list(?)',
            variables: [Variable.withString(table)],
          )
          .get();

      for (final fk in fks) {
        final parentTable = fk.read<String>('table');
        final parentEntity = deletableParents[parentTable];
        if (parentEntity == null) continue; // parent not user-deletable

        final field = camel(fk.read<String>('from'));
        final nullable = !(notNull[fk.read<String>('from')] ?? false);

        final refs = SyncService.parentRefs[childEntity] ?? const [];
        final match = refs
            .where((r) => r.field == field && r.parent == parentEntity)
            .toList();

        if (match.isEmpty) {
          missing.add(
            '$childEntity.$field -> $parentEntity (nullable=$nullable)',
          );
        } else if (match.first.nullable != nullable) {
          wrongNullable.add(
            '$childEntity.$field -> $parentEntity: parentRefs says '
            'nullable=${match.first.nullable}, schema says $nullable',
          );
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'SyncService.parentRefs is missing FK guards. A deleted parent would '
          'dangle these children and fail the deferred-FK COMMIT:\n'
          '${missing.join('\n')}',
    );
    expect(
      wrongNullable,
      isEmpty,
      reason:
          'Nullability mismatch (decides skip vs. clear-the-reference):\n'
          '${wrongNullable.join('\n')}',
    );
  });
}
