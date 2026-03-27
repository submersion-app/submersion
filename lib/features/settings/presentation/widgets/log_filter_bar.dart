import 'package:flutter/material.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';

/// Filter bar with category chips, severity dropdown, displayed below the app bar.
class LogFilterBar extends ConsumerWidget {
  const LogFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(logFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: LogCategory.values.map((category) {
                final isActive = filter.activeCategories.contains(category);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(category.displayName),
                    selected: isActive,
                    onSelected: (_) {
                      ref
                          .read(logFilterProvider.notifier)
                          .toggleCategory(category);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Severity dropdown
          Row(
            children: [
              Text(
                'Min severity: ',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              DropdownButton<LogLevel>(
                value: filter.minimumSeverity,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: LogLevel.values
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(
                          level.tag,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (level) {
                  if (level != null) {
                    ref
                        .read(logFilterProvider.notifier)
                        .setMinimumSeverity(level);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
