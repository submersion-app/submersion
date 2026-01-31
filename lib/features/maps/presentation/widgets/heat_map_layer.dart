import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';

/// A flutter_map layer that displays a heat map visualization.
///
/// Renders weighted points as overlapping radial gradients that blend together
/// using additive blending. Higher weight points appear more intense and
/// slightly larger.
class HeatMapLayer extends StatelessWidget {
  /// The points to render on the heat map.
  final List<HeatMapPoint> points;

  /// Base radius for heat map points in pixels.
  final double radius;

  /// Overall opacity of the heat map (0.0 to 1.0).
  final double opacity;

  /// Custom color gradient from low to high intensity.
  /// If null, uses a default blue-cyan-green-yellow-orange-red gradient.
  final List<Color>? gradient;

  const HeatMapLayer({
    super.key,
    required this.points,
    this.radius = 30.0,
    this.opacity = 0.6,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _HeatMapPainter(
            points: points,
            radius: radius,
            opacity: opacity,
            gradient: gradient ?? _defaultGradient,
            camera: MapCamera.of(context),
          ),
        );
      },
    );
  }

  static const List<Color> _defaultGradient = [
    Color(0xFF3B82F6), // Blue (low)
    Color(0xFF06B6D4), // Cyan
    Color(0xFF22C55E), // Green
    Color(0xFFEAB308), // Yellow
    Color(0xFFF97316), // Orange
    Color(0xFFEF4444), // Red (high)
  ];
}

/// Custom painter that renders the heat map visualization.
class _HeatMapPainter extends CustomPainter {
  final List<HeatMapPoint> points;
  final double radius;
  final double opacity;
  final List<Color> gradient;
  final MapCamera camera;

  _HeatMapPainter({
    required this.points,
    required this.radius,
    required this.opacity,
    required this.gradient,
    required this.camera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Find max weight for normalization
    final maxWeight = points.map((p) => p.weight).reduce(math.max);
    if (maxWeight <= 0) return;

    // Create an offscreen buffer for additive blending
    final recorder = ui.PictureRecorder();
    final bufferCanvas = Canvas(recorder);

    // Draw each point as a radial gradient
    for (final point in points) {
      // Convert lat/lng to screen position
      final screenPoint = camera.latLngToScreenOffset(point.location);

      // Skip points outside the visible area (with padding)
      if (screenPoint.dx < -radius ||
          screenPoint.dx > size.width + radius ||
          screenPoint.dy < -radius ||
          screenPoint.dy > size.height + radius) {
        continue;
      }

      final normalizedWeight = point.weight / maxWeight;
      final pointRadius = radius * (0.5 + normalizedWeight * 0.5);

      // Create radial gradient for this point
      final color = _getColorForWeight(normalizedWeight);
      final gradientShader =
          RadialGradient(
            colors: [
              color.withValues(alpha: opacity * normalizedWeight),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(screenPoint.dx, screenPoint.dy),
              radius: pointRadius,
            ),
          );

      final paint = Paint()
        ..shader = gradientShader
        ..blendMode = BlendMode.plus;

      bufferCanvas.drawCircle(
        Offset(screenPoint.dx, screenPoint.dy),
        pointRadius,
        paint,
      );
    }

    // Draw the buffer to the main canvas
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.width.ceil(), size.height.ceil());

    canvas.drawImage(image, Offset.zero, Paint());
    image.dispose();
  }

  /// Maps a normalized weight (0.0 to 1.0) to a color from the gradient.
  Color _getColorForWeight(double normalizedWeight) {
    if (gradient.isEmpty) return Colors.red;
    if (gradient.length == 1) return gradient.first;

    // Map weight to gradient position
    final position = normalizedWeight * (gradient.length - 1);
    final lowerIndex = position.floor().clamp(0, gradient.length - 2);
    final upperIndex = (lowerIndex + 1).clamp(0, gradient.length - 1);
    final t = position - lowerIndex;

    return Color.lerp(gradient[lowerIndex], gradient[upperIndex], t)!;
  }

  @override
  bool shouldRepaint(covariant _HeatMapPainter oldDelegate) {
    return points != oldDelegate.points ||
        radius != oldDelegate.radius ||
        opacity != oldDelegate.opacity ||
        camera != oldDelegate.camera;
  }
}
