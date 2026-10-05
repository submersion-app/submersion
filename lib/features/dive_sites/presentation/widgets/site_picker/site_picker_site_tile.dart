import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// One site in the site picker: the avatar marks the selected site (primary)
/// or a nearby one (tertiary), the subtitle carries its location and, in the
/// Nearby section, its distance.
class SitePickerSiteTile extends StatelessWidget {
  const SitePickerSiteTile({
    super.key,
    required this.site,
    required this.isSelected,
    required this.isNearby,
    required this.subtitle,
    required this.onTap,
    this.distanceText,
  });

  final DiveSite site;
  final bool isSelected;
  final bool isNearby;
  final String? subtitle;
  final String? distanceText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? colorScheme.primaryContainer
            : isNearby
            ? colorScheme.tertiaryContainer
            : colorScheme.surfaceContainerHighest,
        child: Icon(
          isNearby ? Icons.near_me : Icons.location_on,
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : isNearby
              ? colorScheme.onTertiaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(site.name),
      subtitle: subtitle == null && distanceText == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) Text(subtitle!),
                if (distanceText != null)
                  Text(
                    distanceText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: isNearby
                          ? colorScheme.tertiary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isNearby ? FontWeight.w600 : null,
                    ),
                  ),
              ],
            ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
