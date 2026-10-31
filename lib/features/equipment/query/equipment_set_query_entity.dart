import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_equipmentSets_$key',
);

/// Every field and relation an equipment set query can name (#3882). Global
/// search roots here: the sets have no list query of their own.
final equipmentSetQueryEntity = QueryEntity(
  subject: QuerySubject.equipmentSets,
  table: 'equipment_sets',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "unicode_lower({r}.name) LIKE ? ESCAPE '\\'",
    "unicode_lower({r}.description) LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    _text('description', 'description'),
    const QueryField(
      key: 'default',
      type: FieldType.bool,
      sql: '{r}.is_default',
      emptySql: '0',
      labelKey: 'query_equipmentSets_default',
    ),
    const QueryField(
      key: 'itemCount',
      type: FieldType.number,
      dimension: FieldDimension.count,
      sql:
          '(SELECT COUNT(*) FROM equipment_set_items j '
          'WHERE j.set_id = {r}.id)',
      emptySql: '0',
      labelKey: 'query_equipmentSets_itemCount',
      tables: ['equipment_set_items'],
    ),
  ],
  relations: const [
    QueryRelation(
      key: 'items',
      aliases: ['gear'],
      target: QuerySubject.equipment,
      shape: RelationShape.junction,
      joinSql:
          '{to}.id IN (SELECT j.equipment_id FROM equipment_set_items j '
          'WHERE j.set_id = {from}.id)',
      isMany: true,
      labelKey: 'query_equipmentSets_items',
      tables: ['equipment_set_items'],
    ),
  ],
);
