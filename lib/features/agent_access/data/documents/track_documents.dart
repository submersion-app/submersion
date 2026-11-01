import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

/// Track clocks are wall-clock values flagged UTC, as stored epoch ms.
String _clock(int ms) =>
    wallClock(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));

/// A recorded underwater route, without its points.
Map<String, Object?> navTrackDocument(NavTrack t) => {
  'id': t.id,
  'dive_id': t.diveId,
  'site_id': t.siteId,
  'equipment_id': t.equipmentId,
  'name': t.name,
  'source': t.source.name,
  'source_ref': t.sourceRef,
  'device_name': t.deviceName,
  'link_mode': t.linkMode?.name,
  'is_primary': t.isPrimary,
  'start_time': _clock(t.startTime),
  'end_time': _clock(t.endTime),
  'tz_offset_minutes': t.tzOffsetMinutes,
  'time_offset_s': t.timeOffsetSeconds,
  'point_count': t.pointCount,
  'total_distance_m': t.totalDistance,
  'max_depth_m': t.maxDepth,
  'max_speed_m_s': t.maxSpeed,
  'avg_speed_m_s': t.avgSpeed,
  'duration_s': t.durationSeconds,
  'anchor_latitude': t.anchorLatitude,
  'anchor_longitude': t.anchorLongitude,
  'end_mode': t.endMode.name,
  'end_latitude': t.endLatitude,
  'end_longitude': t.endLongitude,
  'trust_fraction': t.trustFraction,
  'heading_offset_deg': t.headingOffsetDeg,
};

/// One window over a track's points, shaped like a dive's profile block.
Map<String, Object?> navTrackPointsDocument(
  List<NavTrackPoint> points,
  int offset,
  int limit,
) => {
  'offset': offset,
  'limit': limit,
  'total': points.length,
  'samples': [
    for (final p in points.skip(offset).take(limit))
      {
        'time_s': p.timestamp,
        'north_m': p.north,
        'east_m': p.east,
        'depth_m': p.depth,
        'course_deg': p.course,
        'speed_m_s': p.speed,
        'temperature_c': p.temperature,
      },
  ],
};

/// A surface GPS track, without its points. It has no owner: a recording
/// belongs to the device.
Map<String, Object?> gpsTrackDocument(GpsTrack t) => {
  'id': t.id,
  'name': t.name,
  'source': t.source,
  'source_ref': t.sourceRef,
  'device_name': t.deviceName,
  'start_time': _clock(t.startTime),
  'end_time': t.endTime == null ? null : _clock(t.endTime!),
  'tz_offset_minutes': t.tzOffsetMinutes,
  'point_count': t.pointCount,
  'trim_start_time': t.trimStartTime == null ? null : _clock(t.trimStartTime!),
  'trim_end_time': t.trimEndTime == null ? null : _clock(t.trimEndTime!),
};

Map<String, Object?> gpsTrackPointsDocument(
  List<GpsTrackPoint> points,
  int offset,
  int limit,
) => {
  'offset': offset,
  'limit': limit,
  'total': points.length,
  'samples': [
    for (final p in points.skip(offset).take(limit))
      {
        'time_s': p.timestamp,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy_m': p.accuracy,
      },
  ],
};
