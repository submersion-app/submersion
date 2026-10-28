import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/query/dive_aggregate_fields.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';

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
    "unicode_lower({r}.name) LIKE ? ESCAPE '\\'",
    "unicode_lower({r}.location) LIKE ? ESCAPE '\\'",
    "unicode_lower({r}.resort_name) LIKE ? ESCAPE '\\'",
    "unicode_lower({r}.liveaboard_name) LIKE ? ESCAPE '\\'",
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
    // Shared with everyone, or with chosen profiles by name (issue #2151).
    const QueryField(
      key: 'shared',
      type: FieldType.bool,
      sql:
          '({r}.is_shared = 1 OR {r}.id IN '
          '(SELECT trip_id FROM trip_shares))',
      tables: ['trip_shares'],
      emptySql: '0',
      labelKey: 'query_trips_shared',
    ),
    // A trip counts its side trips' dives too (issue #3658), read through
    // the trips table.
    diveCountField(
      'trips',
      tripDivesScopeSql('ad', '{r}.id'),
      tables: const ['trips'],
    ),
  ],
  relations: [
    // A trip's dives take in its side trips' (issue #3658). As an IN list
    // of the trip and its side trips, so the dives lookup keeps using
    // idx_dives_trip_id.
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      // Custom, not child: the hop is an IN list, not one equality.
      shape: RelationShape.custom,
      joinSql:
          '{to}.trip_id IN (SELECT {from}.id UNION ALL '
          '${sideTripIdsSql('{from}.id')})',
      isMany: true,
      labelKey: 'query_trips_dives',
      tables: const ['trips'],
    ),
    // The larger trip a side trip is part of (issue #3658). A link to a
    // trip that is itself a side trip, or to the trip itself, is no link.
    const QueryRelation(
      key: 'partOf',
      target: QuerySubject.trips,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.parent_trip_id',
      targetFilterSql: '{to}.parent_trip_id IS NULL',
      isMany: false,
      labelKey: 'query_trips_partOf',
    ),
  ],
);
