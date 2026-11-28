import 'package:flutter/material.dart';

/// The ascent-rate right axis's labels, drawn at fixed fractions of the plot
/// height in the right axis gutter (issue #5069).
///
/// fl_chart places side-title ticks at multiples of an interval measured
/// from the surface, so after a both-axes zoom its ticks would fall between
/// the bars' baseline and quarter lines. The bars ([AscentRateBarOverlay])
/// are fixed to the plot rect, so their labels are too: positioned here from
/// the same [insets], while the chart keeps the gutter reserved and empty.
class AscentRateAxisLabels extends StatelessWidget {
  /// Each label with its fraction of the plot height from the top.
  final List<({double fraction, String label})> labels;

  /// Reserved axis gutters around the plot rect (the chart's `_plotInsets`).
  final ({double left, double top, double right, double bottom}) insets;

  final TextStyle? style;

  /// The gap between the plot's right edge and a label, as fl_chart's
  /// [SideTitleWidget] leaves by default.
  static const double gap = 8;

  const AscentRateAxisLabels({
    super.key,
    required this.labels,
    required this.insets,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotHeight = constraints.maxHeight - insets.top - insets.bottom;
          if (plotHeight <= 0) return const SizedBox.shrink();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (:fraction, :label) in labels)
                Positioned(
                  left: constraints.maxWidth - insets.right + gap,
                  top: insets.top + fraction * plotHeight,
                  child: FractionalTranslation(
                    translation: const Offset(0, -0.5),
                    child: Text(
                      label,
                      style: style,
                      maxLines: 1,
                      // A number reads left to right in every locale.
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
