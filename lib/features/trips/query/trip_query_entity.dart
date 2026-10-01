import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/query/dive_aggregate_fields.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_trips_$key',
);

QueryField _date(String key, String column) => QueryField(
  key: key,
  type: FieldType.date,
  dateFrame: DateFrame.localInstant,
  sql: '{r}.$column',
  emptySql: '{r}.$column IS NULL',
  labelKey: 'query_trips_$key',
);

/// Every field and relation a trip query can name (#2365). The trip list's
/// filter lowers to these (`TripFilterQuery`); dive paths such as
/// `trip.tripType` walk them.
final tripQueryEntity = QueryEntity(
  subject: QuerySubject.trips,
  table: 'trips',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.location LIKE ? ESCAPE '\\'",
    "{r}.resort_name LIKE ? ESCAPE '\\'",
    "{r}.liveaboard_name LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    _text('location', 'location'),
    _date('startDate', 'start_date'),
    _date('endDate', 'end_date'),
    QueryField(
      key: 'tripType',
      type: FieldType.enumName,
      sql: '{r}.trip_type',
      emptySql: '{r}.trip_type IS NULL',
      labelKey: 'query_trips_tripType',
      enumValues: [for (final t in TripType.values) t.name],
    ),
    _text('resortName', 'resort_name'),
    _text('liveaboardName', 'liveaboard_name'),
    _text('notes', 'notes'),
    const QueryField(
      key: 'shared',
      type: FieldType.bool,
      sql: '{r}.is_shared',
      emptySql: '0',
      labelKey: 'query_trips_shared',
    ),
    diveCountField('trips', 'ad.trip_id = {r}.id'),
  ],
  relations: const [
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.child,
      joinSql: '{to}.trip_id = {from}.id',
      isMany: true,
      labelKey: 'query_trips_dives',
    ),
  ],
);
