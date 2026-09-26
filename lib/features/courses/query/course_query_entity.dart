import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Minimal in PR 1; PR 4 of #2365 adds the list entry point.
const courseQueryEntity = QueryEntity(
  subject: QuerySubject.courses,
  table: 'courses',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_courses_name',
    ),
    QueryField(
      key: 'agency',
      type: FieldType.text,
      sql: '{r}.agency',
      emptySql: "({r}.agency IS NULL OR TRIM({r}.agency) = '')",
      labelKey: 'query_courses_agency',
    ),
    QueryField(
      key: 'startDate',
      type: FieldType.date,
      dateFrame: DateFrame.localInstant,
      sql: '{r}.start_date',
      emptySql: '{r}.start_date IS NULL',
      labelKey: 'query_courses_startDate',
    ),
    QueryField(
      key: 'completionDate',
      type: FieldType.date,
      dateFrame: DateFrame.localInstant,
      sql: '{r}.completion_date',
      emptySql: '{r}.completion_date IS NULL',
      labelKey: 'query_courses_completionDate',
    ),
  ],
);
