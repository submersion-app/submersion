import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Info card overlay for displaying selected item details on a map.
///
/// Positioned at the bottom of the map pane, shows a summary of the selected
/// item with a tap action to navigate to details.
class MapInfoCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onDetailsTap;

  const MapInfoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
    this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: subtitle != null ? '$title, $subtitle' : title,
      child: Card(
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        color: colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: onTap ?? onDetailsTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                if (leading != null) ...[
                  SizedBox(width: 48, height: 48, child: leading),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDetailsTap != null)
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: context.l10n.accessibility_label_viewDetails,
                    onPressed: onDetailsTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
