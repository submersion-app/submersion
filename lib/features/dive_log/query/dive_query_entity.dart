import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

/// Every field and relation a dive query can name (#2365). This file is
/// the ONLY place a dive filter axis is defined: the paginated list, its
/// count, Statistics and the entity-backed views all compile from it.
///
/// SQL is written against `{r}`, the dive row's alias at whatever depth
/// the compiler reaches it. Every fragment is a column, an expression or a
/// correlated subquery; values are never interpolated.

String _label(String key) => 'query_dives_$key';

const _weekday =
    "CAST(strftime('%w', {r}.dive_date_time / 1000, 'unixepoch') AS INTEGER)";
const _year =
    "CAST(strftime('%Y', {r}.dive_date_time / 1000, 'unixepoch') AS INTEGER)";
const _weightsExist =
    'EXISTS (SELECT 1 FROM dive_weights w WHERE w.dive_id = {r}.id)';

/// The gear union the equipment axes have always used: items linked
/// through `dive_equipment` plus cylinders the transmitter registry matched
/// through `dive_tanks.equipment_id`.
const kDiveGearJoinSql =
    '{to}.id IN (SELECT de.equipment_id FROM dive_equipment de '
    'WHERE de.dive_id = {from}.id '
    'UNION SELECT dt.equipment_id FROM dive_tanks dt '
    'WHERE dt.dive_id = {from}.id AND dt.equipment_id IS NOT NULL)';

List<String> _names<T extends Enum>(List<T> values) => [
  for (final v in values) v.name,
];

QueryField _num(
  String key,
  String sql, {
  List<String> aliases = const [],
  FieldDimension dimension = FieldDimension.none,
  ({double min, double max})? sanity,
  String? emptySql,
  List<String> tables = const [],
}) => QueryField(
  key: key,
  aliases: aliases,
  type: FieldType.number,
  dimension: dimension,
  sql: sql,
  emptySql: emptySql ?? '$sql IS NULL',
  labelKey: _label(key),
  sanity: sanity,
  tables: tables,
);

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: _label(key),
);

QueryField _enum(String key, String column, List<String> values) => QueryField(
  key: key,
  type: FieldType.enumName,
  sql: '{r}.$column',
  emptySql: '{r}.$column IS NULL',
  labelKey: _label(key),
  enumValues: values,
);

QueryField _bool(String key, String column) => QueryField(
  key: key,
  type: FieldType.bool,
  sql: '{r}.$column',
  emptySql: '0',
  labelKey: _label(key),
);

QueryRelation _fk(
  String key,
  QuerySubject target,
  String column, {
  List<String> aliases = const [],
}) => QueryRelation(
  key: key,
  aliases: aliases,
  target: target,
  shape: RelationShape.fk,
  joinSql: '{to}.id = {from}.$column',
  isMany: false,
  labelKey: _label(key),
);

QueryRelation _child(String key, QuerySubject target) => QueryRelation(
  key: key,
  target: target,
  shape: RelationShape.child,
  joinSql: '{to}.dive_id = {from}.id',
  isMany: true,
  labelKey: _label(key),
);

QueryRelation _junction(
  String key,
  QuerySubject target,
  String junction,
  String targetColumn, {
  List<String> aliases = const [],
  String? emptySql,
}) => QueryRelation(
  key: key,
  aliases: aliases,
  target: target,
  shape: RelationShape.junction,
  // `IN (subquery)` rather than a nested EXISTS: SQLite then probes the
  // target by its primary key instead of scanning it and testing the
  // junction per row (the EXPLAIN QUERY PLAN test pins this).
  joinSql:
      '{to}.id IN (SELECT j.$targetColumn FROM $junction j '
      'WHERE j.dive_id = {from}.id)',
  isMany: true,
  labelKey: _label(key),
  emptySql: emptySql,
  tables: [junction],
);

final QueryEntity diveQueryEntity = QueryEntity(
  subject: QuerySubject.dives,
  table: 'dives',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "{r}.notes LIKE ? ESCAPE '\\'",
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.buddy LIKE ? ESCAPE '\\'",
    "{r}.dive_master LIKE ? ESCAPE '\\'",
    'EXISTS (SELECT 1 FROM dive_sites ts WHERE ts.id = {r}.site_id '
        "AND (ts.name LIKE ? ESCAPE '\\' OR ts.country LIKE ? ESCAPE '\\' "
        "OR ts.region LIKE ? ESCAPE '\\'))",
    'EXISTS (SELECT 1 FROM dive_centers tc WHERE tc.id = {r}.dive_center_id '
        "AND tc.name LIKE ? ESCAPE '\\')",
    'EXISTS (SELECT 1 FROM dive_buddies tdb JOIN buddies tb '
        'ON tb.id = tdb.buddy_id WHERE tdb.dive_id = {r}.id '
        "AND tb.name LIKE ? ESCAPE '\\')",
    'EXISTS (SELECT 1 FROM dive_tags tdt JOIN tags tt ON tt.id = tdt.tag_id '
        "WHERE tdt.dive_id = {r}.id AND tt.name LIKE ? ESCAPE '\\')",
    'EXISTS (SELECT 1 FROM dive_custom_fields tcf WHERE tcf.dive_id = {r}.id '
        "AND (tcf.field_key LIKE ? ESCAPE '\\' "
        "OR tcf.field_value LIKE ? ESCAPE '\\'))",
  ],
  textSearchTables: const [
    'dive_sites',
    'dive_centers',
    'dive_buddies',
    'buddies',
    'dive_tags',
    'tags',
    'dive_custom_fields',
  ],
  fields: [
    QueryField(
      key: 'id',
      type: FieldType.id,
      sql: '{r}.id',
      emptySql: '{r}.id IS NULL',
      labelKey: _label('id'),
    ),
    _num(
      'diveNumber',
      '{r}.dive_number',
      aliases: ['number'],
      dimension: FieldDimension.count,
    ),
    _text('name', 'name'),
    QueryField(
      key: 'date',
      type: FieldType.date,
      sql: '{r}.dive_date_time',
      emptySql: '{r}.dive_date_time IS NULL',
      labelKey: _label('date'),
    ),
    _num(
      'year',
      _year,
      dimension: FieldDimension.count,
      emptySql: '{r}.dive_date_time IS NULL',
    ),
    QueryField(
      key: 'weekday',
      type: FieldType.enumName,
      sql: _weekday,
      emptySql: '{r}.dive_date_time IS NULL',
      labelKey: _label('weekday'),
      enumValues: const [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ],
      enumSqlValues: const {
        'monday': 1,
        'tuesday': 2,
        'wednesday': 3,
        'thursday': 4,
        'friday': 5,
        'saturday': 6,
        'sunday': 0,
      },
    ),
    // Whole minutes, truncated, mirroring Duration.inMinutes in the old
    // apply(); the list path used seconds * 60 and disagreed with the
    // other two by up to 59 seconds.
    _num(
      'bottomTime',
      '({r}.bottom_time / 60)',
      aliases: ['time', 'duration'],
      dimension: FieldDimension.minutes,
      emptySql: '{r}.bottom_time IS NULL',
    ),
    _num(
      'runtime',
      '({r}.runtime / 60)',
      dimension: FieldDimension.minutes,
      emptySql: '{r}.runtime IS NULL',
    ),
    _num(
      'depth',
      '{r}.max_depth',
      aliases: ['maxDepth'],
      dimension: FieldDimension.depth,
      sanity: (min: 0, max: 400),
    ),
    _num(
      'avgDepth',
      '{r}.avg_depth',
      dimension: FieldDimension.depth,
      sanity: (min: 0, max: 400),
    ),
    // The synced water temperature. dive_sensor_summaries.min_temperature
    // is device-local and never synced, so it is not offered.
    _num(
      'waterTemp',
      '{r}.water_temp',
      aliases: ['temp'],
      dimension: FieldDimension.temperature,
      sanity: (min: -5, max: 45),
    ),
    _num(
      'airTemp',
      '{r}.air_temp',
      dimension: FieldDimension.temperature,
      sanity: (min: -40, max: 60),
    ),
    _num(
      'visibility',
      '{r}.visibility_meters',
      dimension: FieldDimension.depth,
      emptySql:
          '({r}.visibility_meters IS NULL AND ({r}.visibility IS NULL '
          "OR TRIM({r}.visibility) = ''))",
    ),
    _num(
      'rating',
      '{r}.rating',
      dimension: FieldDimension.count,
      sanity: (min: 0, max: 5),
    ),
    _num(
      'surfaceInterval',
      '({r}.surface_interval_seconds / 60)',
      dimension: FieldDimension.minutes,
      emptySql: '{r}.surface_interval_seconds IS NULL',
    ),
    _num(
      'cnsEnd',
      '{r}.cns_end',
      aliases: ['cns'],
      dimension: FieldDimension.percent,
    ),
    _num('otu', '{r}.otu', dimension: FieldDimension.count),
    // Total lead in kg: the weights table when it has rows, else the
    // legacy scalar the edit form retired (#1392). Empty means neither.
    _num(
      'weight',
      'COALESCE((SELECT SUM(w.amount_kg) FROM dive_weights w '
          'WHERE w.dive_id = {r}.id), {r}.weight_amount)',
      aliases: ['lead'],
      dimension: FieldDimension.weight,
      emptySql: '({r}.weight_amount IS NULL AND NOT $_weightsExist)',
      tables: ['dive_weights'],
    ),
    _num(
      'gasCount',
      '(SELECT COUNT(*) FROM dive_tanks t WHERE t.dive_id = {r}.id)',
      dimension: FieldDimension.count,
      emptySql: '0',
      tables: ['dive_tanks'],
    ),
    _text('notes', 'notes'),
    // The legacy free-text buddy column (#757): the dive editor writes only
    // dive_buddies, but old data still carries names here.
    _text('legacyBuddy', 'buddy'),
    _text('diveMaster', 'dive_master'),
    _text('boatName', 'boat_name'),
    _text('diveOperator', 'dive_operator'),
    _text('surfaceConditions', 'surface_conditions'),
    _enum(
      'currentStrength',
      'current_strength',
      _names(CurrentStrength.values),
    ),
    _enum('waterType', 'water_type', _names(WaterType.values)),
    _enum('entryMethod', 'entry_method', _names(EntryMethod.values)),
    _enum('exitMethod', 'exit_method', _names(EntryMethod.values)),
    _enum('diveMode', 'dive_mode', _names(DiveMode.values)),
    _bool('favorite', 'is_favorite'),
    _bool('excludedFromStats', 'excluded_from_stats'),
    _bool('planned', 'is_planned'),
    QueryField(
      key: 'deco',
      type: FieldType.bool,
      sql: '',
      emptySql: '0',
      labelKey: _label('deco'),
      boolSql: (
        whenTrue: decoSignalCondition(wantDeco: true, diveIdRef: '{r}.id'),
        whenFalse: decoSignalCondition(wantDeco: false, diveIdRef: '{r}.id'),
      ),
      tables: const ['dive_profile_series', 'dive_profile_events'],
    ),
    QueryField(
      key: 'hasProfile',
      type: FieldType.bool,
      sql: '',
      emptySql: '0',
      labelKey: _label('hasProfile'),
      boolSql: (
        whenTrue:
            'EXISTS (SELECT 1 FROM dive_profile_series s '
            'WHERE s.dive_id = {r}.id)',
        whenFalse:
            'NOT EXISTS (SELECT 1 FROM dive_profile_series s '
            'WHERE s.dive_id = {r}.id)',
      ),
      tables: const ['dive_profile_series'],
    ),
  ],
  relations: [
    _fk('site', QuerySubject.sites, 'site_id'),
    _fk('trip', QuerySubject.trips, 'trip_id'),
    _fk(
      'center',
      QuerySubject.centers,
      'dive_center_id',
      aliases: ['diveCenter'],
    ),
    _fk('computer', QuerySubject.computers, 'computer_id'),
    _fk('course', QuerySubject.courses, 'course_id'),
    _junction(
      'buddies',
      QuerySubject.buddies,
      'dive_buddies',
      'buddy_id',
      aliases: ['buddy'],
      emptySql:
          "(({from}.buddy IS NULL OR {from}.buddy = '') AND NOT EXISTS "
          '(SELECT 1 FROM dive_buddies j WHERE j.dive_id = {from}.id))',
    ),
    _junction(
      'tags',
      QuerySubject.tags,
      'dive_tags',
      'tag_id',
      aliases: ['tag'],
    ),
    _junction(
      'types',
      QuerySubject.diveTypes,
      'dive_dive_types',
      'dive_type_id',
      aliases: ['type', 'diveType'],
    ),
    QueryRelation(
      key: 'gear',
      aliases: const ['equipment'],
      target: QuerySubject.equipment,
      shape: RelationShape.custom,
      joinSql: kDiveGearJoinSql,
      isMany: true,
      labelKey: _label('gear'),
      tables: const ['dive_equipment', 'dive_tanks'],
    ),
    _child('tanks', QuerySubject.tanks),
    _child('weights', QuerySubject.weights),
    _child('customFields', QuerySubject.customFields),
    _child('sightings', QuerySubject.sightings),
    _child('media', QuerySubject.media),
  ],
);
