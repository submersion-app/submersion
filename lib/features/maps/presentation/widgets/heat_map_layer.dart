import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_shader_provider.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_density.dart';

/// A flutter_map layer that displays a density-colorized heat map.
///
/// Two passes: (1) accumulate every point as a soft radial alpha blob with
/// additive blending into an offscreen density image; (2) a fragment shader
/// maps the accumulated density through a blue->red palette. Renders nothing
/// until the shader program has loaded (or if loading fails).
class HeatMapLayer extends ConsumerStatefulWidget {
  /// The points to render on the heat map.
  final List<HeatMapPoint> points;

  /// Cloud radius in logical pixels (uniform for every point).
  final double radius;

  /// Overall opacity of the heat map (0.0 to 1.0).
  final double opacity;

  const HeatMapLayer({
    super.key,
    required this.points,
    this.radius = 60.0,
    this.opacity = 0.7,
  });

  @override
  ConsumerState<HeatMapLayer> createState() => _HeatMapLayerState();
}

class _HeatMapLayerState extends ConsumerState<HeatMapLayer> {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return const SizedBox.shrink();

    return ref
        .watch(heatMapShaderProgramProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) {
            debugPrint('HeatMapLayer: shader failed to load: $error');
            return const SizedBox.shrink();
          },
          data: (program) {
            // Lazily create (and cache) one shader instance per loaded program.
            if (!identical(program, _program)) {
              _shader?.dispose();
              _shader = program.fragmentShader();
              _program = program;
            }
            return ExcludeSemantics(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _HeatMapPainter(
                        points: widget.points,
                        radius: widget.radius,
                        opacity: widget.opacity,
                        shader: _shader!,
                        camera: MapCamera.of(context),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
  }
}

/// Two-pass density heat-map painter.
class _HeatMapPainter extends CustomPainter {
  final List<HeatMapPoint> points;
  final double radius;
  final double opacity;
  final ui.FragmentShader shader;
  final MapCamera camera;

  /// Density value at which the shader's alpha reaches full opacity. Set near
  /// the per-point intensity floor so an isolated site renders as a smooth
  /// dome (gradual alpha across its whole radius) rather than a flat disk.
  static const double _edgeSoftness = 0.35;

  _HeatMapPainter({
    required this.points,
    required this.radius,
    required this.opacity,
    required this.shader,
    required this.camera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;

    final maxWeight = points.fold<double>(
      0.0,
      (m, p) => p.weight > m ? p.weight : m,
    );
    if (maxWeight <= 0) return;

    // Pass 1: accumulate density into an offscreen image.
    final densityImage = _buildDensityImage(size, maxWeight);

    // Pass 2: colorize the density field via the fragment shader.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, opacity)
      ..setFloat(3, _edgeSoftness)
      ..setImageSampler(0, densityImage);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);

    // Safe to dispose now: the shader retains a native reference to the bound
    // sampler image until the next setImageSampler call. Mirrors the existing
    // drawImage+dispose pattern previously used here.
    densityImage.dispose();
  }

  ui.Image _buildDensityImage(Size size, double maxWeight) {
    final recorder = ui.PictureRecorder();
    final bufferCanvas = Canvas(recorder);

    for (final point in points) {
      final screen = camera.latLngToScreenOffset(point.location);
      if (!isPointVisible(screen, size, radius)) continue;

      final intensity = densityIntensity(point.weight, maxWeight);
      if (intensity <= 0) continue;

      final blob = densityBlobGradient(intensity);
      final gradient = RadialGradient(
        colors: blob.colors,
        stops: blob.stops,
      ).createShader(Rect.fromCircle(center: screen, radius: radius));

      bufferCanvas.drawCircle(
        screen,
        radius,
        Paint()
          ..shader = gradient
          ..blendMode = BlendMode.plus,
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
    picture.dispose();
    return image;
  }

  @override
  bool shouldRepaint(covariant _HeatMapPainter oldDelegate) {
    return points != oldDelegate.points ||
        radius != oldDelegate.radius ||
        opacity != oldDelegate.opacity ||
        shader != oldDelegate.shader ||
        camera != oldDelegate.camera;
  }
}
