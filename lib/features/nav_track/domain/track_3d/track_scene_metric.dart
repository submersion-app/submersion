import 'dart:typed_data';
import 'dart:ui';

/// Metrics an underwater track's 3D ribbon can be colored by.
///
/// A parallel enum to `dive_3d`'s `SceneMetric` rather than an extension
/// of it: that enum's exhaustive switches live across several dive-only
/// files, and a track has none of `ascentRate`/`ppO2`/`cns`/
/// `tankPressure`/`tts` -- adding four dead cases to every one of those
/// switches would be the wrong trade for reusing one enum.
enum TrackSceneMetric { depth, temperature, speed, batteryVoltage }

/// Maps per-sample [TrackSceneMetric] values to per-sample rgb triplets
/// (0..1). A smaller sibling of `dive_3d`'s `MetricPalette`: every track
/// metric is continuous (no `ascentRate`-style discrete safety bands, no
/// `ppO2`/`cns`-style fixed physiological range), so this only needs the
/// one normalize-and-lerp path. The ramp colors are duplicated rather
/// than imported from `MetricPalette`'s private `_ramp`, to keep the same
/// visual language between the dive and track 3D scenes without reaching
/// into `dive_3d`'s internals.
class TrackMetricPalette {
  static const Color _nullColor = Color(0xFF9E9E9E);

  static const List<Color> _ramp = [
    Color(0xFF0077B6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static Float32List colorsFor(List<double?> values) {
    final out = Float32List(values.length * 3);
    final normalize = _normalizer(values);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final color = v == null || !v.isFinite
          ? _nullColor
          : _lerpRamp(normalize(v));
      final p = i * 3;
      out[p] = color.r;
      out[p + 1] = color.g;
      out[p + 2] = color.b;
    }
    return out;
  }

  static double Function(double) _normalizer(List<double?> values) {
    final finite = values.whereType<double>().where((v) => v.isFinite).toList();
    if (finite.isEmpty) return (_) => 0.5;
    var min = finite.first, max = finite.first;
    for (final v in finite) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    if (max - min < 1e-9) return (_) => 0.5;
    return (v) => ((v - min) / (max - min)).clamp(0.0, 1.0);
  }

  static Color _lerpRamp(double t) {
    final scaled = t * (_ramp.length - 1);
    final i = scaled.floor().clamp(0, _ramp.length - 2);
    return Color.lerp(_ramp[i], _ramp[i + 1], scaled - i)!;
  }
}
