import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_certifications_$key',
);

QueryField _date(String key, String column) => QueryField(
  key: key,
  type: FieldType.date,
  dateFrame: DateFrame.localInstant,
  sql: '{r}.$column',
  emptySql: '{r}.$column IS NULL',
  labelKey: 'query_certifications_$key',
);

/// A buddy's certification row, as stored in `buddy_id`/`instructor_id`.
QueryRelation _buddy(String key, String column) => QueryRelation(
  key: key,
  target: QuerySubject.buddies,
  shape: RelationShape.fk,
  joinSql: '{to}.id = {from}.$column',
  isMany: false,
  labelKey: 'query_certifications_$key',
);

/// Every field and relation a certification query can name (#2365). The
/// certification list's query roots here; `buddies.certifications` reaches
/// it from dives. `agency` and `level` store enum names, so they compare as
/// enums; a stored name outside the enum is set but equals no value.
final certificationQueryEntity = QueryEntity(
  subject: QuerySubject.certifications,
  table: 'certifications',
  diverScopeColumn: 'diver_id',
  // The certification search route's columns.
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.agency LIKE ? ESCAPE '\\'",
    "{r}.card_number LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    QueryField(
      key: 'agency',
      type: FieldType.enumName,
      sql: '{r}.agency',
      emptySql: "({r}.agency IS NULL OR TRIM({r}.agency) = '')",
      labelKey: 'query_certifications_agency',
      enumValues: [for (final a in CertificationAgency.values) a.name],
    ),
    QueryField(
      key: 'level',
      type: FieldType.enumName,
      sql: '{r}.level',
      emptySql: "({r}.level IS NULL OR TRIM({r}.level) = '')",
      labelKey: 'query_certifications_level',
      enumValues: [for (final l in CertificationLevel.values) l.name],
    ),
    _text('cardNumber', 'card_number'),
    _text('instructorName', 'instructor_name'),
    _text('instructorNumber', 'instructor_number'),
    _text('notes', 'notes'),
    _date('issueDate', 'issue_date'),
    _date('expiryDate', 'expiry_date'),
  ],
  relations: [
    _buddy('buddy', 'buddy_id'),
    _buddy('instructor', 'instructor_id'),
    // The link is stored on either side (certifications.course_id or
    // courses.certification_id), as the course side's `certification`
    // relation and the certification detail read it.
    const QueryRelation(
      key: 'course',
      target: QuerySubject.courses,
      shape: RelationShape.custom,
      joinSql:
          '({to}.id = {from}.course_id OR {to}.certification_id = {from}.id)',
      isMany: true,
      labelKey: 'query_certifications_course',
    ),
  ],
);
