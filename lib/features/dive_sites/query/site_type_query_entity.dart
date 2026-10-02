import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// A site classification type (issue #1765), the target of the site
/// `types` relation. Built-ins carry a null diver id.
const siteTypeQueryEntity = QueryEntity(
  subject: QuerySubject.siteTypes,
  table: 'site_types',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_siteTypes_name',
    ),
  ],
);
