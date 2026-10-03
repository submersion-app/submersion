import 'package:flutter/material.dart';

/// One labelled number for [DetailStatTiles]. [id] keys the tile as
/// `connections-stat-<id>`.
class DetailStat {
  const DetailStat({
    required this.id,
    required this.value,
    required this.label,
  });

  final String id;
  final String value;
  final String label;
}

/// Equal-width tiles, each a prominent value over a small label.
class DetailStatTiles extends StatelessWidget {
  const DetailStatTiles({super.key, required this.stats});

  final List<DetailStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Equal heights even when a long value shrinks to fit its tile.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, stat) in stats.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              // One spoken item ("18, Dives"), not a bare number.
              child: MergeSemantics(
                child: Container(
                  key: ValueKey('connections-stat-${stat.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Long dates shrink to fit rather than wrap.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          stat.value,
                          maxLines: 1,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        stat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
