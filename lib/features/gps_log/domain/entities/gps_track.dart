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

  /// Provenance: 'phone' | 'gpx' | 'fit' | 'kml' | 'csv'. Rendering code
  /// treats this as opaque - no view logic branches on it.
  final String source;

  /// Originating filename or device, for imported tracks.
  final String? sourceRef;

  /// User-editable label.
  final String? name;

  /// Non-destructive trim bounds, wall-clock-as-UTC epoch MILLISECONDS.
  final int? trimStartTime;
  final int? trimEndTime;

  const GpsTrack({
    required this.id,
    required this.startTime,
    this.endTime,
    this.tzOffsetMinutes = 0,
    this.deviceName,
    this.pointCount = 0,
    this.points = const [],
    this.source = 'phone',
    this.sourceRef,
    this.name,
    this.trimStartTime,
    this.trimEndTime,
  });

  /// Recording window start, honouring a non-destructive trim.
  ///
  /// Read this rather than [startTime] anywhere the question is "does this
  /// track cover instant X" - a trim exists precisely so the drive to the
  /// marina stops matching.
  int get effectiveStartTime => trimStartTime ?? startTime;

  /// Recording window end, honouring a non-destructive trim. Null while
  /// recording.
  int? get effectiveEndTime => trimEndTime ?? endTime;

  /// The points this track actually represents, honouring non-destructive
  /// trim bounds.
  ///
  /// Every consumer - rendering, statistics, export, dive matching - reads
  /// through this rather than [points], so trimming cannot be silently
  /// ignored by one call site. Trim bounds are epoch MILLISECONDS while
  /// point timestamps are epoch SECONDS, hence the division.
  List<GpsTrackPoint> get effectivePoints {
    final start = trimStartTime;
    final end = trimEndTime;
    if (start == null && end == null) return points;
    return List.unmodifiable([
      for (final p in points)
        if ((start == null || p.timestamp >= start ~/ 1000) &&
            (end == null || p.timestamp <= end ~/ 1000))
          p,
    ]);
  }

  /// Fix count inside the trim window, or null when it cannot be known here.
  ///
  /// [pointCount] is a stored scalar covering the WHOLE recording, so a
  /// trimmed track's real count is only knowable once the blob is decoded.
  /// List rows are deliberately hydrated without points, so they get null and
  /// must omit the count rather than print an untrimmed one next to a trimmed
  /// duration.
  int? get effectivePointCount {
    if (trimStartTime == null && trimEndTime == null) return pointCount;
    if (points.isEmpty) return pointCount == 0 ? 0 : null;
    return effectivePoints.length;
  }

  GpsTrack copyWith({
    String? id,
    int? startTime,
    int? endTime,
    int? tzOffsetMinutes,
    String? deviceName,
    int? pointCount,
    List<GpsTrackPoint>? points,
    String? source,
    String? sourceRef,
    String? name,
    int? trimStartTime,
    int? trimEndTime,
  }) {
    return GpsTrack(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      deviceName: deviceName ?? this.deviceName,
      pointCount: pointCount ?? this.pointCount,
      points: points ?? this.points,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      name: name ?? this.name,
      trimStartTime: trimStartTime ?? this.trimStartTime,
      trimEndTime: trimEndTime ?? this.trimEndTime,
    );
  }
}
