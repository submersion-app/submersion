import 'package:flutter/material.dart';

/// One measured figure on a track row: an icon plus its already formatted
/// text (e.g. depth "138,4 m", duration "3h 4min").
class TrackStat {
  final IconData icon;
  final String text;

  const TrackStat({required this.icon, required this.text});
}

/// A track row's measured figures (distance / depth / duration), styled
/// like the dive list's stat line ([DiveCardStatRow]'s `_buildStat`: icon
/// plus bold text in the theme's accent color).
///
/// Unlike [DiveCardStatRow], this never shares its line with badges -- the
/// kind badge sits in the title row instead -- so it needs no fair-share
/// width measurement. It still has to survive a narrow phone width with
/// three stats whose formatted length varies by locale and unit system, so
/// it wraps ([Wrap]) rather than overflowing a rigid [Row].
class TrackStatRow extends StatelessWidget {
  const TrackStatRow({super.key, required this.stats});

  final List<TrackStat> stats;

  static const _iconSize = 14.0;
  static const _iconGap = 4.0;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: color);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final stat in stats)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(stat.icon, size: _iconSize, color: color),
              const SizedBox(width: _iconGap),
              Text(stat.text, style: style),
            ],
          ),
      ],
    );
  }
}
