import 'package:flutter/material.dart';

import '../../data/repositories/statistics_repository.dart';

/// A widget for displaying ranked items with progress bars
class RankingList extends StatelessWidget {
  final List<RankingItem> items;
  final String countLabel;
  final bool showMedals;
  final int? maxItems;
  final void Function(RankingItem)? onItemTap;

  const RankingList({
    super.key,
    required this.items,
    this.countLabel = 'dives',
    this.showMedals = true,
    this.maxItems,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.leaderboard_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No data yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final displayItems = maxItems != null ? items.take(maxItems!).toList() : items;
    final maxCount = items.isNotEmpty
        ? items.map((e) => e.count).reduce((a, b) => a > b ? a : b)
        : 1;

    return Column(
      children: [
        for (var i = 0; i < displayItems.length; i++)
          _RankingTile(
            rank: i + 1,
            item: displayItems[i],
            maxCount: maxCount,
            countLabel: countLabel,
            showMedal: showMedals && i < 3,
            onTap: onItemTap != null ? () => onItemTap!(displayItems[i]) : null,
          ),
        if (maxItems != null && items.length > maxItems!) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'and ${items.length - maxItems!} more',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int rank;
  final RankingItem item;
  final int maxCount;
  final String countLabel;
  final bool showMedal;
  final VoidCallback? onTap;

  const _RankingTile({
    required this.rank,
    required this.item,
    required this.maxCount,
    required this.countLabel,
    required this.showMedal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = maxCount > 0 ? item.count / maxCount : 0.0;
    final medalColors = [
      Colors.amber.shade600,
      Colors.grey.shade400,
      Colors.brown.shade400,
    ];

    Widget tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (showMedal)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: medalColors[rank - 1],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.count} $countLabel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      tile = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: tile,
      );
    }

    return tile;
  }
}

/// A simple list for showing value rankings (like SAC records)
class ValueRankingCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const ValueRankingCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}
