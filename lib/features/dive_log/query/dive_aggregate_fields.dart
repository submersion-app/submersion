import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// A subject's counted dives, as a FROM/WHERE fragment over the alias `ad`
/// (no other registry fragment uses it): the dives [linkSql] ties to the
/// row `{r}`, inside the stats scope and the active diver's alone when the
/// compile names one, so a count is the one the list tiles show. [linkSql]
/// is written against `{r}` and `ad`.
String _counted(String linkSql) =>
    'FROM dives ad WHERE $linkSql${DiveStatsScope.and(alias: 'ad')}'
    '{diver:ad}';

/// How many counted dives the row has. Never unrecorded: `:none` is none.
QueryField diveCountField(
  String subjectKey,
  String linkSql, {
  List<String> tables = const [],
}) => QueryField(
  key: 'diveCount',
  type: FieldType.number,
  dimension: FieldDimension.count,
  sql: '(SELECT COUNT(*) ${_counted(linkSql)})',
  emptySql: 'NOT EXISTS (SELECT 1 ${_counted(linkSql)})',
  labelKey: 'query_${subjectKey}_diveCount',
  tables: ['dives', ...tables],
);

/// The newest (or, with [first], the oldest) counted dive's date. Rows
/// with no counted dive have none, so no bound matches them.
QueryField diveDateField(
  String subjectKey,
  String key,
  String linkSql, {
  bool first = false,
  List<String> tables = const [],
}) => QueryField(
  key: key,
  type: FieldType.date,
  sql:
      '(SELECT ${first ? 'MIN' : 'MAX'}(ad.dive_date_time) '
      '${_counted(linkSql)})',
  emptySql: 'NOT EXISTS (SELECT 1 ${_counted(linkSql)})',
  labelKey: 'query_${subjectKey}_$key',
  tables: ['dives', ...tables],
);
