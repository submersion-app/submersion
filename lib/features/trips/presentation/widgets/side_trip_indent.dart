import 'package:flutter/material.dart';

/// How far [SideTripIndent] moves a side trip's row: the gutter and its
/// arrow. Anything drawn over the row, such as its upcoming banner, moves as
/// far.
const double sideTripIndentWidth = _gutter + _arrowSize;

const double _gutter = 16;
const double _arrowSize = 18;

/// Indents a side trip's row under its larger trip in the trip list, with a
/// branch arrow in the gutter (issue #3658). The row keeps its own width
/// behaviour; only its left edge moves.
class SideTripIndent extends StatelessWidget {
  const SideTripIndent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _gutter),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.subdirectory_arrow_right,
              size: _arrowSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
