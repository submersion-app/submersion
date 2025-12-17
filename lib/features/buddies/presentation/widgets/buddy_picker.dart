import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/buddy.dart';
import '../providers/buddy_providers.dart';

/// Widget for selecting buddies for a dive
class BuddyPicker extends ConsumerWidget {
  final String? diveId;
  final List<BuddyWithRole> selectedBuddies;
  final ValueChanged<List<BuddyWithRole>> onChanged;

  const BuddyPicker({
    super.key,
    this.diveId,
    required this.selectedBuddies,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Buddies',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton.icon(
              onPressed: () => _showBuddySelectionSheet(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Selected buddies as chips
        if (selectedBuddies.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 32,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'No buddies selected',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Add" to select dive buddies',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedBuddies.map((bwr) {
              return _BuddyChip(
                buddyWithRole: bwr,
                onRemove: () {
                  final updated = selectedBuddies
                      .where((b) => b.buddy.id != bwr.buddy.id)
                      .toList();
                  onChanged(updated);
                },
                onRoleChanged: (role) {
                  final updated = selectedBuddies.map((b) {
                    if (b.buddy.id == bwr.buddy.id) {
                      return BuddyWithRole(buddy: b.buddy, role: role);
                    }
                    return b;
                  }).toList();
                  onChanged(updated);
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showBuddySelectionSheet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<List<BuddyWithRole>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BuddySelectionSheet(
        selectedBuddies: selectedBuddies,
      ),
    );
    
    // Update parent with the final list when sheet closes
    if (result != null) {
      onChanged(result);
    }
  }
}

class _BuddyChip extends StatelessWidget {
  final BuddyWithRole buddyWithRole;
  final VoidCallback onRemove;
  final ValueChanged<BuddyRole> onRoleChanged;

  const _BuddyChip({
    required this.buddyWithRole,
    required this.onRemove,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text(
          buddyWithRole.buddy.initials,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(buddyWithRole.buddy.name),
          Text(
            buddyWithRole.role.displayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onDeleted: onRemove,
      onPressed: () => _showRoleSelector(context),
    );
  }

  void _showRoleSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Role for ${buddyWithRole.buddy.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(),
            ...BuddyRole.values.map((role) {
              return ListTile(
                leading: Radio<BuddyRole>(
                  value: role,
                  groupValue: buddyWithRole.role,
                  onChanged: (value) {
                    if (value != null) {
                      onRoleChanged(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                title: Text(role.displayName),
                onTap: () {
                  onRoleChanged(role);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BuddySelectionSheet extends ConsumerStatefulWidget {
  final List<BuddyWithRole> selectedBuddies;

  const _BuddySelectionSheet({
    required this.selectedBuddies,
  });

  @override
  ConsumerState<_BuddySelectionSheet> createState() =>
      _BuddySelectionSheetState();
}

class _BuddySelectionSheetState extends ConsumerState<_BuddySelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late List<BuddyWithRole> _localSelectedBuddies;

  @override
  void initState() {
    super.initState();
    _localSelectedBuddies = List.from(widget.selectedBuddies);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buddiesAsync = _searchQuery.isEmpty
        ? ref.watch(allBuddiesProvider)
        : ref.watch(buddySearchProvider(_searchQuery));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Buddies',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _localSelectedBuddies),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search buddies...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            const SizedBox(height: 8),

            // Add new buddy button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Push to create new buddy and wait for result
                  final result = await context.push<Buddy>('/buddies/new');
                  if (result != null) {
                    // New buddy was created, refresh the list so they can select it
                    ref.invalidate(allBuddiesProvider);
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add New Buddy'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),

            // Buddy list
            Expanded(
              child: buddiesAsync.when(
                data: (buddies) {
                  if (buddies.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.people_outline
                                : Icons.search_off,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No buddies yet'
                                : 'No buddies found',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: buddies.length,
                    itemBuilder: (context, index) {
                      final buddy = buddies[index];
                      final isSelected = _localSelectedBuddies
                          .any((b) => b.buddy.id == buddy.id);
                      final selectedRole = _localSelectedBuddies
                          .where((b) => b.buddy.id == buddy.id)
                          .map((b) => b.role)
                          .firstOrNull;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                )
                              : Text(
                                  buddy.initials,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                        ),
                        title: Text(buddy.name),
                        subtitle: buddy.certificationLevel != null
                            ? Text(buddy.certificationLevel!.displayName)
                            : null,
                        trailing: isSelected
                            ? Chip(
                                label: Text(selectedRole?.displayName ?? 'Buddy'),
                                visualDensity: VisualDensity.compact,
                              )
                            : null,
                        onTap: () {
                          if (isSelected) {
                            _removeBuddy(buddy.id);
                          } else {
                            _showRoleSelectorForBuddy(context, buddy);
                          }
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Error: $error'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _removeBuddy(String buddyId) {
    setState(() {
      _localSelectedBuddies = _localSelectedBuddies
          .where((b) => b.buddy.id != buddyId)
          .toList();
    });
  }

  void _addBuddy(Buddy buddy, BuddyRole role) {
    final existing = _localSelectedBuddies.indexWhere((b) => b.buddy.id == buddy.id);
    setState(() {
      if (existing >= 0) {
        // Update role
        _localSelectedBuddies = [
          ..._localSelectedBuddies.sublist(0, existing),
          BuddyWithRole(buddy: buddy, role: role),
          ..._localSelectedBuddies.sublist(existing + 1),
        ];
      } else {
        _localSelectedBuddies = [
          ..._localSelectedBuddies,
          BuddyWithRole(buddy: buddy, role: role),
        ];
      }
    });
  }

  void _showRoleSelectorForBuddy(BuildContext context, Buddy buddy) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Role for ${buddy.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(),
            ...BuddyRole.values.map((role) {
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(role.displayName),
                onTap: () {
                  Navigator.pop(ctx);
                  _addBuddy(buddy, role);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
