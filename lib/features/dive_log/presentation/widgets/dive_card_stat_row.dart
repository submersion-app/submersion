import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';

/// One stat slot on the detailed dive card: an optional leading icon plus
/// its already formatted text.
class DiveCardStat {
  final IconData? icon;
  final String text;

  /// Icon and text color. Falls back to the theme's bodySmall color.
  final Color? color;

  const DiveCardStat({this.icon, required this.text, this.color});
}

/// The detailed dive card's stat line: the stat slots on the start side, and
/// the dive-type badges plus the dive mode badge right-aligned on the same
/// line, with the mode badge last.
///
/// A plain Row cannot share this line safely. The stats are rigid text, and
/// giving them a Flexible splits the width evenly with the badges' Expanded
/// no matter what each side needs. So this measures instead: the badges get
/// their narrowest width reserved first (the type badges collapsed to "+N",
/// the mode badge at its full width), the stats get the remainder at
/// their natural width, and only when that remainder is too small do the
/// stats ellipsize, each under a fair share of it (see [fairShareWidths]).
/// The badges then take whatever the stats leave, expanding back out of
/// "+N" as room allows.
class DiveCardStatRow extends StatelessWidget {
  final List<DiveCardStat> stats;
  final List<String> diveTypeLabels;
  final DiveMode diveMode;

  const DiveCardStatRow({
    super.key,
    required this.stats,
    required this.diveTypeLabels,
    required this.diveMode,
  });

  static const _statGap = 16.0;
  static const _badgeGap = 8.0;
  static const _modeGap = 6.0;
  static const _iconSize = 14.0;
  static const _iconGap = 4.0;

  /// Splits [available] across items whose natural widths are [natural],
  /// in the same order.
  ///
  /// Everything keeps its natural width when the total fits. Otherwise the
  /// budget is filled narrowest first: an item needing less than an equal
  /// share of what is left keeps its natural width, and the leftover goes to
  /// the wider items, which each end up with an equal share.
  static List<double> fairShareWidths(List<double> natural, double available) {
    final budget = math.max(0.0, available);
    final total = natural.fold(0.0, (sum, width) => sum + width);
    if (total <= budget) return List.of(natural);

    final order = List.generate(natural.length, (i) => i)
      ..sort((a, b) => natural[a].compareTo(natural[b]));
    final widths = List.filled(natural.length, 0.0);
    var remaining = budget;
    for (var k = 0; k < order.length; k++) {
      final share = remaining / (order.length - k);
      final width = math.min(natural[order[k]], share);
      widths[order[k]] = width;
      remaining -= width;
    }
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    TextStyle? styleOf(DiveCardStat stat) =>
        stat.color == null ? baseStyle : baseStyle?.copyWith(color: stat.color);

    double naturalWidth(DiveCardStat stat) {
      final painter = TextPainter(
        text: TextSpan(text: stat.text, style: styleOf(stat)),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      // Rounded up so a stat measured to fit is never ellipsized by a
      // sub-pixel difference from the Text's own layout.
      final textWidth = painter.width.ceilToDouble();
      painter.dispose();
      return stat.icon == null ? textWidth : _iconSize + _iconGap + textWidth;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final naturals = [for (final stat in stats) naturalWidth(stat)];
        final typeReserve = diveTypeLabels.isEmpty
            ? 0.0
            : DiveTypeBadgeRow.minWidthOf(
                    context,
                    diveTypeLabels,
                    dense: true,
                  ) +
                  _modeGap;
        final badgeReserve =
            _badgeGap +
            typeReserve +
            DiveModeBadge.widthOf(context, diveMode, dense: true);
        final gaps = _statGap * math.max(0, stats.length - 1);
        final widths = constraints.maxWidth.isFinite
            ? fairShareWidths(
                naturals,
                constraints.maxWidth - badgeReserve - gaps,
              )
            : naturals;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: _statGap),
              SizedBox(
                width: widths[i],
                child: _buildStat(stats[i], styleOf(stats[i]), widths[i]),
              ),
            ],
            const SizedBox(width: _badgeGap),
            // Within the badge cell the type badges are the ones that give:
            // they collapse into "+N" while the mode badge keeps its width.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (diveTypeLabels.isNotEmpty) ...[
                      Flexible(
                        child: DiveTypeBadgeRow(
                          labels: diveTypeLabels,
                          dense: true,
                        ),
                      ),
                      const SizedBox(width: _modeGap),
                    ],
                    DiveModeBadge(mode: diveMode, dense: true),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStat(DiveCardStat stat, TextStyle? style, double width) {
    final text = Text(
      stat.text,
      style: style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    // Narrower than the icon itself: drop it rather than overflow.
    if (stat.icon == null || width < _iconSize) return text;
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(stat.icon, size: _iconSize, color: style?.color),
        ),
        // Between the icon's width and icon plus gap, the gap shrinks and
        // the text gets nothing, so the icon stays without overflowing.
        SizedBox(width: math.min(_iconGap, width - _iconSize)),
        Flexible(child: text),
      ],
    );
  }
}
