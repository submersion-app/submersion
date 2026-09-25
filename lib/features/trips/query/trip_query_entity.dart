import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// Minimal in PR 1; PR 3 of #2365 completes it.
const tripQueryEntity = QueryEntity(
  subject: QuerySubject.trips,
  table: 'trips',
  diverScopeColumn: 'diver_id',
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_trips_name',
    ),
    QueryField(
      key: 'location',
      type: FieldType.text,
      sql: '{r}.location',
      emptySql: "({r}.location IS NULL OR TRIM({r}.location) = '')",
      labelKey: 'query_trips_location',
    ),
    QueryField(
      key: 'startDate',
      type: FieldType.date,
      sql: '{r}.start_date',
      emptySql: '{r}.start_date IS NULL',
      labelKey: 'query_trips_startDate',
    ),
    QueryField(
      key: 'endDate',
      type: FieldType.date,
      sql: '{r}.end_date',
      emptySql: '{r}.end_date IS NULL',
      labelKey: 'query_trips_endDate',
    ),
  ],
);
