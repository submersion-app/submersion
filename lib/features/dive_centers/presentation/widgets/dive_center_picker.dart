import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/dive_center.dart';
import '../providers/dive_center_providers.dart';

/// A bottom sheet widget for selecting a dive center from a list
class DiveCenterPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final DiveCenter? selectedCenter;
  final ValueChanged<DiveCenter> onCenterSelected;

  const DiveCenterPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedCenter,
    required this.onCenterSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centersAsync = ref.watch(allDiveCentersProvider);

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title and add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Dive Center',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/dive-centers/new');
                },
                icon: const Icon(Icons.add),
                label: const Text('New Dive Center'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Dive center list
        Expanded(
          child: centersAsync.when(
            data: (centers) {
              if (centers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No dive centers yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/dive-centers/new');
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Dive Center'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: centers.length,
                itemBuilder: (context, index) {
                  final center = centers[index];
                  final isSelected = selectedCenter?.id == center.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.store,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(center.name),
                    subtitle: center.displayLocation != null
                        ? Text(center.displayLocation!)
                        : null,
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => onCenterSelected(center),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error loading dive centers: $error'),
            ),
          ),
        ),
      ],
    );
  }
}
