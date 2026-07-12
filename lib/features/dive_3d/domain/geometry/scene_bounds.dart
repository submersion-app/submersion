/// Normalizes any dive into a fixed-size scene box so a 30 min / 18 m dive
/// and a 4 h / 100 m dive both fill the viewport with sane proportions.
/// X = run time (0..xSpan), Y = depth (0 at surface, -ySpan at max depth),
/// Z = lateral extrusion. [sceneMinY]/[sceneMaxY] describe the actual
/// vertical extent the renderer must fit; they default to the depth
/// convention but scenes whose Y rises (e.g. the tissue surface) override
/// them so the projector frames the geometry correctly.
class SceneBounds {
  final double durationSeconds;
  final double maxDepthMeters;
  final double sceneMinY;
  final double sceneMaxY;
  final double sceneMinZ;
  final double sceneMaxZ;

  static const double xSpan = 10.0;
  static const double ySpan = 6.0;
  static const double zHalfWidth = 0.09;
  static const double zSlabHalfWidth = 1.0;

  const SceneBounds({
    required this.durationSeconds,
    required this.maxDepthMeters,
    this.sceneMinY = -ySpan,
    this.sceneMaxY = 0,
    this.sceneMinZ = -zSlabHalfWidth,
    this.sceneMaxZ = zSlabHalfWidth,
  });

  double xOf(num seconds) =>
      durationSeconds <= 0 ? 0 : (seconds / durationSeconds) * xSpan;

  double yOf(num meters) =>
      maxDepthMeters <= 0 ? 0 : -(meters / maxDepthMeters) * ySpan;
}
