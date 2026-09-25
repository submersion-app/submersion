import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';

/// A number badge and an item's name, the whole slot tappable.
///
/// [pill] draws a rounded background on one line (the wide layout); without
/// it the label is plain text in a column (the phone layout), which may wrap
/// to two lines. [alignEnd] pushes the content to the right edge, for labels
/// left of their gear.
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
  static const double _pillPadding = 8;

  /// Phone columns are narrow, so their labels keep only enough padding for
  /// the selection flash to show around the text.
  static const double _columnPadding = 4;

  final int number;
  final String text;
  final bool alignEnd;
  final bool pill;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  /// The label type: the theme's small body style in a pill, and a size
  /// smaller with no extra letter spacing in a phone column, where every
  /// character counts.
  static TextStyle styleFor(BuildContext context, {required bool pill}) {
    final base =
        Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    return pill ? base : base.copyWith(fontSize: 11, letterSpacing: 0);
  }

  /// The width a pill needs to show [text] in full on one line, at the
  /// diver's text size.
  static double preferredWidth(
    String text,
    TextStyle style,
    TextDirection direction, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final width = _measure(text, style, direction, textScaler);
    return badgeSize + _gap + width + _pillPadding * 2 + 2;
  }

  /// The row height a label needs for its lines at the diver's text size,
  /// never below the 40 pt tap target.
  static double heightFor(BuildContext context, {required bool pill}) {
    final style = styleFor(context, pill: pill);
    final fontSize = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize ?? 12);
    final lineHeight = fontSize * (style.height ?? 1.34);
    return math.max(40, lineHeight * (pill ? 1 : 2) + 10);
  }

  static double _measure(
    String text,
    TextStyle style,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Two lines in a column, unless one word is wider than a line: wrapping
  /// would then split the word mid-letter, so the name takes one line and
  /// ends in an ellipsis instead.
  int _linesFor(BuildContext context, double lineWidth, TextStyle style) {
    if (pill) return 1;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final longestWord = text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => _measure(word, style, direction, scaler))
        .fold<double>(0, math.max);
    return longestWord > lineWidth ? 1 : 2;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = selected ? figureHighlightFor(scheme) : null;
    final style = styleFor(
      context,
      pill: pill,
    ).copyWith(color: highlight?.onFill);
    final padding = pill ? _pillPadding : _columnPadding;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final badge = FigureNumberBadge(
              number: number,
              size: badgeSize,
              selected: selected,
            );
            // Too narrow for any of the name (a phone column in a very
            // narrow pane): show the number alone, scaled down if even the
            // badge does not fit, rather than overflow the row.
            if (constraints.maxWidth < badgeSize + _gap + padding * 2 + 12) {
              return Align(
                alignment: alignEnd
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: badge),
              );
            }
            final lineWidth = math.max(
              0.0,
              constraints.maxWidth - badgeSize - _gap - padding * 2,
            );
            final lines = _linesFor(context, lineWidth, style);
            return Align(
              alignment: alignEnd
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 3),
                decoration: pill || selected
                    ? BoxDecoration(
                        color: (highlight ?? figurePillFor(scheme)).fill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant,
                          width: 0.5,
                        ),
                      )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    badge,
                    const SizedBox(width: _gap),
                    Flexible(
                      child: Text(
                        text,
                        maxLines: lines,
                        overflow: TextOverflow.ellipsis,
                        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                        // Hug the longest line, so the badge sits beside
                        // the words rather than across an empty gap.
                        textWidthBasis: TextWidthBasis.longestLine,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
