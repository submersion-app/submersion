import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/scenes/scene_clock.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';

/// A summary pane drawn as a scene: a slowly moving picture filling the
/// pane, with the page's facts laid over it.
///
/// The picture is decoration and is excluded from semantics; the facts in
/// [child] are ordinary widgets, read in order and set in [ink].
class SummaryScenePane extends StatelessWidget {
  const SummaryScenePane({
    super.key,
    required this.painterBuilder,
    required this.ink,
    this.shadows,
    required this.child,
  });

  /// Builds the scene's painter for a clock value and theme brightness.
  final CustomPainter Function(double seconds, Brightness brightness)
  painterBuilder;

  /// The colour the facts are set in.
  final Color ink;

  /// Optional text shadows for the facts, for a scene with bright areas.
  final List<Shadow>? shadows;

  /// The facts, usually a Stack of positioned text.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // Built once, outside the clock: the clock's builder hands back this
    // same instance every frame, so the facts never rebuild, yet they sit
    // under the clock and can reach it through SceneTime.
    final facts = Positioned.fill(
      child: SceneInk(color: ink, shadows: shadows, child: child),
    );
    return SizedBox.expand(
      child: SceneClock(
        builder: (context, seconds) => Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: painterBuilder(seconds, brightness),
                  ),
                ),
              ),
            ),
            facts,
          ],
        ),
      ),
    );
  }
}
