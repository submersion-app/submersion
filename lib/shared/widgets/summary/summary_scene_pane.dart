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
    required this.child,
  });

  /// Builds the scene's painter for a clock value and theme brightness.
  final CustomPainter Function(double seconds, Brightness brightness)
  painterBuilder;

  /// The colour the facts are set in.
  final Color ink;

  /// The facts, usually a Stack of positioned text.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: SceneClock(
                  builder: (context, seconds) =>
                      CustomPaint(painter: painterBuilder(seconds, brightness)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SceneInk(color: ink, child: child),
          ),
        ],
      ),
    );
  }
}
