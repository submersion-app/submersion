import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

/// Which device family produced a route.
///
/// Rendering never branches on this -- only the caption and the parser
/// registry do -- but it drives which parser can re-read a re-imported
/// file and which label the UI shows.
enum NavTrackSource {
  seacraftEnc,
  suuntoRoute;

  /// The value stored in `nav_tracks.source`.
  String get wireValue => switch (this) {
    NavTrackSource.seacraftEnc => 'seacraft_enc',
    NavTrackSource.suuntoRoute => 'suunto_route',
  };

  static NavTrackSource fromWireValue(String value) => switch (value) {
    'seacraft_enc' => NavTrackSource.seacraftEnc,
    'suunto_route' => NavTrackSource.suuntoRoute,
    _ => throw ArgumentError.value(value, 'value', 'unknown nav track source'),
  };

  String get label => switch (this) {
    NavTrackSource.seacraftEnc => 'Seacraft ENC',
    NavTrackSource.suuntoRoute => 'Suunto route',
  };
}

/// How a route came to be linked to a dive.
enum NavTrackLinkMode {
  /// The match sweep linked it because exactly one dive overlapped in time.
  auto,

  /// The diver chose the dive by hand.
  manual;

  String get wireValue => name;

  static NavTrackLinkMode? fromWireValue(String? value) => switch (value) {
    null => null,
    'auto' => NavTrackLinkMode.auto,
    'manual' => NavTrackLinkMode.manual,
    _ => throw ArgumentError.value(value, 'value', 'unknown link mode'),
  };
}

extension NavTrackEndModeWire on NavTrackEndMode {
  /// The value stored in `nav_tracks.end_mode`.
  String get wireValue => switch (this) {
    NavTrackEndMode.none => 'none',
    NavTrackEndMode.sameAsStart => 'same_as_start',
    NavTrackEndMode.point => 'point',
    NavTrackEndMode.gpsFix => 'gps_fix',
  };

  static NavTrackEndMode fromWireValue(String value) => switch (value) {
    'none' => NavTrackEndMode.none,
    'same_as_start' => NavTrackEndMode.sameAsStart,
    'point' => NavTrackEndMode.point,
    'gps_fix' => NavTrackEndMode.gpsFix,
    _ => throw ArgumentError.value(value, 'value', 'unknown end mode'),
  };
}

/// A measured underwater route: the `nav_tracks` row, plus its samples when
/// hydrated. A list read omits [points] ([pointCount] is the cheap summary
/// for that case); a detail read includes them.
class NavTrack extends Equatable {
  final String id;

  /// The dive this route belongs to, or null while unlinked.
  final String? diveId;

  /// Null exactly when [diveId] is null.
  final NavTrackLinkMode? linkMode;

  /// The route a dive's 3D seascape draws when several are linked to it.
  final bool isPrimary;

  /// The dive site chosen at import, or inherited from the linked dive:
  /// the default map anchor until the diver corrects it.
  final String? siteId;

  final NavTrackSource source;

  /// Originating file name.
  final String? sourceRef;
  final String? deviceName;

  /// User-editable label; defaults to the file name.
  final String? name;

  /// Optional link to the console or scooter in the equipment list.
  final String? equipmentId;

  /// Wall-clock-as-UTC epoch milliseconds (dives.entryTime convention).
  final int startTime;
  final int endTime;
  final int tzOffsetMinutes;

  /// Seconds added to the device's clock to place it on the linked dive's
  /// timeline.
  final int timeOffsetSeconds;

  final int pointCount;

  /// Metres, from the device's own log when present and monotone, else
  /// path length -- see `NavTrackStats`.
  final double? totalDistance;

  /// Metres.
  final double? maxDepth;

  /// Metres per second.
  final double? maxSpeed;

  /// Metres per second.
  final double? avgSpeed;

  final double? anchorLatitude;
  final double? anchorLongitude;

  final NavTrackEndMode endMode;
  final double? endLatitude;
  final double? endLongitude;

  /// 0 to 1: fraction of cumulative distance trusted as recorded.
  final double trustFraction;

  /// Clockwise rotation in degrees.
  final double headingOffsetDeg;

  /// Hydrated on demand; empty on a list row.
  final List<NavTrackPoint> points;

  final DateTime createdAt;
  final DateTime updatedAt;

  const NavTrack({
    required this.id,
    this.diveId,
    this.linkMode,
    this.isPrimary = true,
    this.siteId,
    required this.source,
    this.sourceRef,
    this.deviceName,
    this.name,
    this.equipmentId,
    required this.startTime,
    required this.endTime,
    this.tzOffsetMinutes = 0,
    this.timeOffsetSeconds = 0,
    required this.pointCount,
    this.totalDistance,
    this.maxDepth,
    this.maxSpeed,
    this.avgSpeed,
    this.anchorLatitude,
    this.anchorLongitude,
    this.endMode = NavTrackEndMode.none,
    this.endLatitude,
    this.endLongitude,
    this.trustFraction = 0,
    this.headingOffsetDeg = 0,
    this.points = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Where the route's local origin sits on the map, or null until the
  /// diver sets one.
  GeoPoint? get anchor => (anchorLatitude == null || anchorLongitude == null)
      ? null
      : GeoPoint(anchorLatitude!, anchorLongitude!);

  /// The target for [NavTrackEndMode.point], or null otherwise / until set.
  GeoPoint? get endPoint => (endLatitude == null || endLongitude == null)
      ? null
      : GeoPoint(endLatitude!, endLongitude!);

  /// The correction [NavTrackCorrector.apply] reads: this row's anchor, end
  /// target, trust fraction and rotation, assembled from the columns above.
  NavTrackCorrection get correction => NavTrackCorrection(
    anchor: anchor,
    endMode: endMode,
    endPoint: endPoint,
    trustFraction: trustFraction,
    headingOffsetDeg: headingOffsetDeg,
  );

  NavTrack copyWith({
    String? id,
    String? diveId,
    NavTrackLinkMode? linkMode,
    bool? isPrimary,
    String? siteId,
    NavTrackSource? source,
    String? sourceRef,
    String? deviceName,
    String? name,
    String? equipmentId,
    int? startTime,
    int? endTime,
    int? tzOffsetMinutes,
    int? timeOffsetSeconds,
    int? pointCount,
    double? totalDistance,
    double? maxDepth,
    double? maxSpeed,
    double? avgSpeed,
    double? anchorLatitude,
    double? anchorLongitude,
    NavTrackEndMode? endMode,
    double? endLatitude,
    double? endLongitude,
    double? trustFraction,
    double? headingOffsetDeg,
    List<NavTrackPoint>? points,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NavTrack(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      linkMode: linkMode ?? this.linkMode,
      isPrimary: isPrimary ?? this.isPrimary,
      siteId: siteId ?? this.siteId,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      deviceName: deviceName ?? this.deviceName,
      name: name ?? this.name,
      equipmentId: equipmentId ?? this.equipmentId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      timeOffsetSeconds: timeOffsetSeconds ?? this.timeOffsetSeconds,
      pointCount: pointCount ?? this.pointCount,
      totalDistance: totalDistance ?? this.totalDistance,
      maxDepth: maxDepth ?? this.maxDepth,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      anchorLatitude: anchorLatitude ?? this.anchorLatitude,
      anchorLongitude: anchorLongitude ?? this.anchorLongitude,
      endMode: endMode ?? this.endMode,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      trustFraction: trustFraction ?? this.trustFraction,
      headingOffsetDeg: headingOffsetDeg ?? this.headingOffsetDeg,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    linkMode,
    isPrimary,
    siteId,
    source,
    sourceRef,
    deviceName,
    name,
    equipmentId,
    startTime,
    endTime,
    tzOffsetMinutes,
    timeOffsetSeconds,
    pointCount,
    totalDistance,
    maxDepth,
    maxSpeed,
    avgSpeed,
    anchorLatitude,
    anchorLongitude,
    endMode,
    endLatitude,
    endLongitude,
    trustFraction,
    headingOffsetDeg,
    points,
    createdAt,
    updatedAt,
  ];
}
