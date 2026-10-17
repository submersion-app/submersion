import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/scenes/scene_dash.dart';
import 'package:submersion/shared/widgets/scenes/scene_painter.dart';

/// The two palettes of the paper chart scene.
class ChartPalette {
  const ChartPalette({
    required this.paper,
    required this.land,
    required this.ink,
    required this.line,
    required this.landLine,
    required this.sounding,
    required this.mark,
    required this.markLabel,
    required this.sweep,
    required this.course,
    required this.headScrim,
  });

  final Color paper;
  final Color land;

  /// The colour the scene's facts are set in.
  final Color ink;

  /// Contours and the compass rose.
  final Color line;
  final Color landLine;
  final Color sounding;

  /// Mark dots and halos, and their labels.
  final Color mark;
  final Color markLabel;

  /// The band of light that sweeps across the sheet.
  final Color sweep;

  /// The passage's dashed course.
  final Color course;

  /// Opacity of a paper wash behind the headline band, so the compass and
  /// contours fade under the type; zero for none.
  final double headScrim;

  static const light = ChartPalette(
    paper: Color(0xFFEFE7D2),
    land: Color(0xFFE4DABD),
    ink: Color(0xFF3B3324),
    line: Color(0x8C463C28),
    landLine: Color(0x80463C28),
    sounding: Color(0x8C3C321E),
    mark: Color(0xFF2A8AA6),
    markLabel: Color(0xFF1D5D70),
    sweep: Color(0x59FFFFFF),
    course: Color(0xCCB7352B),
    headScrim: 0.55,
  );

  static const dark = ChartPalette(
    paper: Color(0xFF121C26),
    land: Color(0xFF1C2A36),
    ink: Color(0xFFD9E2EA),
    line: Color(0x66BED2E1),
    landLine: Color(0x59BED2E1),
    sounding: Color(0x8CC8D7E4),
    mark: Color(0xFF7FD3EA),
    markLabel: Color(0xFFBFE8F3),
    sweep: Color(0x1FA0C8E6),
    course: Color(0xCCF08A7A),
    headScrim: 0.5,
  );

  static ChartPalette of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  /// A soft paper halo around the scene's type, so it stays legible where it
  /// crosses a contour or a sounding. The same list instance every time, so
  /// a scene's ink is identical between builds.
  List<Shadow> get inkShadows =>
      identical(this, light) ? _lightInkShadows : _darkInkShadows;

  static final _lightInkShadows = [
    Shadow(color: light.paper.withValues(alpha: 0.9), blurRadius: 6),
  ];

  static final _darkInkShadows = [
    Shadow(color: dark.paper.withValues(alpha: 0.9), blurRadius: 6),
  ];
}

/// The paper chart: a coastline on the end side with its land, three dashed
/// depth contours, soundings, a compass rose, and a band of light sweeping
/// across. The sheet drifts and breathes slowly; it is a drawing, not a map.
class ChartPainter extends ScenePainter {
  ChartPainter({required super.seconds, required super.brightness});

  /// The sheet is drawn in the mockup's 1000 x 690 viewBox.
  static const Size sheet = Size(1000, 690);

  static const List<(String, Offset)> _soundings = [
    ('12', Offset(120, 330)),
    ('18', Offset(250, 420)),
    ('27', Offset(380, 300)),
    ('9', Offset(200, 560)),
    ('33', Offset(430, 500)),
    ('21', Offset(320, 620)),
    ('24', Offset(470, 380)),
    ('14', Offset(90, 470)),
  ];

  static const Offset _compass = Offset(130, 150);

  static const _serif = TextStyle(
    fontFamily: 'Iowan Old Style',
    fontFamilyFallback: [
      'Palatino',
      'Georgia',
      'Noto Serif',
      'DejaVu Serif',
      'serif',
    ],
  );

  /// The coast's sea edge, a smooth curve from the top to the bottom.
  static final Path _coast = Path()
    ..moveTo(690, 0)
    ..cubicTo(640, 90, 730, 180, 660, 260)
    ..cubicTo(590, 340, 720, 420, 640, 520)
    ..cubicTo(560, 620, 700, 640, 660, 690);

  static final Path _land = Path.from(_coast)
    ..lineTo(1000, 690)
    ..lineTo(1000, 0)
    ..close();

  static final List<Path> _contours = [
    for (final step in [50.0, 100.0, 150.0])
      dashedPath(_coast.shift(Offset(-step, 0)), dash: 3, gap: 4),
  ];

  static final Path _compassCross = Path()
    ..moveTo(0, -58)
    ..lineTo(0, 58)
    ..moveTo(-58, 0)
    ..lineTo(58, 0);

  /// Laid-out soundings and the compass's "N", per brightness: their layout
  /// does not depend on the pane size, so it is done once.
  static final Map<Brightness, List<(TextPainter, Offset)>> _labels = {};

  static List<(TextPainter, Offset)> _labelsFor(Brightness b) =>
      _labels.putIfAbsent(b, () {
        final palette = ChartPalette.of(b);
        TextPainter lay(String text, double size) => TextPainter(
          text: TextSpan(
            text: text,
            style: _serif.copyWith(fontSize: size, color: palette.sounding),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final north = lay('N', 12);
        return [
          for (final (text, at) in _soundings)
            // SVG places text by its baseline; lift each label to match.
            (lay(text, 11), at.translate(0, -9)),
          (north, _compass.translate(-north.width / 2, -66 - 11)),
        ];
      });

  @override
  void paint(Canvas canvas, Size size) {
    final palette = ChartPalette.of(brightness);
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = palette.paper);
    canvas.save();
    canvas.clipRect(rect);
    _paintSheet(canvas, size, palette);
    _paintHeadScrim(canvas, rect, palette);
    _paintSweep(canvas, size, palette);
    canvas.restore();
  }

  void _paintSheet(Canvas canvas, Size size, ChartPalette palette) {
    // Eased back and forth over 70 s each way.
    final p = (1 - math.cos(math.pi * seconds / 70)) / 2;
    final fit = math.max(size.width / sheet.width, size.height / sheet.height);
    // Never below 1.02, so the drift never shows the sheet's edge.
    final scale = fit * (1.02 + 0.02 * p);
    canvas.save();
    canvas.translate(
      size.width / 2 + _lerp(-0.012, 0.012, p) * size.width,
      size.height / 2 + _lerp(-0.006, 0.008, p) * size.height,
    );
    canvas.scale(scale);
    canvas.translate(-sheet.width / 2, -sheet.height / 2);

    final hairline = 1 / scale;
    canvas.drawPath(_land, Paint()..color = palette.land);
    canvas.drawPath(
      _land,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hairline
        ..color = palette.landLine,
    );
    final contour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * hairline
      ..color = palette.line.withValues(alpha: palette.line.a * 0.8);
    for (final path in _contours) {
      canvas.drawPath(path, contour);
    }
    for (final (label, at) in _labelsFor(brightness)) {
      label.paint(canvas, at);
    }
    final rose = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hairline
      ..color = palette.line;
    canvas.save();
    canvas.translate(_compass.dx, _compass.dy);
    canvas.drawCircle(Offset.zero, 46, rose);
    canvas.drawCircle(Offset.zero, 30, rose);
    canvas.drawPath(_compassCross, rose);
    canvas.restore();
    canvas.restore();
  }

  void _paintHeadScrim(Canvas canvas, Rect rect, ChartPalette palette) {
    if (palette.headScrim <= 0) return;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.paper.withValues(alpha: palette.headScrim),
            palette.paper.withValues(alpha: palette.headScrim * 0.9),
            palette.paper.withValues(alpha: 0),
          ],
          stops: const [0, 0.26, 0.46],
        ).createShader(rect),
    );
  }

  void _paintSweep(Canvas canvas, Size size, ChartPalette palette) {
    final travel = (seconds % 42) / 42;
    final band = Rect.fromLTWH(
      _lerp(-0.30, 1.20, travel) * size.width,
      -0.2 * size.height,
      0.26 * size.width,
      1.4 * size.height,
    );
    canvas.save();
    canvas.translate(band.center.dx, band.center.dy);
    canvas.rotate(18 * math.pi / 180);
    canvas.translate(-band.center.dx, -band.center.dy);
    canvas.drawRect(
      band,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..shader = LinearGradient(
          colors: [
            palette.sweep.withValues(alpha: 0),
            palette.sweep,
            palette.sweep.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
    canvas.restore();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
