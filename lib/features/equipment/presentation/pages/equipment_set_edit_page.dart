import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

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
              appBar: AppBar(
                title: Text(context.l10n.equipment_setEdit_notFoundTitle),
              ),
              body: Center(
                child: Text(context.l10n.equipment_setEdit_notFoundMessage),
              ),
            );
          }
          _initializeFromSet(set);
          return _buildForm(context, allEquipmentAsync, set);
        },
        loading: () => Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.equipment_setEdit_loadingTitle),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.equipment_setEdit_errorTitle),
          ),
          body: Center(
            child: Text(context.l10n.equipment_setEdit_errorMessage('$error')),
          ),
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
        title: Text(
          widget.isEditing
              ? context.l10n.equipment_setEdit_appBar_editTitle
              : context.l10n.equipment_setEdit_appBar_newTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.equipment_setEdit_nameLabel,
                prefixIcon: const Icon(Icons.folder),
                hintText: context.l10n.equipment_setEdit_nameHint,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.l10n.equipment_setEdit_nameValidation;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: context.l10n.equipment_setEdit_descriptionLabel,
                prefixIcon: const Icon(Icons.description),
                hintText: context.l10n.equipment_setEdit_descriptionHint,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Equipment selection
            Text(
              context.l10n.equipment_setEdit_selectEquipmentTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.equipment_setEdit_selectEquipmentSubtitle,
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
                            ExcludeSemantics(
                              child: Icon(
                                Icons.backpack_outlined,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context
                                  .l10n
                                  .equipment_setEdit_noEquipmentAvailable,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.equipment_setEdit_addEquipmentFirst,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
              error: (error, _) => Center(
                child: Text(
                  context.l10n.equipment_setEdit_errorMessage('$error'),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            Tooltip(
              message: widget.isEditing
                  ? context.l10n.equipment_setEdit_saveTooltip_edit
                  : context.l10n.equipment_setEdit_saveTooltip_new,
              child: FilledButton(
                onPressed: _isLoading ? null : () => _saveSet(existingSet),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.isEditing
                            ? context.l10n.equipment_setEdit_saveButton_edit
                            : context.l10n.equipment_setEdit_saveButton_new,
                      ),
              ),
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
      final diverId =
          existingSet?.diverId ??
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
                  ? context.l10n.equipment_setEdit_snackbar_updated
                  : context.l10n.equipment_setEdit_snackbar_created,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.equipment_setEdit_snackbar_error('$e')),
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
