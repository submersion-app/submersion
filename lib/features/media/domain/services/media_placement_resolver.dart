import 'package:latlong2/latlong.dart';

import 'package:submersion/features/media/data/services/gps_fix.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';

/// A resolved map position and the source it came from.
typedef ResolvedPlacement = ({LatLng point, MediaPlacement placement});

/// Picks where a media item sits on the map.
///
/// Own GPS wins, then the dive's entry fix, then the dive's site, then the
/// attached site. The two GPS sources must pass [isPlausibleFix], which
/// rejects the `(0, 0)` cameras and phones write when the receiver had no
/// fix. Site coordinates are typed by hand and trusted as stored, subject
/// only to the valid range, since flutter_map cannot place a point outside
/// it. Returns null when nothing usable is present.
ResolvedPlacement? resolveMediaPlacement({
  double? ownLatitude,
  double? ownLongitude,
  double? diveEntryLatitude,
  double? diveEntryLongitude,
  double? diveSiteLatitude,
  double? diveSiteLongitude,
  double? attachedSiteLatitude,
  double? attachedSiteLongitude,
}) {
  final own = _fix(ownLatitude, ownLongitude);
  if (own != null) return (point: own, placement: MediaPlacement.ownGps);

  final entry = _fix(diveEntryLatitude, diveEntryLongitude);
  if (entry != null) {
    return (point: entry, placement: MediaPlacement.diveEntry);
  }

  final site = _stored(diveSiteLatitude, diveSiteLongitude);
  if (site != null) return (point: site, placement: MediaPlacement.diveSite);

  final attached = _stored(attachedSiteLatitude, attachedSiteLongitude);
  if (attached != null) {
    return (point: attached, placement: MediaPlacement.attachedSite);
  }
  return null;
}

/// A GPS fix: both axes present and plausible.
LatLng? _fix(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  if (!isPlausibleFix(lat, lng)) return null;
  return LatLng(lat, lng);
}

/// A stored site position: both axes present and inside the valid ranges.
LatLng? _stored(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  if (!lat.isFinite || !lng.isFinite) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}
