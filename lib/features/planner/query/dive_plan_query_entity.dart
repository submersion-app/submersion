import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_divePlans_$key',
);

/// Every field and relation a saved plan query can name (#3882). Global
/// search roots here: the plans have no list query of their own. Depth and
/// runtime read the summary a save denormalizes, so no plan is recomputed.
final divePlanQueryEntity = QueryEntity(
  subject: QuerySubject.divePlans,
  table: 'dive_plans',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "unicode_lower({r}.name) LIKE ? ESCAPE '\\'",
    "unicode_lower({r}.notes) LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    QueryField(
      key: 'mode',
      type: FieldType.enumName,
      sql: '{r}.mode',
      emptySql: '0',
      labelKey: 'query_divePlans_mode',
      enumValues: [for (final m in PlanMode.values) m.name],
    ),
    const QueryField(
      key: 'date',
      aliases: ['planned'],
      type: FieldType.date,
      dateFrame: DateFrame.localInstant,
      // Stored in seconds; the date grammar binds milliseconds.
      sql: '({r}.start_date_time * 1000)',
      emptySql: '{r}.start_date_time IS NULL',
      labelKey: 'query_divePlans_date',
    ),
    const QueryField(
      key: 'depth',
      aliases: ['maxDepth'],
      type: FieldType.number,
      dimension: FieldDimension.depth,
      sql: '{r}.summary_max_depth',
      emptySql: '{r}.summary_max_depth IS NULL',
      labelKey: 'query_divePlans_depth',
      sanity: (min: 0, max: 400),
    ),
    const QueryField(
      key: 'runtime',
      type: FieldType.number,
      dimension: FieldDimension.minutes,
      sql: '({r}.summary_runtime_seconds / 60)',
      emptySql: '{r}.summary_runtime_seconds IS NULL',
      labelKey: 'query_divePlans_runtime',
    ),
    _text('notes', 'notes'),
  ],
  relations: const [
    QueryRelation(
      key: 'site',
      target: QuerySubject.sites,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.site_id',
      isMany: false,
      labelKey: 'query_divePlans_site',
    ),
  ],
);
