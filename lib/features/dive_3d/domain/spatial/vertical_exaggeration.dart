/// Auto-computed vertical exaggeration for the site seascape terrain
/// (issue #2141). [SpatialProjection.yOf] renders depth at the same
/// real-world scale as the horizontal axes, which is geometrically
/// accurate but reads as nearly flat for real dive sites: horizontal
/// extent typically runs into the hundreds or thousands of meters while
/// max depth is tens of meters.
///
/// [narrowSpanMeters] must be the site's own footprint (e.g. the
/// narrower side of its wet-area bounding box), not the bathymetry
/// tile's fetch radius: the tile is always fetched at a fixed span
/// (BathymetryResolver.defaultSpanMeters) regardless of the site's real
/// shape, so a 300 m-wide fjord-like lake inside an 8 km tile must not
/// be exaggerated as if it were 8 km wide -- it already reads reasonably
/// steep at its own scale.
///
/// Sites whose natural depth-to-span ratio already meets or exceeds
/// [targetDepthFraction] get no exaggeration at all (clamped to a floor
/// of 1.0): this is what keeps narrow, already-steep sites from being
/// stretched into unrealistic spikes, the opposite failure that #1767
/// fixed. [maxExaggeration] caps the other end, so an extremely wide,
/// flat site does not get exaggerated past a believable amount.
double computeVerticalExaggeration({
  required double maxDepthMeters,
  required double narrowSpanMeters,
  double targetDepthFraction = 0.35,
  double maxExaggeration = 8.0,
}) {
  final span = narrowSpanMeters < 1.0 ? 1.0 : narrowSpanMeters;
  final naturalRatio = maxDepthMeters / span;
  if (naturalRatio <= 0) return 1.0;
  final exaggeration = targetDepthFraction / naturalRatio;
  return exaggeration.clamp(1.0, maxExaggeration);
}

/// The range the diver can pick with the manual exaggeration slider
/// (issue #2141 follow-up: the automatic value can still read too strong
/// for some narrow lakes, so it must be adjustable down to true scale).
/// The upper bound sits above [computeVerticalExaggeration]'s default
/// 8x cap, so the slider still has headroom above whatever the automatic
/// value picked.
const double minManualVerticalExaggeration = 1.0;
const double maxManualVerticalExaggeration = 10.0;

/// Constrains a stored per-site override to the range the slider can
/// actually produce (Copilot review). The override travels from settings
/// to [SpatialProjection] without passing through the slider again, so a
/// row that was corrupted, hand-edited, or written by a client with a
/// different range would otherwise scale the entire scene by an arbitrary
/// factor and make it unusable.
///
/// A NaN is treated as "no usable value" rather than clamped: `num.clamp`
/// propagates NaN (every comparison against it is false), and
/// [SpatialProjection.depthScale] multiplies every vertex, so a single NaN
/// factor leaves nothing to render at all instead of merely distorting it.
double clampManualVerticalExaggeration(double factor) => factor.isNaN
    ? minManualVerticalExaggeration
    : factor.clamp(
        minManualVerticalExaggeration,
        maxManualVerticalExaggeration,
      );
