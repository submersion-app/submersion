import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card displaying a non-dive UDDF entity for selection in the import wizard.
///
/// Shows entity name, optional subtitle, icon, selection checkbox, and
/// optional duplicate badge. Used for trips, sites, equipment, buddies,
/// dive centers, certifications, tags, and dive types.
class UddfEntityCard extends StatelessWidget {
  const UddfEntityCard({
    super.key,
    required this.name,
    this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onToggle,
    this.isDuplicate = false,
  });

  final String name;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onToggle;
  final bool isDuplicate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Semantics(
        button: true,
        label: context.l10n.diveImport_uddf_toggleEntitySelection(name),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildCheckbox(colorScheme),
                const SizedBox(width: 12),
                Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isDuplicate) ...[
                  const SizedBox(width: 8),
                  _buildDuplicateBadge(context, colorScheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(ColorScheme colorScheme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
        color: isSelected ? colorScheme.primary : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }

  Widget _buildDuplicateBadge(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: colorScheme.error),
          const SizedBox(width: 4),
          Text(
            context.l10n.diveImport_uddf_duplicate,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
