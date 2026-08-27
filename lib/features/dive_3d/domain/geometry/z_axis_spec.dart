import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';

/// The Z axis of the path scene: a nice-number range in the diver's DISPLAY
/// unit (the provider converts before building), mapped onto the scene's
/// Z span. Plain immutable data so it crosses compute() untouched.
class ZAxisSpec {
  final double lo;
  final double hi;
  final double step;

  /// Unit symbol for the axis title ('°C', 'psi', 'm/min', '' for ppO2).
  final String symbol;

  const ZAxisSpec({
    required this.lo,
    required this.hi,
    required this.step,
    required this.symbol,
  });

  /// Snaps [min]..[max] outward to a nice step that yields about
  /// [targetTicks] ticks. A flat series (min == max) is widened by a
  /// tenth of its magnitude (or 1.0 at zero) so the band is never empty.
  factory ZAxisSpec.fromRange({
    required double min,
    required double max,
    required String symbol,
    int targetTicks = 5,
  }) {
    var span = max - min;
    if (span <= 0) span = max.abs() > 0 ? max.abs() * 0.1 : 1.0;
    final step = niceStep(span / (targetTicks - 1));
    final lo = (min / step).floor() * step;
    var hi = (max / step).ceil() * step;
    if (hi <= lo) hi = lo + step;
    return ZAxisSpec(lo: lo, hi: hi, step: step, symbol: symbol);
  }

  /// Scene Z for a display-unit value; larger values toward the viewer.
  double zOf(double value) {
    if (hi <= lo) return 0;
    final t = ((value - lo) / (hi - lo)).clamp(0.0, 1.0);
    return -SceneBounds.zPathHalfSpan + t * 2 * SceneBounds.zPathHalfSpan;
  }

  /// Tick values lo..hi inclusive, computed by index so no float drift.
  List<double> get ticks {
    if (step <= 0 || hi <= lo) return [lo];
    final count = ((hi - lo) / step).round();
    return [for (var i = 0; i <= count; i++) lo + i * step];
  }
}

/// Everything the geometry service needs to put a metric on Z: which
/// metric, its axis, and the full-resolution series (display units,
/// parallel to Dive3dSceneData.times, nulls where the computer logged
/// nothing).
class ZAxisInput {
  final SceneMetric metric;
  final ZAxisSpec spec;
  final List<double?> values;

  const ZAxisInput({
    required this.metric,
    required this.spec,
    required this.values,
  });
}
