import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/query/dive_aggregate_fields.dart';

/// Every field and relation a buddy query can name (#2365). The buddy list's
/// query roots here; dive paths reach it through `buddies`.
final buddyQueryEntity = QueryEntity(
  subject: QuerySubject.buddies,
  table: 'buddies',
  diverScopeColumn: 'diver_id',
  // The buddy search route's columns (name, email, phone).
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.email LIKE ? ESCAPE '\\'",
    "{r}.phone LIKE ? ESCAPE '\\'",
  ],
  fields: [
    const QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_buddies_name',
    ),
    const QueryField(
      key: 'email',
      type: FieldType.text,
      sql: '{r}.email',
      emptySql: "({r}.email IS NULL OR TRIM({r}.email) = '')",
      labelKey: 'query_buddies_email',
    ),
    const QueryField(
      key: 'phone',
      type: FieldType.text,
      sql: '{r}.phone',
      emptySql: "({r}.phone IS NULL OR TRIM({r}.phone) = '')",
      labelKey: 'query_buddies_phone',
    ),
    const QueryField(
      key: 'notes',
      type: FieldType.text,
      sql: '{r}.notes',
      emptySql: "({r}.notes IS NULL OR TRIM({r}.notes) = '')",
      labelKey: 'query_buddies_notes',
    ),
    const QueryField(
      key: 'favorite',
      type: FieldType.bool,
      sql: '{r}.is_favorite',
      emptySql: '0',
      labelKey: 'query_buddies_favorite',
    ),
    diveCountField(
      'buddies',
      'ad.id IN (SELECT j.dive_id FROM dive_buddies j '
          'WHERE j.buddy_id = {r}.id)',
      tables: const ['dive_buddies'],
    ),
    diveDateField(
      'buddies',
      'lastDived',
      'ad.id IN (SELECT j.dive_id FROM dive_buddies j '
          'WHERE j.buddy_id = {r}.id)',
      tables: const ['dive_buddies'],
    ),
  ],
  relations: const [
    QueryRelation(
      key: 'certifications',
      target: QuerySubject.certifications,
      shape: RelationShape.child,
      joinSql: '{to}.buddy_id = {from}.id',
      isMany: true,
      labelKey: 'query_buddies_certifications',
    ),
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.junction,
      // IN (subquery), as the dive side's junction hops: SQLite probes
      // dives by key.
      joinSql:
          '{to}.id IN (SELECT j.dive_id FROM dive_buddies j '
          'WHERE j.buddy_id = {from}.id)',
      isMany: true,
      labelKey: 'query_buddies_dives',
      tables: ['dive_buddies'],
    ),
  ],
);
