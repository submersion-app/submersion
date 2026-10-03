import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// [routes] ordered by how close each recording started to [entryTime],
/// nearest first, as a new list. Ties go to the earlier recording, then to
/// the lower id, so every device shows the same order.
///
/// [entryTime] is a dive time as the app stores it and is compared with
/// [NavTrack.startTime] exactly as the dive detail section's link picker
/// always compared them.
List<NavTrack> sortByProximityTo(
  Iterable<NavTrack> routes,
  DateTime entryTime,
) {
  final entryMs = entryTime.millisecondsSinceEpoch;
  int gap(NavTrack route) => (route.startTime - entryMs).abs();
  return [...routes]..sort((a, b) {
    final byGap = gap(a).compareTo(gap(b));
    if (byGap != 0) return byGap;
    final byStart = a.startTime.compareTo(b.startTime);
    if (byStart != 0) return byStart;
    return a.id.compareTo(b.id);
  });
}
