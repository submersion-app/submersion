import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Minimal in PR 1 (enough for dive paths like `site.country`); PR 3 of
/// #2365 adds the rest and the site list's own query entry point.
const siteQueryEntity = QueryEntity(
  subject: QuerySubject.sites,
  table: 'dive_sites',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_sites_name',
    ),
    QueryField(
      key: 'country',
      type: FieldType.text,
      sql: '{r}.country',
      emptySql: "({r}.country IS NULL OR TRIM({r}.country) = '')",
      labelKey: 'query_sites_country',
    ),
    QueryField(
      key: 'region',
      type: FieldType.text,
      sql: '{r}.region',
      emptySql: "({r}.region IS NULL OR TRIM({r}.region) = '')",
      labelKey: 'query_sites_region',
    ),
    QueryField(
      key: 'city',
      type: FieldType.text,
      sql: '{r}.city',
      emptySql: "({r}.city IS NULL OR TRIM({r}.city) = '')",
      labelKey: 'query_sites_city',
    ),
    QueryField(
      key: 'island',
      type: FieldType.text,
      sql: '{r}.island',
      emptySql: "({r}.island IS NULL OR TRIM({r}.island) = '')",
      labelKey: 'query_sites_island',
    ),
    QueryField(
      key: 'rating',
      type: FieldType.number,
      dimension: FieldDimension.count,
      sql: '{r}.rating',
      emptySql: '{r}.rating IS NULL',
      labelKey: 'query_sites_rating',
      sanity: (min: 0, max: 5),
    ),
    QueryField(
      key: 'maxDepth',
      type: FieldType.number,
      dimension: FieldDimension.depth,
      sql: '{r}.max_depth',
      emptySql: '{r}.max_depth IS NULL',
      labelKey: 'query_sites_maxDepth',
    ),
  ],
);
