import 'package:submersion/core/query/domain/query_node.dart' show QueryOp;
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/query/dive_aggregate_fields.dart';

/// Every field and relation a dive center query can name (#2365). The
/// center list's query roots here; dives reach it through `center`.
/// `affiliations` is the comma-separated text the edit page writes, so it
/// is matched with contains (`affiliations ~ PADI`).
final diveCenterQueryEntity = QueryEntity(
  subject: QuerySubject.centers,
  table: 'dive_centers',
  diverScopeColumn: 'diver_id',
  // The center search route's columns.
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.city LIKE ? ESCAPE '\\'",
    "{r}.country LIKE ? ESCAPE '\\'",
  ],
  fields: [
    const QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_centers_name',
    ),
    const QueryField(
      key: 'city',
      type: FieldType.text,
      sql: '{r}.city',
      emptySql: "({r}.city IS NULL OR TRIM({r}.city) = '')",
      labelKey: 'query_centers_city',
    ),
    const QueryField(
      key: 'country',
      type: FieldType.text,
      sql: '{r}.country',
      emptySql: "({r}.country IS NULL OR TRIM({r}.country) = '')",
      labelKey: 'query_centers_country',
    ),
    const QueryField(
      key: 'stateProvince',
      type: FieldType.text,
      sql: '{r}.state_province',
      emptySql: "({r}.state_province IS NULL OR TRIM({r}.state_province) = '')",
      labelKey: 'query_centers_stateProvince',
    ),
    const QueryField(
      key: 'affiliations',
      type: FieldType.text,
      sql: '{r}.affiliations',
      emptySql: "({r}.affiliations IS NULL OR TRIM({r}.affiliations) = '')",
      labelKey: 'query_centers_affiliations',
    ),
    const QueryField(
      key: 'rating',
      type: FieldType.number,
      dimension: FieldDimension.count,
      sql: '{r}.rating',
      emptySql: '{r}.rating IS NULL',
      labelKey: 'query_centers_rating',
      sanity: (min: 0, max: 5),
    ),
    const QueryField(
      key: 'notes',
      type: FieldType.text,
      sql: '{r}.notes',
      emptySql: "({r}.notes IS NULL OR TRIM({r}.notes) = '')",
      labelKey: 'query_centers_notes',
    ),
    // Like the site field: both halves, and `:none`/`:any` besides =.
    const QueryField(
      key: 'coordinates',
      type: FieldType.bool,
      ops: {QueryOp.eq, QueryOp.neq, QueryOp.isEmpty, QueryOp.isSet},
      sql: '({r}.latitude IS NOT NULL AND {r}.longitude IS NOT NULL)',
      emptySql: '({r}.latitude IS NULL OR {r}.longitude IS NULL)',
      labelKey: 'query_centers_coordinates',
    ),
    diveCountField('centers', 'ad.dive_center_id = {r}.id'),
    diveDateField('centers', 'lastDived', 'ad.dive_center_id = {r}.id'),
  ],
  relations: const [
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.child,
      joinSql: '{to}.dive_center_id = {from}.id',
      isMany: true,
      labelKey: 'query_centers_dives',
    ),
  ],
);
