import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

/// Minimal in PR 1 (enough for `gear.type` and the suit-thickness lowering
/// through `gear[attributes[...]]`); PR 3 of #2365 completes it.
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
