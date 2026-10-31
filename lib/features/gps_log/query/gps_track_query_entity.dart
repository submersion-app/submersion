import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_gpsTracks_$key',
);

/// Where a trim starts or ends, or the recording's own edge: what the track's
/// page shows, since a trim never rewrites the points.
const _start = 'COALESCE({r}.trim_start_time, {r}.start_time)';
const _end = 'COALESCE({r}.trim_end_time, {r}.end_time)';

/// Every field a GPS track query can name (#3882). Global search roots here:
/// the tracks have no list query of their own.
final gpsTrackQueryEntity = QueryEntity(
  subject: QuerySubject.gpsTracks,
  table: 'gps_tracks',
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
      sql: _start,
      emptySql: '0',
      labelKey: 'query_gpsTracks_date',
    ),
    const QueryField(
      key: 'duration',
      type: FieldType.number,
      dimension: FieldDimension.minutes,
      sql: '(($_end - $_start) / 60000)',
      emptySql: '{r}.end_time IS NULL',
      labelKey: 'query_gpsTracks_duration',
    ),
    _text('deviceName', 'device_name'),
    _text('source', 'source'),
    _text('file', 'source_ref'),
  ],
);
