import 'package:flutter/material.dart';

/// A row of form fields that wraps by width (issue #4962): as many equal
/// columns per line as fit at [minFieldWidth] each, and a field that does
/// not fit moves to the next line at the same column width, so O2 and He
/// share a line on a phone with N2 below O2.
///
/// [minFieldWidth] grows with the text scale, since the fields hold text.
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

  @override
  Widget build(BuildContext context) {
    final minWidth = MediaQuery.textScalerOf(context).scale(minFieldWidth);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          width: constraints.maxWidth,
          count: slots ?? children.length,
          minFieldWidth: minWidth,
          spacing: spacing,
        );
        final lines = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          if (lines.isNotEmpty) lines.add(SizedBox(height: runSpacing));
          lines.add(_line(children.skip(start).take(columns), columns));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: lines,
        );
      },
    );
  }

  /// One line of [columns] equal cells, the cells past [fields] left empty
  /// so the fields keep the column width.
  Widget _line(Iterable<Widget> fields, int columns) {
    final cells = [
      for (final field in fields) Expanded(child: field),
      for (var i = fields.length; i < columns; i++) const Spacer(),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          cells[i],
        ],
      ],
    );
  }
}
