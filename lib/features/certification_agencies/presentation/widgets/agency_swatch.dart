import 'package:flutter/material.dart';

/// A rounded gradient chip in an agency's card colours (issue #690).
class AgencySwatch extends StatelessWidget {
  const AgencySwatch({
    super.key,
    required this.primary,
    required this.secondary,
    this.size = 28,
    this.selected = false,
  });

  final Color primary;
  final Color secondary;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, secondary],
        ),
        border: Border.all(
          color: selected ? scheme.onSurface : scheme.outlineVariant,
          width: selected ? 3 : 1,
        ),
      ),
    );
  }
}
