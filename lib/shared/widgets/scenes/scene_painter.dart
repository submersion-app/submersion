import 'package:flutter/widgets.dart';

/// Base for every summary-pane scene painter.
///
/// A scene is a pure function of the clock ([seconds]) and the theme
/// [brightness]: painting the same values twice draws the same picture,
/// which is what lets tests pin a frame and lets the scene clock freeze one.
abstract class ScenePainter extends CustomPainter {
  const ScenePainter({required this.seconds, required this.brightness});

  /// Elapsed scene time, from `SceneClock`.
  final double seconds;

  /// Which of the scene's two palettes to paint.
  final Brightness brightness;

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) =>
      oldDelegate.seconds != seconds || oldDelegate.brightness != brightness;
}
