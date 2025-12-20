import 'package:flutter/material.dart';

import '../../domain/entities/dive_computer.dart';

/// Widget for selecting between multiple dive profiles (computers).
class ProfileSelectorWidget extends StatelessWidget {
  /// Available dive computers/profiles
  final List<DiveComputer> computers;

  /// Currently selected computer ID
  final String? selectedComputerId;

  /// Callback when selection changes
  final void Function(String computerId)? onSelectionChanged;

  /// ID of the primary profile
  final String? primaryComputerId;

  const ProfileSelectorWidget({
    super.key,
    required this.computers,
    this.selectedComputerId,
    this.onSelectionChanged,
    this.primaryComputerId,
  });

  @override
  Widget build(BuildContext context) {
    if (computers.isEmpty) {
      return const SizedBox.shrink();
    }

    if (computers.length == 1) {
      return _buildSingleComputerDisplay(context, computers.first);
    }

    return _buildComputerSelector(context);
  }

  Widget _buildSingleComputerDisplay(
    BuildContext context,
    DiveComputer computer,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.watch,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            computer.displayName,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (computer.model != null) ...[
            const SizedBox(width: 4),
            Text(
              '(${computer.model})',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComputerSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Dive Computers',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: computers.map((computer) {
              final isSelected = computer.id == selectedComputerId;
              final isPrimary = computer.id == primaryComputerId;

              return _buildComputerChip(
                context,
                computer: computer,
                isSelected: isSelected,
                isPrimary: isPrimary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildComputerChip(
    BuildContext context, {
    required DiveComputer computer,
    required bool isSelected,
    required bool isPrimary,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onSelectionChanged != null
          ? () => onSelectionChanged!(computer.id)
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.watch,
              size: 16,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              computer.displayName,
              style: textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isPrimary) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Primary',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dropdown version of the profile selector.
class ProfileSelectorDropdown extends StatelessWidget {
  /// Available dive computers/profiles
  final List<DiveComputer> computers;

  /// Currently selected computer ID
  final String? selectedComputerId;

  /// Callback when selection changes
  final void Function(String computerId)? onSelectionChanged;

  /// ID of the primary profile
  final String? primaryComputerId;

  const ProfileSelectorDropdown({
    super.key,
    required this.computers,
    this.selectedComputerId,
    this.onSelectionChanged,
    this.primaryComputerId,
  });

  @override
  Widget build(BuildContext context) {
    if (computers.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final selectedComputer = computers.firstWhere(
      (c) => c.id == selectedComputerId,
      orElse: () => computers.first,
    );

    return DropdownButton<String>(
      value: selectedComputer.id,
      onChanged: onSelectionChanged != null
          ? (value) {
              if (value != null) {
                onSelectionChanged!(value);
              }
            }
          : null,
      underline: const SizedBox.shrink(),
      icon: Icon(
        Icons.arrow_drop_down,
        color: colorScheme.onSurfaceVariant,
      ),
      selectedItemBuilder: (context) {
        return computers.map((computer) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.watch,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                computer.displayName,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (computer.id == primaryComputerId) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'P',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onTertiary,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ],
          );
        }).toList();
      },
      items: computers.map((computer) {
        final isPrimary = computer.id == primaryComputerId;

        return DropdownMenuItem(
          value: computer.id,
          child: Row(
            children: [
              Icon(
                Icons.watch,
                size: 16,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      computer.displayName,
                      style: textTheme.bodyMedium,
                    ),
                    if (computer.model != null)
                      Text(
                        computer.model!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Primary',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
