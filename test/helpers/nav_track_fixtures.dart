import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

/// 2025-08-22 10:00 UTC, the recording start every fixture route shares
/// unless a test overrides it.
const int kTestRouteStartMs = 1755856800000;

/// Two samples ten minutes apart: the fewest `insertImportedRoute` accepts.
const List<NavTrackPoint> kTestNavTrackPoints = [
  NavTrackPoint(
    timestamp: 1755856800,
    north: 0,
    east: 0,
    depth: 5,
    distance: 0,
    speed: 0.3,
  ),
  NavTrackPoint(
    timestamp: 1755857400,
    north: 40,
    east: 0,
    depth: 5,
    distance: 40,
    speed: 0.3,
  ),
];

NavTrack testNavTrack(
  String id, {
  String? name,
  String? diveId,
  bool isPrimary = true,
  int? startTime,
  double? totalDistance,
}) {
  final start = startTime ?? kTestRouteStartMs;
  return NavTrack(
    id: id,
    name: name,
    diveId: diveId,
    isPrimary: isPrimary,
    source: NavTrackSource.seacraftEnc,
    sourceRef: '$id.csv',
    startTime: start,
    endTime: start + 3600000,
    pointCount: 0,
    totalDistance: totalDistance,
    createdAt: DateTime(2025, 8, 22),
    updatedAt: DateTime(2025, 8, 22),
  );
}
