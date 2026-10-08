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

  /// The digits' style for a badge of [size].
  static TextStyle digitStyle(double size, Color color) => TextStyle(
    color: color,
    fontSize: size * 0.5,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  /// The width a badge of [size] takes for [number] at [textScaler]: its
  /// size for one or two digits, wider when the digits need it.
  static double widthFor(
    int number,
    double size, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: digitStyle(size, const Color(0xFF000000)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width + size * 0.4;
    painter.dispose();
    return width < size ? size : width;
  }

  @override
  Widget build(BuildContext context) {
    final palette = figurePaletteFor(Theme.of(context).colorScheme);
    final fill = Color(palette.badge);
    final digit = Color(palette.onBadge);
    // A circle for one or two digits; a longer number stretches it into a
    // pill rather than clipping the digits.
    final circle = Container(
      width: widthFor(
        number,
        size,
        textScaler: MediaQuery.textScalerOf(context),
      ),
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        color: fill,
        border: Border.all(color: digit, width: selected ? 2.5 : 1),
      ),
      child: Text(
        '$number',
        maxLines: 1,
        softWrap: false,
        style: digitStyle(size, digit),
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
