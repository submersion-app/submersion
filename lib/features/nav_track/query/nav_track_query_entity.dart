import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_navTracks_$key',
);

/// A route's link to [target] through [column].
QueryRelation _link(String key, QuerySubject target, String column) =>
    QueryRelation(
      key: key,
      target: target,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.$column',
      isMany: false,
      labelKey: 'query_navTracks_$key',
    );

/// Every field and relation an underwater route query can name (#3882).
/// Global search roots here: the routes have no list query of their own.
/// Depth, distance and duration read the summary columns a list row reads,
/// so no route's points are decoded.
final navTrackQueryEntity = QueryEntity(
  subject: QuerySubject.navTracks,
  table: 'nav_tracks',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "unicode_lower({r}.name) LIKE ? ESCAPE '\\'",
    "unicode_lower({r}.source_ref) LIKE ? ESCAPE '\\'",
    "unicode_lower({r}.device_name) LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    const QueryField(
      key: 'date',
      type: FieldType.date,
      sql: '{r}.start_time',
      emptySql: '0',
      labelKey: 'query_navTracks_date',
    ),
    const QueryField(
      key: 'depth',
      aliases: ['maxDepth'],
      type: FieldType.number,
      dimension: FieldDimension.depth,
      sql: '{r}.max_depth',
      emptySql: '{r}.max_depth IS NULL',
      labelKey: 'query_navTracks_depth',
      sanity: (min: 0, max: 400),
    ),
    const QueryField(
      key: 'distance',
      type: FieldType.number,
      // Metres, which read and print through the diver's depth unit.
      dimension: FieldDimension.depth,
      sql: '{r}.total_distance',
      emptySql: '{r}.total_distance IS NULL',
      labelKey: 'query_navTracks_distance',
    ),
    const QueryField(
      key: 'duration',
      type: FieldType.number,
      dimension: FieldDimension.minutes,
      sql: '({r}.duration_seconds / 60)',
      emptySql: '{r}.duration_seconds IS NULL',
      labelKey: 'query_navTracks_duration',
    ),
    _text('deviceName', 'device_name'),
    _text('source', 'source'),
    _text('file', 'source_ref'),
  ],
  relations: [
    _link('dive', QuerySubject.dives, 'dive_id'),
    _link('site', QuerySubject.sites, 'site_id'),
    _link('equipment', QuerySubject.equipment, 'equipment_id'),
  ],
);
