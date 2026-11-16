import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Reached through `dives.myRole` (#4409). Hops are not scoped to the
/// active diver (built-in roles have no owner); the relation's join keeps
/// built-ins and the dive owner's own custom roles (`diveRoleVisibleSql`).
const diveRoleQueryEntity = QueryEntity(
  subject: QuerySubject.diveRoles,
  table: 'dive_roles',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_diveRoles_name',
    ),
    QueryField(
      key: 'builtIn',
      type: FieldType.bool,
      sql: '{r}.is_built_in',
      emptySql: '0',
      labelKey: 'query_diveRoles_builtIn',
    ),
  ],
);
