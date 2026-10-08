import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Reached through `dives.types`.
const diveTypeQueryEntity = QueryEntity(
  subject: QuerySubject.diveTypes,
  table: 'dive_types',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_diveTypes_name',
    ),
    QueryField(
      key: 'builtIn',
      type: FieldType.bool,
      sql: '{r}.is_built_in',
      emptySql: '0',
      labelKey: 'query_diveTypes_builtIn',
    ),
  ],
);
