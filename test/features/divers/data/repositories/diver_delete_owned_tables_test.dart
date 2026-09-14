import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';

/// Every table whose `diver_id` references `divers` without an ON DELETE
/// action has to be cleared by the diver delete itself. A row the delete
/// leaves behind fails the final `DELETE FROM divers` with
/// SqliteException(787), which rolls the whole transaction back: the diver
/// can then never be deleted.
///
/// The rows are tombstoned as well. A peer applies the diver's tombstone as a
/// single-row delete and its FK repair then sets every dangling `diver_id` to
/// NULL, which several readers treat as "shared with every diver": without a
/// tombstone the deleted diver's templates and kinds would surface for
/// everyone on the other devices.
void main() {
  late DiverRepository repository;
  late AppDatabase db;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id, {bool isDefault = false}) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            isDefault: Value(isDefault),
            createdAt: const Value(stale),
            updatedAt: const Value(stale),
          ),
        );
  }

  Future<bool> diverExists(String id) async =>
      (await db
              .customSelect(
                'SELECT 1 FROM divers WHERE id = ?',
                variables: [Variable<String>(id)],
              )
              .get())
          .isNotEmpty;

  Future<int> countOf(String table, String id) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM $table WHERE id = ?',
                variables: [Variable<String>(id)],
              )
              .getSingle())
          .read<int>('n');

  Future<int> tombstonesFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log '
                'WHERE entity_type = ? AND record_id = ?',
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  Future<int> pendingCountFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? '
                "AND record_id = ? AND sync_status = 'pending'",
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  Future<void> insertServiceKind(String id, {String? diverId}) async {
    await db
        .into(db.serviceKinds)
        .insert(
          ServiceKindsCompanion.insert(
            id: id,
            name: 'O2 clean',
            diverId: Value(diverId),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
  }

  Future<void> insertEquipment(String id, {String? diverId}) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'regulator',
            diverId: Value(diverId),
            createdAt: stale,
            updatedAt: stale,
          ),
        );
  }

  Future<void> insertSchedule(String id, String equipmentId, String kindId) =>
      db
          .into(db.serviceSchedules)
          .insert(
            ServiceSchedulesCompanion.insert(
              id: id,
              equipmentId: equipmentId,
              serviceKindId: kindId,
              createdAt: stale,
              updatedAt: stale,
            ),
          );

  /// One seeder per diver-owned table: each inserts a row owned by
  /// `diver-a` (plus the child rows that hang off it) and names the rows the
  /// delete must have removed, as (table, sync entity type, id).
  final seeders = <String, Future<List<(String, String, String)>> Function()>{
    'a custom service kind': () async {
      await insertServiceKind('kind-a', diverId: 'diver-a');
      return [('service_kinds', 'serviceKinds', 'kind-a')];
    },
    'a weight preset and its entries': () async {
      await db
          .into(db.weightPresets)
          .insert(
            WeightPresetsCompanion.insert(
              id: 'wp-a',
              displayName: 'Drysuit',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.weightPresetEntries)
          .insert(
            WeightPresetEntriesCompanion.insert(
              id: 'wpe-a',
              presetId: 'wp-a',
              weightType: 'belt',
              amountKg: 4,
              createdAt: stale,
            ),
          );
      return [
        ('weight_presets', 'weightPresets', 'wp-a'),
        ('weight_preset_entries', 'weightPresetEntries', 'wpe-a'),
      ];
    },
    'a cylinder config and its items': () async {
      await db
          .into(db.cylinderConfigs)
          .insert(
            CylinderConfigsCompanion.insert(
              id: 'cc-a',
              name: 'Sidemount',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.cylinderConfigItems)
          .insert(
            CylinderConfigItemsCompanion.insert(
              id: 'cci-a',
              configId: 'cc-a',
              tankRole: 'backGas',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('cylinder_configs', 'cylinderConfigs', 'cc-a'),
        ('cylinder_config_items', 'cylinderConfigItems', 'cci-a'),
      ];
    },
    'a transmitter': () async {
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: 'tx-a',
              label: 'Back gas',
              tankRole: 'backGas',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('transmitters', 'transmitters', 'tx-a')];
    },
    'a custom dive role': () async {
      await db
          .into(db.diveRoles)
          .insert(
            DiveRolesCompanion.insert(
              id: 'role-a',
              name: 'Safety diver',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('dive_roles', 'diveRoles', 'role-a')];
    },
    'a dive plan with its tanks and segments': () async {
      await db
          .into(db.divePlans)
          .insert(
            DivePlansCompanion.insert(
              id: 'plan-a',
              name: 'Wreck',
              gfLow: 30,
              gfHigh: 70,
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.divePlanTanks)
          .insert(
            DivePlanTanksCompanion.insert(
              id: 'ptank-a',
              planId: 'plan-a',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.divePlanSegments)
          .insert(
            DivePlanSegmentsCompanion.insert(
              id: 'pseg-a',
              planId: 'plan-a',
              type: 'bottom',
              startDepth: 30,
              endDepth: 30,
              durationSeconds: 1200,
              tankId: 'ptank-a',
              gasO2: 0.21,
              gasHe: 0,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('dive_plans', 'divePlans', 'plan-a'),
        ('dive_plan_tanks', 'divePlanTanks', 'ptank-a'),
        ('dive_plan_segments', 'divePlanSegments', 'pseg-a'),
      ];
    },
    'a trip checklist template and its items': () async {
      await db
          .into(db.checklistTemplates)
          .insert(
            ChecklistTemplatesCompanion.insert(
              id: 'ct-a',
              name: 'Liveaboard',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.checklistTemplateItems)
          .insert(
            ChecklistTemplateItemsCompanion.insert(
              id: 'cti-a',
              templateId: 'ct-a',
              title: 'Passport',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('checklist_templates', 'checklistTemplates', 'ct-a'),
        ('checklist_template_items', 'checklistTemplateItems', 'cti-a'),
      ];
    },
    'a pre-dive checklist template and its items': () async {
      await db
          .into(db.preDiveChecklistTemplates)
          .insert(
            PreDiveChecklistTemplatesCompanion.insert(
              id: 'pdt-a',
              name: 'CCR build',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.preDiveChecklistTemplateItems)
          .insert(
            PreDiveChecklistTemplateItemsCompanion.insert(
              id: 'pdti-a',
              templateId: 'pdt-a',
              title: 'Cells',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('pre_dive_checklist_templates', 'preDiveChecklistTemplates', 'pdt-a'),
        (
          'pre_dive_checklist_template_items',
          'preDiveChecklistTemplateItems',
          'pdti-a',
        ),
      ];
    },
    'a pre-dive session and its items': () async {
      await db
          .into(db.preDiveSessions)
          .insert(
            PreDiveSessionsCompanion.insert(
              id: 'pds-a',
              templateName: 'CCR build',
              startedAt: stale,
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.preDiveSessionItems)
          .insert(
            PreDiveSessionItemsCompanion.insert(
              id: 'pdsi-a',
              sessionId: 'pds-a',
              title: 'Cells',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('pre_dive_sessions', 'preDiveSessions', 'pds-a'),
        ('pre_dive_session_items', 'preDiveSessionItems', 'pdsi-a'),
      ];
    },
  };

  for (final MapEntry(key: label, value: seed) in seeders.entries) {
    test('a diver who owns $label can be deleted', () async {
      await insertDiver('diver-a');
      await insertDiver('diver-b', isDefault: true);
      final owned = await seed();

      await repository.deleteDiverWithReassignment('diver-a');

      expect(await diverExists('diver-a'), isFalse);
      expect(await diverExists('diver-b'), isTrue);
      for (final (table, entityType, id) in owned) {
        expect(
          await countOf(table, id),
          0,
          reason: '$table row $id belonged to the deleted diver',
        );
        expect(
          await tombstonesFor(entityType, id),
          1,
          reason: 'a peer keeps $entityType $id without a tombstone',
        );
      }
    });
  }

  group('a custom service kind still scheduled on surviving gear', () {
    test('moves to the surviving diver instead of taking the schedule '
        'with it', () async {
      // service_schedules.service_kind_id cascades, so deleting Alice's kind
      // would silently delete Bob's service clock.
      await insertDiver('diver-a');
      await insertDiver('diver-b', isDefault: true);
      await insertServiceKind('kind-a', diverId: 'diver-a');
      await insertEquipment('reg-b', diverId: 'diver-b');
      await insertSchedule('sched-b', 'reg-b', 'kind-a');

      await repository.deleteDiverWithReassignment('diver-a');

      final kind = await db
          .customSelect(
            "SELECT diver_id, updated_at FROM service_kinds WHERE id = 'kind-a'",
          )
          .getSingle();
      expect(kind.readNullable<String>('diver_id'), 'diver-b');
      expect(
        kind.read<int>('updated_at'),
        greaterThan(stale),
        reason: 'a peer cannot see a change that did not move updated_at',
      );
      expect(await pendingCountFor('serviceKinds', 'kind-a'), 1);
      expect(await tombstonesFor('serviceKinds', 'kind-a'), 0);
      expect(await countOf('service_schedules', 'sched-b'), 1);
    });

    test('becomes shared when no diver survives', () async {
      await insertDiver('diver-a');
      await insertServiceKind('kind-a', diverId: 'diver-a');
      // Ownerless gear (legacy or synced) outlives every diver.
      await insertEquipment('reg-x');
      await insertSchedule('sched-x', 'reg-x', 'kind-a');

      await repository.deleteDiverWithReassignment('diver-a');

      expect(await diverExists('diver-a'), isFalse);
      final kind = await db
          .customSelect(
            "SELECT diver_id FROM service_kinds WHERE id = 'kind-a'",
          )
          .getSingle();
      expect(kind.readNullable<String>('diver_id'), isNull);
      expect(await pendingCountFor('serviceKinds', 'kind-a'), 1);
      expect(await countOf('service_schedules', 'sched-x'), 1);
    });

    test("the diver's own gear does not keep the kind alive", () async {
      // Alice's regulator goes with her, and its schedule with it, so
      // nothing still needs the kind.
      await insertDiver('diver-a');
      await insertDiver('diver-b', isDefault: true);
      await insertServiceKind('kind-a', diverId: 'diver-a');
      await insertEquipment('reg-a', diverId: 'diver-a');
      await insertSchedule('sched-a', 'reg-a', 'kind-a');

      await repository.deleteDiverWithReassignment('diver-a');

      expect(await countOf('service_kinds', 'kind-a'), 0);
      expect(await tombstonesFor('serviceKinds', 'kind-a'), 1);
    });
  });

  test("a surviving plan linked to the diver's dives is cleared, stamped "
      'and marked', () async {
    // dive_plans.source_dive_id and linked_dive_id reference dives with no
    // ON DELETE action, and plans are not owned by a diver in practice, so
    // any plan built from or linked to one of the diver's dives failed the
    // `DELETE FROM dives` step.
    await insertDiver('diver-a');
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-a',
            diverId: const Value('diver-a'),
            diveDateTime: stale,
            createdAt: stale,
            updatedAt: stale,
          ),
        );
    await db
        .into(db.divePlans)
        .insert(
          DivePlansCompanion.insert(
            id: 'plan-x',
            name: 'Repeat',
            gfLow: 30,
            gfHigh: 70,
            sourceDiveId: const Value('dive-a'),
            linkedDiveId: const Value('dive-a'),
            createdAt: stale,
            updatedAt: stale,
          ),
        );

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await diverExists('diver-a'), isFalse);
    final plan = await db
        .customSelect(
          'SELECT source_dive_id, linked_dive_id, updated_at FROM dive_plans '
          "WHERE id = 'plan-x'",
        )
        .getSingle();
    expect(plan.readNullable<String>('source_dive_id'), isNull);
    expect(plan.readNullable<String>('linked_dive_id'), isNull);
    expect(plan.read<int>('updated_at'), greaterThan(stale));
    expect(await pendingCountFor('divePlans', 'plan-x'), 1);
  });

  test('every table owned by a diver is either cascaded by the schema or '
      'cleared by the diver delete', () async {
    // Adding a table with a plain `diver_id REFERENCES divers(id)` re-breaks
    // the delete for any diver who owns a row of it. This fails until the
    // new table gets an ON DELETE action or a step in
    // deleteDiverWithReassignment, and is listed here.
    const clearedByDelete = {
      'buddies',
      'certifications',
      'checklist_templates',
      'cylinder_configs',
      'dive_centers',
      'dive_computers',
      'dive_plans',
      'dive_roles',
      'dive_sites',
      'dive_types',
      'diver_settings',
      'diver_weight_entries',
      'dives',
      'equipment',
      'equipment_sets',
      'pre_dive_checklist_templates',
      'pre_dive_sessions',
      'service_kinds',
      'site_types',
      'tags',
      'tank_presets',
      'transmitters',
      'trips',
      'weight_presets',
    };
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final unhandled = <String>[];
    for (final row in tables) {
      final table = row.read<String>('name');
      final keys = await db
          .customSelect("PRAGMA foreign_key_list('$table')")
          .get();
      final blocksDelete = keys.any(
        (k) =>
            k.read<String>('table') == 'divers' &&
            k.read<String>('on_delete').toUpperCase() != 'CASCADE',
      );
      if (blocksDelete && !clearedByDelete.contains(table)) {
        unhandled.add(table);
      }
    }
    expect(unhandled, isEmpty);
  });
}
