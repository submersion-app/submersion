import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_card_ids.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The GPS track page's values a sitting edits (issue #4527, phase 3): its
/// name and its trim. Everything else on the page is recorded or calculated.

/// A trim's two bounds, wall-clock-as-UTC epoch milliseconds; null leaves
/// that end open.
typedef GpsTrackTrim = ({int? startMs, int? endMs});

const Object _keep = Object();

T? _or<T>(Object? value, T? kept) =>
    identical(value, _keep) ? kept : value as T?;

/// [t] with the given values, every other one kept. [GpsTrack.copyWith]
/// cannot clear a value, so the fields build the track whole.
GpsTrack _with(
  GpsTrack t, {
  Object? name = _keep,
  Object? trimStartTime = _keep,
  Object? trimEndTime = _keep,
}) => GpsTrack(
  id: t.id,
  startTime: t.startTime,
  endTime: t.endTime,
  tzOffsetMinutes: t.tzOffsetMinutes,
  deviceName: t.deviceName,
  pointCount: t.pointCount,
  points: t.points,
  source: t.source,
  sourceRef: t.sourceRef,
  name: _or<String>(name, t.name),
  trimStartTime: _or<int>(trimStartTime, t.trimStartTime),
  trimEndTime: _or<int>(trimEndTime, t.trimEndTime),
);

/// A blank name is stored as none, so the track falls back to its file.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The track's own label, on the header block.
final gpsTrackNameField = EditField<GpsTrack, String?>(
  id: 'name',
  cardId: GpsTrackCardId.header.name,
  read: (t) => t.name,
  write: (t, v) => _with(t, name: _orNone(v)),
  equals: (a, b) => _orNone(a) == _orNone(b),
);

/// Both trim bounds as one value, so Reset trim is one change.
final gpsTrackTrimField = EditField<GpsTrack, GpsTrackTrim>(
  id: 'trim',
  cardId: GpsTrackCardId.trim.name,
  read: (t) => (startMs: t.trimStartTime, endMs: t.trimEndTime),
  write: (t, v) => _with(t, trimStartTime: v.startMs, trimEndTime: v.endMs),
);
