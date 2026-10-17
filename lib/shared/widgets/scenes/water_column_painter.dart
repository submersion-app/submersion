import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/scenes/scene_painter.dart';

/// The two palettes of the water column scene.
class WaterColumnPalette {
  const WaterColumnPalette({
    required this.surface,
    required this.mid,
    required this.deep,
    required this.rayOpacity,
    required this.snowOpacity,
    required this.foamOpacity,
    required this.snow,
  });

  final Color surface;
  final Color mid;
  final Color deep;
  final double rayOpacity;
  final double snowOpacity;
  final double foamOpacity;
  final Color snow;

  static const light = WaterColumnPalette(
    surface: Color(0xFFA9E6EF),
    mid: Color(0xFF3EA3C6),
    deep: Color(0xFF0C3F70),
    rayOpacity: 0.50,
    snowOpacity: 0.85,
    foamOpacity: 0.42,
    snow: Color(0xFFFFFFFF),
  );

  static const dark = WaterColumnPalette(
    surface: Color(0xFF1B6D8D),
    mid: Color(0xFF0D3A60),
    deep: Color(0xFF030B1B),
    rayOpacity: 0.26,
    snowOpacity: 0.75,
    foamOpacity: 0.16,
    snow: Color(0xFFD2EBF5),
  );

  static WaterColumnPalette of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;
}

/// One sinking particle of marine snow, in pane fractions.
class _Snow {
  const _Snow(this.x, this.y0, this.radius, this.speed, this.phase, this.alpha);

  final double x;
  final double y0;
  final double radius;
  final double speed;
  final double phase;
  final double alpha;
}

/// One swaying light ray: left edge and width as pane fractions, base
/// rotation in degrees, sway period in seconds, peak opacity factor.
class _Ray {
  const _Ray(this.left, this.width, this.degrees, this.period, this.peak);

  final double left;
  final double width;
  final double degrees;
  final double period;
  final double peak;
}

/// The water column: a surface-to-abyss gradient, swaying light rays,
/// sinking marine snow and a rippling surface along the top edge.
class WaterColumnPainter extends ScenePainter {
  WaterColumnPainter({
    required super.seconds,
    required super.brightness,
    this.seed = 7,
  });

  final int seed;

  static const int snowCount = 90;

  static const _rays = [
    _Ray(0.22, 0.16, -16, 18, 1.0),
    _Ray(0.46, 0.10, -11, 22, 0.7),
    _Ray(0.68, 0.20, -19, 26, 0.6),
  ];

  /// Particles depend only on the seed, so they are generated once per seed
  /// and shared by every frame.
  static final Map<int, List<_Snow>> _snowBySeed = {};

  static List<_Snow> _snowFor(int seed) => _snowBySeed.putIfAbsent(seed, () {
    final random = math.Random(seed);
    return List.generate(snowCount, (_) {
      return _Snow(
        random.nextDouble(),
        random.nextDouble(),
        0.5 + random.nextDouble() * 1.3,
        0.0028 + random.nextDouble() * 0.0063,
        random.nextDouble() * 2 * math.pi,
        0.18 + random.nextDouble() * 0.4,
      );
    }, growable: false);
  });

  @override
  void paint(Canvas canvas, Size size) {
    final palette = WaterColumnPalette.of(brightness);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.surface, palette.mid, palette.deep],
          stops: const [0, 0.48, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRect(rect);
    _paintRays(canvas, size, palette);
    _paintSnow(canvas, size, palette);
    _paintFoam(canvas, size, palette);
    canvas.restore();
  }

  /// Eased back-and-forth in [-1, 1] over [period] seconds.
  double _swing(double period, double offset) =>
      math.sin((seconds + offset) / period * 2 * math.pi);

  void _paintRays(Canvas canvas, Size size, WaterColumnPalette palette) {
    for (var i = 0; i < _rays.length; i++) {
      final ray = _rays[i];
      final swing = _swing(ray.period, i * 5.0);
      final width = ray.width * size.width;
      final height = size.height * 1.3;
      final topCentre = Offset(
        ray.left * size.width + width / 2 + swing * 6,
        -size.height * 0.12,
      );
      final opacity =
          palette.rayOpacity * ray.peak * (0.55 + 0.45 * (swing + 1) / 2);
      final shape = Rect.fromLTWH(-width / 2, 0, width, height);
      canvas.save();
      canvas.translate(topCentre.dx, topCentre.dy);
      canvas.rotate((ray.degrees + swing * 2.5) * math.pi / 180);
      canvas.drawRect(
        shape,
        Paint()
          ..blendMode = BlendMode.screen
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.72],
          ).createShader(shape),
      );
      canvas.restore();
    }
  }

  void _paintSnow(Canvas canvas, Size size, WaterColumnPalette palette) {
    final paint = Paint();
    for (final flake in _snowFor(seed)) {
      final y = (flake.y0 + flake.speed * seconds) % 1.1 - 0.05;
      final x = flake.x + math.sin(seconds * 0.4 + flake.phase) * 0.004;
      paint.color = palette.snow.withValues(
        alpha: flake.alpha * palette.snowOpacity,
      );
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        flake.radius,
        paint,
      );
    }
  }

  void _paintFoam(Canvas canvas, Size size, WaterColumnPalette palette) {
    const band = 34.0;
    final wavelength = size.width / 2;
    for (final (period, direction, alpha) in [
      (26.0, 1.0, 1.0),
      (46.0, -1.0, 0.5),
    ]) {
      final shift = direction * (seconds / period % 1) * wavelength;
      final path = Path()..moveTo(0, 0);
      for (var x = 0.0; x <= size.width; x += 8) {
        final y =
            band / 2 +
            math.sin((x + shift) / wavelength * 2 * math.pi) * band / 4 -
            8;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: palette.foamOpacity * alpha),
      );
    }
  }
}
