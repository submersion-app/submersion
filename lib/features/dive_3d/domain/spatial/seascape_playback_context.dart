/// What `SiteTerrainPane` is being asked to additionally play back, on top
/// of its default site-only view: either one dive's reconstructed path, or
/// one underwater route's. `null` (the pane's default) means the plain
/// site-only view, unchanged from before this type existed.
///
/// Deliberately not named with "overlay": `SceneOverlay` already names the
/// marker/contour/wall/feature toggles, and reusing that word for this
/// unrelated concept (which dive or route is being played back) would make
/// the two impossible to tell apart in code and review.
sealed class SeascapePlaybackContext {
  const SeascapePlaybackContext();
}

/// Playing back one dive's reconstructed path. Unlocks the path-provenance
/// caption and the "show measured route" toggle, in addition to the
/// timeline every variant gets.
class DivePlaybackContext extends SeascapePlaybackContext {
  final String diveId;

  const DivePlaybackContext(this.diveId);
}

/// Playing back one underwater route's path. No provenance toggle: a route
/// IS the recorded path, there is no dead-reckoned alternative to switch to.
class NavTrackPlaybackContext extends SeascapePlaybackContext {
  final String trackId;

  const NavTrackPlaybackContext(this.trackId);
}
