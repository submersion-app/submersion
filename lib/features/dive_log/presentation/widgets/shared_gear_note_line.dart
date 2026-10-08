import 'package:flutter/material.dart';

/// "Also on Anna's dive, 10:02" under a gear row while editing a dive: the
/// item is also on another profile's overlapping dive (issue #2853). A note,
/// not an error: pooled gear can legitimately be on two divers at once.
class SharedGearNoteLine extends StatelessWidget {
  const SharedGearNoteLine(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color =
        style?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
