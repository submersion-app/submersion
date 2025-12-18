import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/dive_type_entity.dart';
import '../providers/dive_type_providers.dart';

class DiveTypesPage extends ConsumerWidget {
  const DiveTypesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveTypesAsync = ref.watch(diveTypeListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Types'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDiveTypeDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: diveTypesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (diveTypes) {
          final builtInTypes = diveTypes.where((t) => t.isBuiltIn).toList();
          final customTypes = diveTypes.where((t) => !t.isBuiltIn).toList();

          return ListView(
            children: [
              if (customTypes.isNotEmpty) ...[
                _buildSectionHeader(context, 'Custom Dive Types'),
                ...customTypes.map(
                  (type) => _buildDiveTypeTile(
                    context,
                    ref,
                    type,
                    canDelete: true,
                  ),
                ),
                const Divider(),
              ],
              _buildSectionHeader(context, 'Built-in Dive Types'),
              ...builtInTypes.map(
                (type) => _buildDiveTypeTile(
                  context,
                  ref,
                  type,
                  canDelete: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDiveTypeTile(
    BuildContext context,
    WidgetRef ref,
    DiveTypeEntity diveType, {
    required bool canDelete,
  }) {
    return ListTile(
      leading: Icon(
        canDelete ? Icons.label_outline : Icons.label,
        color: canDelete
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(diveType.name),
      subtitle: canDelete ? const Text('Custom') : const Text('Built-in'),
      trailing: canDelete
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, diveType),
            )
          : null,
    );
  }

  Future<void> _showAddDiveTypeDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Dive Type'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Dive Type Name',
              hintText: 'e.g., Search & Recovery',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final notifier = ref.read(diveTypeListNotifierProvider.notifier);
        await notifier.addDiveTypeByName(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added dive type: $result')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding dive type: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DiveTypeEntity diveType,
  ) async {
    // Check if dive type is in use
    final notifier = ref.read(diveTypeListNotifierProvider.notifier);
    final inUse = await notifier.isDiveTypeInUse(diveType.id);

    if (!context.mounted) return;

    if (inUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete "${diveType.name}" - it is used by existing dives'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dive Type?'),
        content: Text('Are you sure you want to delete "${diveType.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await notifier.deleteDiveType(diveType.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${diveType.name}"')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting dive type: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
