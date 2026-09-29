import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Every field and relation a site query can name (#2365). The site list's
/// filter lowers to these (`SiteFilterQuery`), and dive paths such as
/// `site.country` walk them.

/// A text column. [trimmed] is the expression both `=` and `:none` compare,
/// so a value the match treats as blank is also empty; by default only
/// `:none` trims (plain spaces).
QueryField _text(String key, String column, {String? trimmed}) => QueryField(
  key: key,
  type: FieldType.text,
  sql: trimmed ?? '{r}.$column',
  emptySql: "({r}.$column IS NULL OR ${trimmed ?? 'TRIM({r}.$column)'} = '')",
  labelKey: 'query_sites_$key',
);

/// The characters Dart's `String.trim` strips, as a SQLite `char(...)`
/// set. One-argument `TRIM` strips only U+0020, so a value imported with a
/// CR or pasted with a no-break space would miss the location chip that
/// the dropdown (deduped with Dart's trim) offers for it.
const _dartWhitespace =
    'char(9, 10, 11, 12, 13, 32, 133, 160, 5760, 8192, 8193, 8194, 8195, '
    '8196, 8197, 8198, 8199, 8200, 8201, 8202, 8232, 8233, 8239, 8287, '
    '12288, 65279)';

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
    _text('name', 'name'),
    // Trimmed: the location chips offer the trimmed spelling, and a stored
    // value with stray whitespace must still match it (and one that is only
    // whitespace is empty).
    _text('country', 'country', trimmed: 'TRIM({r}.country, $_dartWhitespace)'),
    _text('region', 'region', trimmed: 'TRIM({r}.region, $_dartWhitespace)'),
    _text('city', 'city'),
    _text('island', 'island'),
    _text('notes', 'notes'),
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
