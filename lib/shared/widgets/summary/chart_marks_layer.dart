import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/scenes/chart_marks_painter.dart';
import 'package:submersion/shared/widgets/scenes/chart_painter.dart';
import 'package:submersion/shared/widgets/scenes/scene_clock.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';

/// One mark on the chart: where it sits and what its label says.
class ChartMark {
  const ChartMark({
    required this.spot,
    required this.label,
    this.compactLabel,
    this.onTap,
    this.semanticsLabel,
  });

  final ChartSpot spot;
  final String label;

  /// The shorter label a narrow pane shows; [label] when null.
  final String? compactLabel;

  /// Opens what the mark stands for; null for a plain label.
  final VoidCallback? onTap;

  /// What a screen reader says for the link; [label] when null.
  final String? semanticsLabel;
}

/// The chart's marks: dots and halos painted off the pane clock, with a
/// label beside each one.
///
/// Marks belong to the picture, so they keep their physical positions in a
/// right-to-left locale; only the text inside a label follows the locale.
class ChartMarksLayer extends StatelessWidget {
  const ChartMarksLayer({
    super.key,
    required this.marks,
    this.course = false,
    this.compact = false,
  });

  final List<ChartMark> marks;

  /// Draws the passage's dashed course through the marks, in order.
  final bool course;

  /// Shows each mark's compact label.
  final bool compact;

  /// Past this fraction of the width a label goes on the dot's start side.
  static const double flipAt = 0.6;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final palette = ChartPalette.of(brightness);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final inset = w * 0.075;
        return Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ChartMarksPainter(
                      time: SceneTime.of(context),
                      brightness: brightness,
                      spots: [for (final mark in marks) mark.spot],
                      course: course,
                    ),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < marks.length; i++)
              _label(context, i, marks[i], w, h, inset, palette),
          ],
        );
      },
    );
  }

  Widget _label(
    BuildContext context,
    int index,
    ChartMark mark,
    double w,
    double h,
    double inset,
    ChartPalette palette,
  ) {
    final x = mark.spot.at.dx * w;
    final y = mark.spot.at.dy * h;
    final endSide = mark.spot.at.dx <= flipAt;
    final text = compact ? (mark.compactLabel ?? mark.label) : mark.label;
    final onTap = mark.onTap;
    // Physical, like the dot: a wrapped label's lines hug the dot side in
    // either reading direction.
    final align = endSide ? TextAlign.left : TextAlign.right;
    // Marks can sit a line or two apart on a short pane; the full label is
    // still read out through the link's semantics.
    final maxLines = compact ? 1 : 2;
    return Positioned(
      key: ValueKey('chart-mark-$index'),
      top: y - 9,
      left: endSide ? x + 12 : inset,
      right: endSide ? inset : w - x + 12,
      child: Align(
        alignment: endSide ? Alignment.topLeft : Alignment.topRight,
        child: SceneInk(
          color: palette.markLabel,
          shadows: SceneInk.shadowsOf(context),
          child: onTap == null
              ? SceneLabel(text, textAlign: align, maxLines: maxLines)
              : SceneLink(
                  text: text,
                  onTap: onTap,
                  semanticsLabel: mark.semanticsLabel ?? mark.label,
                  textAlign: align,
                  maxLines: maxLines,
                ),
        ),
      ),
    );
  }
}
