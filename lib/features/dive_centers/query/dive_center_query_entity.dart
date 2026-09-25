import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Minimal in PR 1; PR 4 of #2365 adds the list entry point.
const diveCenterQueryEntity = QueryEntity(
  subject: QuerySubject.centers,
  table: 'dive_centers',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_centers_name',
    ),
    QueryField(
      key: 'city',
      type: FieldType.text,
      sql: '{r}.city',
      emptySql: "({r}.city IS NULL OR TRIM({r}.city) = '')",
      labelKey: 'query_centers_city',
    ),
    QueryField(
      key: 'country',
      type: FieldType.text,
      sql: '{r}.country',
      emptySql: "({r}.country IS NULL OR TRIM({r}.country) = '')",
      labelKey: 'query_centers_country',
    ),
  ],
);
