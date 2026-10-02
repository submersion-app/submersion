import 'package:flutter/material.dart';

/// One stat on a route card: an icon plus its already formatted text.
class NavTrackCardStat {
  final IconData icon;
  final String text;

  const NavTrackCardStat({required this.icon, required this.text});
}

/// The route card's stat line: depth, duration and distance, each with a
/// leading icon. Wraps onto a second line rather than overflowing when the
/// card is too narrow for all of them (unlike the dive card's stat row,
/// a route card has no badges competing for the same line, so a plain Wrap
/// is enough).
class NavTrackCardStatRow extends StatelessWidget {
  const NavTrackCardStatRow({super.key, required this.stats});

  final List<NavTrackCardStat> stats;

  static const _iconSize = 14.0;
  static const _iconGap = 4.0;
  static const _statSpacing = 16.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wrap gives each child the parent's full available width as its own
        // upper bound (it only wraps *between* children, it never shrinks
        // one), so a single stat wider than a very narrow card would
        // otherwise overflow instead of ellipsizing.
        final maxStatWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        return Wrap(
          spacing: _statSpacing,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final stat in stats)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxStatWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stat.icon, size: _iconSize, color: style?.color),
                    const SizedBox(width: _iconGap),
                    Flexible(
                      child: Text(
                        stat.text,
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
