import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Every field and relation a site query can name (#2365). The site list's
/// filter lowers to these (`SiteFilterQuery`), and dive paths such as
/// `site.country` walk them.

QueryField _text(String key, String sql, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: sql,
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_sites_$key',
);

/// Site to one side of a site junction table.
QueryRelation _junction(
  String key,
  QuerySubject target,
  String junction,
  String targetColumn,
) => QueryRelation(
  key: key,
  target: target,
  shape: RelationShape.junction,
  joinSql:
      '{to}.id IN (SELECT j.$targetColumn FROM $junction j '
      'WHERE j.site_id = {from}.id)',
  isMany: true,
  labelKey: 'query_sites_$key',
  tables: [junction],
);

final siteQueryEntity = QueryEntity(
  subject: QuerySubject.sites,
  table: 'dive_sites',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.country LIKE ? ESCAPE '\\'",
    "{r}.region LIKE ? ESCAPE '\\'",
    "{r}.city LIKE ? ESCAPE '\\'",
    "{r}.island LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', '{r}.name', 'name'),
    // Trimmed: the location chips offer the trimmed spelling, and a stored
    // value with a stray space must still match it.
    _text('country', 'TRIM({r}.country)', 'country'),
    _text('region', 'TRIM({r}.region)', 'region'),
    _text('city', '{r}.city', 'city'),
    _text('island', '{r}.island', 'island'),
    _text('notes', '{r}.notes', 'notes'),
    const QueryField(
      key: 'rating',
      type: FieldType.number,
      dimension: FieldDimension.count,
      sql: '{r}.rating',
      emptySql: '{r}.rating IS NULL',
      labelKey: 'query_sites_rating',
      sanity: (min: 0, max: 5),
    ),
    const QueryField(
      key: 'maxDepth',
      type: FieldType.number,
      dimension: FieldDimension.depth,
      sql: '{r}.max_depth',
      emptySql: '{r}.max_depth IS NULL',
      labelKey: 'query_sites_maxDepth',
    ),
    // Stored as free text in any case ('Advanced', 'advanced'); the app
    // reads it case-insensitively, so the query does too.
    QueryField(
      key: 'difficulty',
      type: FieldType.enumName,
      sql: 'LOWER({r}.difficulty)',
      emptySql: "({r}.difficulty IS NULL OR TRIM({r}.difficulty) = '')",
      labelKey: 'query_sites_difficulty',
      enumValues: [for (final d in SiteDifficulty.values) d.name],
    ),
    // A position needs both halves, like `DiveSite.hasCoordinates`. A bool
    // that also takes `:none`/`:any` (the sheet's "has coordinates").
    const QueryField(
      key: 'coordinates',
      type: FieldType.bool,
      ops: {QueryOp.eq, QueryOp.neq, QueryOp.isEmpty, QueryOp.isSet},
      sql: '({r}.latitude IS NOT NULL AND {r}.longitude IS NOT NULL)',
      emptySql: '({r}.latitude IS NULL OR {r}.longitude IS NULL)',
      labelKey: 'query_sites_coordinates',
    ),
  ],
  relations: [
    const QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.child,
      joinSql: '{to}.site_id = {from}.id',
      isMany: true,
      labelKey: 'query_sites_dives',
    ),
    _junction('tags', QuerySubject.tags, 'site_tags', 'tag_id'),
    _junction(
      'types',
      QuerySubject.siteTypes,
      'site_site_types',
      'site_type_id',
    ),
  ],
);
