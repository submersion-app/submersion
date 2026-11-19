import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Where [item] was taken, for limiting marine life names to the species
/// recorded there (issues #4668, #4727): its own position, else its dive's
/// site ([siteLocation]), else where the dive's computer logged its entry
/// ([entryLocation]).
GeoPoint? mediaLocation(
  MediaItem item, {
  GeoPoint? siteLocation,
  GeoPoint? entryLocation,
}) {
  final lat = item.latitude;
  final lon = item.longitude;
  if (lat != null && lon != null) return GeoPoint(lat, lon);
  return siteLocation ?? entryLocation;
}
