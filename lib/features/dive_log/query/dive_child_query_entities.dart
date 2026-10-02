import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

/// The dive's child tables, reachable only through a dive relation
/// (`tanks.o2 > 32`, `weights[amount >= 2]`, `customFields[key = k]`).

QueryField _num(
  String subject,
  String key,
  String sql, {
  FieldDimension dimension = FieldDimension.none,
  String? emptySql,
}) => QueryField(
  key: key,
  type: FieldType.number,
  dimension: dimension,
  sql: sql,
  emptySql: emptySql ?? '$sql IS NULL',
  labelKey: 'query_${subject}_$key',
);

QueryField _text(String subject, String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_${subject}_$key',
);

final tankQueryEntity = QueryEntity(
  subject: QuerySubject.tanks,
  table: 'dive_tanks',
  fields: [
    _num('tanks', 'o2', '{r}.o2_percent', dimension: FieldDimension.percent),
    _num('tanks', 'he', '{r}.he_percent', dimension: FieldDimension.percent),
    _num(
      'tanks',
      'startPressure',
      '{r}.start_pressure',
      dimension: FieldDimension.pressure,
    ),
    _num(
      'tanks',
      'endPressure',
      '{r}.end_pressure',
      dimension: FieldDimension.pressure,
    ),
    _num('tanks', 'volume', '{r}.volume', dimension: FieldDimension.volume),
    _text('tanks', 'name', 'tank_name'),
  ],
  relations: const [
    QueryRelation(
      key: 'cylinder',
      target: QuerySubject.equipment,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.equipment_id',
      isMany: false,
      labelKey: 'query_tanks_cylinder',
    ),
  ],
);

final weightQueryEntity = QueryEntity(
  subject: QuerySubject.weights,
  table: 'dive_weights',
  fields: [
    _num(
      'weights',
      'amount',
      '{r}.amount_kg',
      dimension: FieldDimension.weight,
    ),
    QueryField(
      key: 'type',
      type: FieldType.enumName,
      sql: '{r}.weight_type',
      emptySql: '{r}.weight_type IS NULL',
      labelKey: 'query_weights_type',
      enumValues: [for (final v in WeightType.values) v.name],
    ),
    _text('weights', 'notes', 'notes'),
  ],
);

final customFieldQueryEntity = QueryEntity(
  subject: QuerySubject.customFields,
  table: 'dive_custom_fields',
  fields: [
    _text('customFields', 'key', 'field_key'),
    _text('customFields', 'value', 'field_value'),
  ],
);

final sightingQueryEntity = QueryEntity(
  subject: QuerySubject.sightings,
  table: 'sightings',
  fields: [
    _num('sightings', 'count', '{r}.count', dimension: FieldDimension.count),
    _text('sightings', 'notes', 'notes'),
  ],
  relations: const [
    QueryRelation(
      key: 'species',
      target: QuerySubject.species,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.species_id',
      isMany: false,
      labelKey: 'query_sightings_species',
    ),
  ],
);

/// `file_type` is text rather than a closed enum: the row mapper accepts
/// both `instructor_signature` and `instructorSignature`, so a typed value
/// matches by contains rather than by one spelling.
final mediaQueryEntity = QueryEntity(
  subject: QuerySubject.media,
  table: 'media',
  fields: [
    _text('media', 'type', 'file_type'),
    _text('media', 'caption', 'caption'),
    const QueryField(
      key: 'favorite',
      type: FieldType.bool,
      sql: '{r}.is_favorite',
      emptySql: '0',
      labelKey: 'query_media_favorite',
    ),
  ],
);

/// A finding the diver still sees: not dismissed, and from the current
/// review engine (an older one is replaced when the dive is next reviewed).
/// The `findings` relation's target filter, written against `{to}`.
const kLiveFindingSql =
    '{to}.dismissed_at IS NULL '
    'AND {to}.engine_version >= ${SafetyReviewService.engineVersion}';

/// A dive's safety review findings, reached through the dive relation
/// `findings`, whose target filter hides every finding that is not live.
final findingQueryEntity = QueryEntity(
  subject: QuerySubject.findings,
  table: 'dive_safety_findings',
  fields: [
    QueryField(
      key: 'rule',
      type: FieldType.enumName,
      sql: '{r}.rule_id',
      emptySql: '{r}.rule_id IS NULL',
      labelKey: 'query_findings_rule',
      enumValues: [for (final r in SafetyRuleId.values) r.dbValue],
    ),
  ],
);
