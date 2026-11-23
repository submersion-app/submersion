import 'package:flutter/material.dart';

/// A row of form fields that wraps by width (issue #4962): as many equal
/// columns per line as fit at [minFieldWidth] each, and a field that does
/// not fit moves to the next line at the same column width, so O2 and He
/// share a line on a phone with N2 below O2.
///
/// [minFieldWidth] grows with the fields' text size ([textGrowth]).
/// [slots] sets the columns for fewer [children] than the row is laid out
/// for, so a lone field lines up with a full row above it.
class TankFieldGrid extends StatelessWidget {
  const TankFieldGrid({
    super.key,
    required this.children,
    this.slots,
    this.spacing = 12,
    this.runSpacing = 12,
    this.minFieldWidth = defaultMinFieldWidth,
  });

  /// Room for a three digit value with its unit ("200 bar") and a floating
  /// label such as "Start pressure" at the default text scale, while a
  /// 360 dp phone still fits two fields to a line.
  static const double defaultMinFieldWidth = 100;

  final List<Widget> children;
  final int? slots;
  final double spacing;
  final double runSpacing;
  final double minFieldWidth;

  /// How many columns of at least [minFieldWidth] fit in [width], from one
  /// up to [count].
  static int columnsFor({
    required double width,
    required int count,
    required double minFieldWidth,
    required double spacing,
  }) {
    if (count <= 1) return 1;
    if (!width.isFinite) return count;
    final fit = ((width + spacing) / (minFieldWidth + spacing)).floor();
    return fit.clamp(1, count);
  }

  /// How much the text size setting grows the fields' own text. Measured on
  /// their font size rather than by scaling [minFieldWidth] as if it were
  /// one: Android 14 and later scale text nonlinearly, growing large sizes
  /// less than small ones, so a 100 "font size" would hardly grow while the
  /// fields' 16 sp text doubled.
  static double textGrowth(BuildContext context) {
    final fontSize = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16;
    return MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
  }

  @override
  Widget build(BuildContext context) {
    final minWidth = minFieldWidth * textGrowth(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          width: constraints.maxWidth,
          count: slots ?? children.length,
          minFieldWidth: minWidth,
          spacing: spacing,
        );
        final width = constraints.maxWidth;
        // One Wrap, not a Row per line: every field keeps its place in one
        // child list, so a field that changes line when the columns change
        // (a rotation, a window resize) keeps its focus and state. Wrap
        // allows for rounding, so exact column widths fill a line.
        final fieldWidth = width.isFinite
            ? (width - spacing * (columns - 1)) / columns
            : null;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: fieldWidth, child: child),
          ],
        );
      },
    );
  }
}
