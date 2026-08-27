import 'dart:math' as math;
import 'dart:ui';

/// Pure helpers for the density heat-map render passes.
///
/// Kept free of Flutter bindings so they can be unit-tested directly.

/// Per-point center intensity for the density accumulation pass.
///
/// Returns a value in `[floor, 1.0]`: a site at [maxWeight] returns 1.0, while
/// the faintest site returns [floor], guaranteeing it stays visible. The
/// [gamma] curve (gamma < 1, e.g. sqrt) lifts small weights so a single "home"
/// site no longer crushes everything else. Returns 0 when [maxWeight] <= 0.
double densityIntensity(
  double weight,
  double maxWeight, {
  double floor = 0.35,
  double gamma = 0.5,
}) {
  if (maxWeight <= 0) return 0.0;
  final normalized = (weight / maxWeight).clamp(0.0, 1.0);
  final softened = math.pow(normalized, gamma).toDouble();
  return floor + (1.0 - floor) * softened;
}

/// Radial-gradient colors + stops for a single density blob.
///
/// Uses white so the density pass records a single accumulating channel; the
/// alpha carries [intensity] at the center and falls to 0 at the edge with a
/// soft mid-stop for a bell-like cloud. [intensity] is clamped to `[0, 1]`.
({List<Color> colors, List<double> stops}) densityBlobGradient(
  double intensity,
) {
  final i = intensity.clamp(0.0, 1.0);
  return (
    colors: [
      Color.fromRGBO(255, 255, 255, i),
      Color.fromRGBO(255, 255, 255, i * 0.5),
      const Color.fromRGBO(255, 255, 255, 0.0),
    ],
    stops: const [0.0, 0.55, 1.0],
  );
}

/// Whether a blob centered at [screen] can contribute to the [size] canvas,
/// given cloud [radius]. Includes radius padding so a center just off-screen
/// still renders its visible edge.
bool isPointVisible(Offset screen, Size size, double radius) {
  return screen.dx >= -radius &&
      screen.dx <= size.width + radius &&
      screen.dy >= -radius &&
      screen.dy <= size.height + radius;
}
