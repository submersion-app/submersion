import 'package:flutter/material.dart';

/// A kind's colour as a filled circle: the legend's swatch, and the marker
/// beside a node's name in the Details tab.
class KindDot extends StatelessWidget {
  const KindDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
