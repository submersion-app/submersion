import 'package:flutter/material.dart';

/// A dive not yet done (issue #3565): the main menu's diver
/// ([Icons.scuba_diving]) filled white and outlined in [color].
///
/// Material has no outlined diver ([Icons.scuba_diving_outlined] is the same
/// solid figure), so the glyph is painted twice: once filled, once stroked
/// over it. Sized by the ambient [IconTheme] like an [Icon], and decorative:
/// the chip around it carries the label.
class PlannedDiveIcon extends StatelessWidget {
  const PlannedDiveIcon({super.key, this.size, this.color});

  /// Defaults to the ambient [IconTheme] size.
  final double? size;

  /// The outline colour; defaults to the theme's primary colour.
  final Color? color;

  static const _icon = Icons.scuba_diving;

  @override
  Widget build(BuildContext context) {
    final size = this.size ?? IconTheme.of(context).size ?? 24;
    final outline = color ?? Theme.of(context).colorScheme.primary;
    final style = TextStyle(
      inherit: false,
      fontFamily: _icon.fontFamily,
      package: _icon.fontPackage,
      fontSize: size,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final glyph = String.fromCharCode(_icon.codePoint);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(glyph, style: style.copyWith(color: Colors.white)),
            Text(
              glyph,
              style: style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size / 16
                  ..strokeJoin = StrokeJoin.round
                  ..color = outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
