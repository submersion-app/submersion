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
  labelKey: 'query_courses_$key',
);

QueryField _date(String key, String column) => QueryField(
  key: key,
  type: FieldType.date,
  dateFrame: DateFrame.localInstant,
  sql: '{r}.$column',
  emptySql: '{r}.$column IS NULL',
  labelKey: 'query_courses_$key',
);

/// Every field and relation a course query can name (#2365). The course
/// list's query (and its status chips, as `completionDate:none`/`:any`)
/// roots here; dives reach it through `course`.
final courseQueryEntity = QueryEntity(
  subject: QuerySubject.courses,
  table: 'courses',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.location LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    QueryField(
      key: 'agency',
      type: FieldType.enumName,
      sql: '{r}.agency',
      emptySql: "({r}.agency IS NULL OR TRIM({r}.agency) = '')",
      labelKey: 'query_courses_agency',
      enumValues: [for (final a in CertificationAgency.values) a.name],
      customValueSubject: QuerySubject.certificationAgencies,
    ),
    _date('startDate', 'start_date'),
    _date('completionDate', 'completion_date'),
    _text('location', 'location'),
    _text('instructorName', 'instructor_name'),
    _text('notes', 'notes'),
  ],
  relations: const [
    QueryRelation(
      key: 'instructor',
      target: QuerySubject.buddies,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.instructor_id',
      isMany: false,
      labelKey: 'query_courses_instructor',
    ),
    // The link is stored on either side (courses.certification_id or
    // certifications.course_id); the course detail reads both.
    QueryRelation(
      key: 'certification',
      target: QuerySubject.certifications,
      shape: RelationShape.custom,
      joinSql:
          '({to}.id = {from}.certification_id OR {to}.course_id = {from}.id)',
      isMany: true,
      labelKey: 'query_courses_certification',
    ),
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.child,
      joinSql: '{to}.course_id = {from}.id',
      isMany: true,
      labelKey: 'query_courses_dives',
    ),
  ],
);
