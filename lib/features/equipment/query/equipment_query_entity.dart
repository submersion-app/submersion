import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/query/dive_aggregate_fields.dart';
import 'package:submersion/features/equipment/data/equipment_location_sql.dart';

/// Minimal in PR 1 (enough for `gear.type` and the suit-thickness lowering
/// through `gear[attributes[...]]`); PR 3 of #2365 completes it.
/// The local cache table (v242) the `serviceDue` field reads; a compiled
/// query names it in `tablesTouched` exactly when it reads the verdicts.
const serviceStatusTable = 'equipment_service_status';

/// A counted dive this item was on: linked through dive_equipment, or a
/// cylinder matched through dive_tanks (the dive gear union).
const _gearDiveLink =
    'ad.id IN (SELECT de.dive_id FROM dive_equipment de '
    'WHERE de.equipment_id = {r}.id '
    'UNION SELECT dt.dive_id FROM dive_tanks dt '
    'WHERE dt.equipment_id = {r}.id)';

final equipmentQueryEntity = QueryEntity(
  subject: QuerySubject.equipment,
  table: 'equipment',
  diverScopeColumn: 'diver_id',
  fields: [
    const QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_equipment_name',
    ),
    const QueryField(
      key: 'brand',
      type: FieldType.text,
      sql: '{r}.brand',
      emptySql: "({r}.brand IS NULL OR TRIM({r}.brand) = '')",
      labelKey: 'query_equipment_brand',
    ),
    const QueryField(
      key: 'model',
      type: FieldType.text,
      sql: '{r}.model',
      emptySql: "({r}.model IS NULL OR TRIM({r}.model) = '')",
      labelKey: 'query_equipment_model',
    ),
    const QueryField(
      key: 'serialNumber',
      type: FieldType.text,
      sql: '{r}.serial_number',
      emptySql: "({r}.serial_number IS NULL OR TRIM({r}.serial_number) = '')",
      labelKey: 'query_equipment_serialNumber',
    ),
    QueryField(
      key: 'type',
      type: FieldType.enumName,
      sql: '{r}.type',
      emptySql: '{r}.type IS NULL',
      labelKey: 'query_equipment_type',
      enumValues: [for (final v in EquipmentType.values) v.name],
    ),
    QueryField(
      key: 'status',
      type: FieldType.enumName,
      sql: '{r}.status',
      emptySql: '{r}.status IS NULL',
      labelKey: 'query_equipment_status',
      enumValues: [for (final v in EquipmentStatus.values) v.name],
    ),
    const QueryField(
      key: 'active',
      type: FieldType.bool,
      sql: '{r}.is_active',
      emptySql: '0',
      labelKey: 'query_equipment_active',
    ),
    // The service engine's verdict for the active diver (#2365 PR 3), read
    // from the local cache the engine writes; an item it never evaluated
    // (retired, sold, not visible) reads as ok.
    const QueryField(
      key: 'serviceDue',
      type: FieldType.enumName,
      sql:
          'COALESCE((SELECT s.severity FROM $serviceStatusTable s '
          "WHERE s.equipment_id = {r}.id), 'ok')",
      emptySql: '0',
      labelKey: 'query_equipment_serviceDue',
      enumValues: ['ok', 'dueSoon', 'overdue'],
      tables: [serviceStatusTable],
    ),
    diveCountField(
      'equipment',
      _gearDiveLink,
      tables: const ['dive_equipment', 'dive_tanks'],
    ),
    diveDateField(
      'equipment',
      'lastDived',
      _gearDiveLink,
      tables: const ['dive_equipment', 'dive_tanks'],
    ),
    // The worst service clock's next due instant, from the same cache
    // `serviceDue` reads: "due within 30 days" is a bound on this date.
    const QueryField(
      key: 'nextServiceDue',
      type: FieldType.date,
      dateFrame: DateFrame.localInstant,
      sql:
          '(SELECT s.due_date FROM $serviceStatusTable s '
          'WHERE s.equipment_id = {r}.id)',
      emptySql:
          'NOT EXISTS (SELECT 1 FROM $serviceStatusTable s '
          'WHERE s.equipment_id = {r}.id AND s.due_date IS NOT NULL)',
      labelKey: 'query_equipment_nextServiceDue',
      tables: [serviceStatusTable],
    ),
    // Where the item is now (v268): the name of its newest move's place, so
    // a typed `location = Garage` and the filter panel both match what the
    // diver sees. Reads the move log and the places, so a move or a rename
    // refreshes any list this field narrows.
    QueryField(
      key: 'location',
      type: FieldType.text,
      sql:
          '(SELECT l.name FROM equipment_locations l '
          'WHERE l.id = ${currentLocationIdSql('{r}.id')})',
      emptySql: '${currentLocationIdSql('{r}.id')} IS NULL',
      labelKey: 'query_equipment_location',
      tables: const ['equipment_location_moves', 'equipment_locations'],
    ),
  ],
  relations: const [
    QueryRelation(
      key: 'attributes',
      target: QuerySubject.equipmentAttributes,
      shape: RelationShape.child,
      joinSql: '{to}.equipment_id = {from}.id',
      isMany: true,
      labelKey: 'query_equipment_attributes',
    ),
    QueryRelation(
      key: 'tags',
      target: QuerySubject.tags,
      shape: RelationShape.junction,
      joinSql:
          '{to}.id IN (SELECT j.tag_id FROM equipment_tags j '
          'WHERE j.equipment_id = {from}.id)',
      isMany: true,
      labelKey: 'query_equipment_tags',
      tables: ['equipment_tags'],
    ),
    // The dive gear union (`kDiveGearJoinSql`) read from the item's side:
    // linked through dive_equipment, or a cylinder matched through
    // dive_tanks.
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.custom,
      joinSql:
          '{to}.id IN (SELECT de.dive_id FROM dive_equipment de '
          'WHERE de.equipment_id = {from}.id '
          'UNION SELECT dt.dive_id FROM dive_tanks dt '
          'WHERE dt.equipment_id = {from}.id)',
      isMany: true,
      labelKey: 'query_equipment_dives',
      tables: ['dive_equipment', 'dive_tanks'],
    ),
  ],
);

/// The curated attribute rows an item carries (`thickness_mm`, ...). The
/// suit-thickness dive axis lowers to `gear[type in [...] AND
/// attributes[key = thickness_mm AND custom = false AND valueNum >= n]]`.
const equipmentAttributeQueryEntity = QueryEntity(
  subject: QuerySubject.equipmentAttributes,
  table: 'equipment_attributes',
  fields: [
    QueryField(
      key: 'key',
      type: FieldType.text,
      sql: '{r}.attr_key',
      emptySql: "({r}.attr_key IS NULL OR TRIM({r}.attr_key) = '')",
      labelKey: 'query_equipmentAttributes_key',
    ),
    QueryField(
      key: 'custom',
      type: FieldType.bool,
      sql: '{r}.is_custom',
      emptySql: '0',
      labelKey: 'query_equipmentAttributes_custom',
    ),
    QueryField(
      key: 'valueText',
      type: FieldType.text,
      sql: '{r}.value_text',
      emptySql: "({r}.value_text IS NULL OR TRIM({r}.value_text) = '')",
      labelKey: 'query_equipmentAttributes_valueText',
    ),
    QueryField(
      key: 'valueNum',
      type: FieldType.number,
      sql: '{r}.value_num',
      emptySql: '{r}.value_num IS NULL',
      labelKey: 'query_equipmentAttributes_valueNum',
    ),
  ],
);
