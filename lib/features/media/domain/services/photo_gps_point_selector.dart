import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// One GPS-tagged media row linked to a dive.
typedef PhotoGpsPoint = ({String mediaId, GeoPoint location, DateTime takenAt});

/// The photo most likely shot at the site: the one whose capture time is
/// nearest the dive's entry time. The earliest photo (the previous rule) is
/// often a hotel or car-park shot; the one nearest entry is on the boat or
/// the shore. Every linked photo is eligible, because a manual link is the
/// diver asserting the photo belongs to this dive. Ties go to the earlier
/// sample. Both times are wall-clock-UTC, so they compare directly.
PhotoGpsPoint? selectBestPhotoGps(
  List<PhotoGpsPoint> samples,
  DateTime entryTime,
) {
  PhotoGpsPoint? best;
  Duration? bestGap;
  for (final s in samples) {
    final gap = s.takenAt.difference(entryTime).abs();
    final better =
        bestGap == null ||
        gap < bestGap ||
        (gap == bestGap && s.takenAt.isBefore(best!.takenAt));
    if (better) {
      best = s;
      bestGap = gap;
    }
  }
  return best;
}
