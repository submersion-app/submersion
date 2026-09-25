import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';

/// A number badge and an item's name, one line, the whole slot tappable.
///
/// [pill] draws a rounded background (the wide layout); without it the
/// label is plain text in a column (the phone layout). [alignEnd] pushes the
/// content to the right edge, for labels left of their gear.
class FigureNameLabel extends StatelessWidget {
  const FigureNameLabel({
    super.key,
    required this.number,
    required this.text,
    this.alignEnd = false,
    this.pill = false,
    this.selected = false,
    this.onTap,
    this.semanticsLabel,
  });

  static const double badgeSize = 18;
  static const double _gap = 6;
  static const double _padding = 8;

  final int number;
  final String text;
  final bool alignEnd;
  final bool pill;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  static TextStyle styleOf(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12);

  /// The width the label needs to show [text] in full on one line, at the
  /// diver's text size.
  static double preferredWidth(
    String text,
    TextStyle style,
    TextDirection direction, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = badgeSize + _gap + painter.width + _padding * 2 + 2;
    painter.dispose();
    return width;
  }

  /// Lines of name a label may use: two in a phone column, one in a pill.
  int get maxLines => pill ? 1 : 2;

  /// The row height a label needs for its lines at the diver's text size,
  /// never below the 40 pt tap target.
  static double heightFor(BuildContext context, {required bool pill}) {
    final style = styleOf(context);
    final fontSize = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize ?? 12);
    final lineHeight = fontSize * (style.height ?? 1.34);
    return math.max(40, lineHeight * (pill ? 1 : 2) + 10);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = selected ? figureHighlightFor(scheme) : null;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: _padding, vertical: 3),
      decoration: pill || selected
          ? BoxDecoration(
              color: (highlight ?? figurePillFor(scheme)).fill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FigureNumberBadge(
            number: number,
            size: badgeSize,
            selected: selected,
          ),
          const SizedBox(width: _gap),
          Flexible(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
              style: styleOf(context).copyWith(color: highlight?.onFill),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: content,
        ),
      ),
    );
  }
}
