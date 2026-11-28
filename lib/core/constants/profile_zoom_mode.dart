/// What zooming the dive profile chart scales (issue #5069).
///
/// One choice for the diver, stored as two flags: the v262
/// `profileMetricsFollowViewport` and the v389 `profileZoomTimeOnly`. Time
/// only wins, and choosing it leaves the viewport flag alone, so going back to
/// a both-axes mode restores the one the diver had.
enum ProfileZoomMode {
  /// Both axes zoom, and the metric overlays (NDL, ppO2, temperature...)
  /// magnify with the depth axis. The default.
  magnifyOverlays,

  /// Both axes zoom, and the metric overlays re-fit the visible depth slice.
  keepOverlaysInView,

  /// Only the time axis zooms; depth always runs from the surface to the
  /// deepest point.
  timeOnly;

  /// The mode two stored flags stand for.
  static ProfileZoomMode fromFlags({
    required bool timeOnly,
    required bool followViewport,
  }) {
    if (timeOnly) return ProfileZoomMode.timeOnly;
    return followViewport
        ? ProfileZoomMode.keepOverlaysInView
        : ProfileZoomMode.magnifyOverlays;
  }
}
