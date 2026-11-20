import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Whether changing a route's site should also move its anchor to the new
/// site's pin (item 5).
///
/// True only when the diver never touched the start point away from the old
/// site's pin: [currentAnchor] is unset, or still exactly equals
/// [oldSiteLocation]. If the diver already corrected the start point by
/// hand, changing the site must not silently move that correction: the
/// safer, more predictable rule the design settled on.
bool navTrackAnchorShouldFollowSiteChange(
  GeoPoint? currentAnchor,
  GeoPoint? oldSiteLocation,
) {
  return currentAnchor == null || currentAnchor == oldSiteLocation;
}

/// What changing a route's site does to its stored anchor.
///
/// `write` false keeps the anchor as it is (the diver placed it by hand).
/// Otherwise the anchor becomes `anchor`: the new site's pin, or null when
/// the new site has none, since an anchor that followed the old pin would
/// otherwise keep the route at the old site.
({bool write, GeoPoint? anchor}) navTrackAnchorChangeForSite(
  GeoPoint? currentAnchor,
  GeoPoint? oldSiteLocation,
  GeoPoint? newSiteLocation,
) {
  if (!navTrackAnchorShouldFollowSiteChange(currentAnchor, oldSiteLocation)) {
    return (write: false, anchor: null);
  }
  return (write: true, anchor: newSiteLocation);
}
