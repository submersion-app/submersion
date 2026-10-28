import 'package:flutter/material.dart';

/// Indents a side trip's row under its larger trip in the trip list, with a
/// branch arrow in the gutter (issue #3658). The row keeps its own width
/// behaviour; only its left edge moves.
class SideTripIndent extends StatelessWidget {
  const SideTripIndent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.subdirectory_arrow_right,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
