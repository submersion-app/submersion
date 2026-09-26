import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

/// Minimal in PR 1; PR 4 of #2365 adds the buddy list's query entry point.
const buddyQueryEntity = QueryEntity(
  subject: QuerySubject.buddies,
  table: 'buddies',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_buddies_name',
    ),
    QueryField(
      key: 'email',
      type: FieldType.text,
      sql: '{r}.email',
      emptySql: "({r}.email IS NULL OR TRIM({r}.email) = '')",
      labelKey: 'query_buddies_email',
    ),
    QueryField(
      key: 'phone',
      type: FieldType.text,
      sql: '{r}.phone',
      emptySql: "({r}.phone IS NULL OR TRIM({r}.phone) = '')",
      labelKey: 'query_buddies_phone',
    ),
    QueryField(
      key: 'notes',
      type: FieldType.text,
      sql: '{r}.notes',
      emptySql: "({r}.notes IS NULL OR TRIM({r}.notes) = '')",
      labelKey: 'query_buddies_notes',
    ),
    QueryField(
      key: 'favorite',
      type: FieldType.bool,
      sql: '{r}.is_favorite',
      emptySql: '0',
      labelKey: 'query_buddies_favorite',
    ),
  ],
  relations: [
    QueryRelation(
      key: 'certifications',
      target: QuerySubject.certifications,
      shape: RelationShape.child,
      joinSql: '{to}.buddy_id = {from}.id',
      isMany: true,
      labelKey: 'query_buddies_certifications',
    ),
  ],
);
