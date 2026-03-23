import 'package:flutter/material.dart';

/// Two-line compact card tile for the site list.
///
/// Line 1: Site name (expanded) | Dive count text | Chevron
/// Line 2: Location string (secondary text color)
class CompactSiteListTile extends StatelessWidget {
  final String name;
  final String? location;
  final int diveCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const CompactSiteListTile({
    super.key,
    required this.name,
    this.location,
    required this.diveCount,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
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
        label: name,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 4,
              right: 10,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Visibility(
                  visible: isSelectionMode,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line 1: site name, dive count, chevron
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$diveCount dives',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: secondaryTextColor),
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
                      if (location != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          location!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: secondaryTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
