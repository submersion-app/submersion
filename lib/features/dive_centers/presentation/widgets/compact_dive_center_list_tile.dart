import 'package:flutter/material.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';

/// Two-line compact card tile for the dive center list.
///
/// Line 1: Center name (expanded) | Dive count text | Chevron
/// Line 2: Location string (secondary text color)
class CompactDiveCenterListTile extends StatelessWidget {
  final DiveCenter center;
  final int diveCount;
  final bool isSelected;
  final VoidCallback? onTap;

  const CompactDiveCenterListTile({
    super.key,
    required this.center,
    required this.diveCount,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: cardColor,
      child: Semantics(
        button: true,
        label: center.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: center name, dive count, chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        center.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$diveCount dives',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        color: secondaryTextColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                // Line 2: location
                if (center.fullLocationString != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    center.fullLocationString!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
