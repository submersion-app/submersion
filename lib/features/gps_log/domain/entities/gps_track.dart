/// A single recorded GPS fix.
///
/// [timestamp] is a wall-clock-as-UTC epoch in SECONDS: the recording
/// device's local wall-clock components reinterpreted as UTC, matching the
/// convention used by dives.entryTime so points compare directly against
/// dive timestamps on any device.
class GpsTrackPoint {
  final int timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;

  const GpsTrackPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });
}

/// A recorded GPS surface track (one recording session).
///
/// [startTime] and [endTime] are wall-clock-as-UTC epoch MILLISECONDS,
/// matching dives.entryTime. [endTime] is null while recording.
class GpsTrack {
  final String id;
  final int startTime;
  final int? endTime;
  final int tzOffsetMinutes;
  final String? deviceName;
  final int pointCount;
  final List<GpsTrackPoint> points;

  const GpsTrack({
    required this.id,
    required this.startTime,
    this.endTime,
    this.tzOffsetMinutes = 0,
    this.deviceName,
    this.pointCount = 0,
    this.points = const [],
  });

  GpsTrack copyWith({
    String? id,
    int? startTime,
    int? endTime,
    int? tzOffsetMinutes,
    String? deviceName,
    int? pointCount,
    List<GpsTrackPoint>? points,
  }) {
    return GpsTrack(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      deviceName: deviceName ?? this.deviceName,
      pointCount: pointCount ?? this.pointCount,
      points: points ?? this.points,
    );
  }
}
