import 'package:flutter/material.dart';

import 'package:submersion/features/universal_import/presentation/widgets/duplicate_badge.dart';

/// Card displaying an entity for selection in the universal import wizard.
///
/// Generalizes the UDDF entity card to work with any import entity type.
/// Shows entity name, optional subtitle, icon, selection checkbox, and
/// optional duplicate badge.
class ImportEntityCard extends StatelessWidget {
  const ImportEntityCard({
    super.key,
    required this.name,
    this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onToggle,
    this.isDuplicate = false,
    this.duplicateLabel,
  });

  final String name;
  final String? subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onToggle;
  final bool isDuplicate;
  final String? duplicateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _SelectionCheckbox(
                isSelected: isSelected,
                colorScheme: colorScheme,
              ),
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
                DuplicateBadge(label: duplicateLabel),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({
    required this.isSelected,
    required this.colorScheme,
  });

  final bool isSelected;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
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
}
