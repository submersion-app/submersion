import 'dart:typed_data';
import 'dart:ui';

/// Metrics the ribbon can be colored by.
enum SceneMetric {
  depth,
  temperature,
  ascentRate,
  ppO2,
  cns,
  heartRate,
  tankPressure,
}

/// Maps per-sample metric values to per-sample rgb triplets (0..1).
/// Continuous metrics interpolate along a ramp; ascentRate uses the
/// app's discrete green/orange/red safety bands (9 and 12 m/min).
class MetricPalette {
  static const Color _nullColor = Color(0xFF9E9E9E);

  // Cool-to-warm ramp shared by continuous metrics. First stop matches
  // AppColors.chartDepth.
  static const List<Color> _ramp = [
    Color(0xFF0077B6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static Float32List colorsFor(SceneMetric metric, List<double?> values) {
    final out = Float32List(values.length * 3);
    final normalize = _normalizerFor(metric, values);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final color = v == null || !v.isFinite
          ? _nullColor
          : metric == SceneMetric.ascentRate
          ? _ascentBand(v)
          : _lerpRamp(normalize(v));
      final p = i * 3;
      out[p] = color.r;
      out[p + 1] = color.g;
      out[p + 2] = color.b;
    }
    return out;
  }

  static Color _ascentBand(double metersPerMinute) {
    final rate = metersPerMinute.abs();
    if (rate <= 9) return const Color(0xFF4CAF50);
    if (rate <= 12) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  static double Function(double) _normalizerFor(
    SceneMetric metric,
    List<double?> values,
  ) {
    switch (metric) {
      case SceneMetric.ppO2:
        return (v) => _unit(v, 0.2, 1.6);
      case SceneMetric.cns:
        return (v) => _unit(v, 0, 100);
      default:
        final finite = values
            .whereType<double>()
            .where((v) => v.isFinite)
            .toList();
        if (finite.isEmpty) return (_) => 0.5;
        var min = finite.first, max = finite.first;
        for (final v in finite) {
          if (v < min) min = v;
          if (v > max) max = v;
        }
        if (max - min < 1e-9) return (_) => 0.5;
        return (v) => _unit(v, min, max);
    }
  }

  static double _unit(double v, double min, double max) =>
      ((v - min) / (max - min)).clamp(0.0, 1.0);

  static Color _lerpRamp(double t) {
    final scaled = t * (_ramp.length - 1);
    final i = scaled.floor().clamp(0, _ramp.length - 2);
    return Color.lerp(_ramp[i], _ramp[i + 1], scaled - i)!;
  }
}
