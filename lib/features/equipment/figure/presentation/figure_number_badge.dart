import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';

/// The number badge, at the head of a figure label and of a legend row.
///
/// Always drawn with a ring in the digit colour, so the badge keeps an edge
/// on a body or a gear colour close to `primary`; selection thickens it.
class FigureNumberBadge extends StatelessWidget {
  const FigureNumberBadge({
    super.key,
    required this.number,
    this.selected = false,
    this.size = 24,
    this.onTap,
    this.semanticsLabel,
  });

  final int number;
  final bool selected;
  final double size;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = figurePaletteFor(Theme.of(context).colorScheme);
    final fill = Color(palette.badge);
    final digit = Color(palette.onBadge);
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: digit, width: selected ? 2.5 : 1),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: digit,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticsLabel != null,
      child: onTap == null
          ? circle
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: circle,
            ),
    );
  }
}
