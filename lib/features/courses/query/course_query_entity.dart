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
    "unicode_lower({r}.name) LIKE ? ESCAPE '\\'",
    "unicode_lower({r}.location) LIKE ? ESCAPE '\\'",
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
    // certifications.course_id is the truth since v288 (#2515);
    // courses.certification_id is only a representative.
    QueryRelation(
      key: 'certification',
      target: QuerySubject.certifications,
      shape: RelationShape.child,
      joinSql: '{to}.course_id = {from}.id',
      isMany: true,
      labelKey: 'query_courses_certification',
    ),
    // A course's dives come from the dive_courses junction (#2515).
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.junction,
      joinSql:
          '{to}.id IN (SELECT j.dive_id FROM dive_courses j '
          'WHERE j.course_id = {from}.id)',
      isMany: true,
      labelKey: 'query_courses_dives',
      tables: ['dive_courses'],
    ),
  ],
);
