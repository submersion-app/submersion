import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../domain/entities/equipment_set.dart';
import '../../domain/entities/equipment_item.dart';
import '../providers/equipment_providers.dart';
import '../providers/equipment_set_providers.dart';

class EquipmentSetEditPage extends ConsumerStatefulWidget {
  final String? setId;

  const EquipmentSetEditPage({super.key, this.setId});

  bool get isEditing => setId != null;

  @override
  ConsumerState<EquipmentSetEditPage> createState() =>
      _EquipmentSetEditPageState();
}

class _EquipmentSetEditPageState extends ConsumerState<EquipmentSetEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final Set<String> _selectedEquipmentIds = {};
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeFromSet(EquipmentSet set) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = set.name;
    _descriptionController.text = set.description;
    _selectedEquipmentIds.addAll(set.equipmentIds);
  }

  @override
  Widget build(BuildContext context) {
    final allEquipmentAsync = ref.watch(activeEquipmentProvider);

    if (widget.isEditing) {
      final setAsync = ref.watch(equipmentSetProvider(widget.setId!));
      return setAsync.when(
        data: (set) {
          if (set == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Set Not Found')),
              body: const Center(
                child: Text('This equipment set no longer exists.'),
              ),
            );
          }
          _initializeFromSet(set);
          return _buildForm(context, allEquipmentAsync, set);
        },
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Loading...')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(child: Text('Error: $error')),
        ),
      );
    }

    return _buildForm(context, allEquipmentAsync, null);
  }

  Widget _buildForm(
    BuildContext context,
    AsyncValue<List<EquipmentItem>> equipmentAsync,
    EquipmentSet? existingSet,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Set' : 'New Equipment Set'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Set Name *',
                prefixIcon: Icon(Icons.folder),
                hintText: 'e.g., Warm Water Setup',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                hintText: 'Optional description...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Equipment selection
            Text(
              'Select Equipment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the equipment items to include in this set.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),

            equipmentAsync.when(
              data: (equipment) {
                if (equipment.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.backpack_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No equipment available',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add equipment first before creating a set.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Group equipment by type
                final groupedEquipment = <EquipmentType, List<EquipmentItem>>{};
                for (final item in equipment) {
                  groupedEquipment.putIfAbsent(item.type, () => []).add(item);
                }

                return Column(
                  children: groupedEquipment.entries.map((entry) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              entry.key.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ),
                          ...entry.value.map(
                            (item) => _buildEquipmentCheckbox(context, item),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),

            const SizedBox(height: 32),

            // Save Button
            FilledButton(
              onPressed: _isLoading ? null : () => _saveSet(existingSet),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save Changes' : 'Create Set'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentCheckbox(BuildContext context, EquipmentItem item) {
    final isSelected = _selectedEquipmentIds.contains(item.id);

    return CheckboxListTile(
      value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            _selectedEquipmentIds.add(item.id);
          } else {
            _selectedEquipmentIds.remove(item.id);
          }
        });
      },
      title: Text(item.name),
      subtitle: item.fullName != item.name ? Text(item.fullName) : null,
      secondary: Icon(
        _getIconForType(item.type),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  Future<void> _saveSet(EquipmentSet? existingSet) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get the current diver ID - preserve existing for edits, get fresh for new sets
      final diverId = existingSet?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      final set = EquipmentSet(
        id: widget.setId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        equipmentIds: _selectedEquipmentIds.toList(),
        createdAt: existingSet?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final notifier = ref.read(equipmentSetListNotifierProvider.notifier);

      if (widget.isEditing) {
        await notifier.updateSet(set);
      } else {
        await notifier.addSet(set);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Equipment set updated'
                  : 'Equipment set created',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving equipment set: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getIconForType(EquipmentType type) {
    switch (type) {
      case EquipmentType.regulator:
        return Icons.air;
      case EquipmentType.bcd:
        return Icons.accessibility_new;
      case EquipmentType.wetsuit:
      case EquipmentType.drysuit:
        return Icons.checkroom;
      case EquipmentType.fins:
        return Icons.directions_walk;
      case EquipmentType.mask:
        return Icons.visibility;
      case EquipmentType.computer:
        return Icons.watch;
      case EquipmentType.tank:
        return Icons.propane_tank;
      case EquipmentType.weights:
        return Icons.fitness_center;
      case EquipmentType.light:
        return Icons.flashlight_on;
      case EquipmentType.camera:
        return Icons.camera_alt;
      default:
        return Icons.backpack;
    }
  }
}
