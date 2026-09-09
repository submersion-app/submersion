import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the add-components sheet for [parentId].
Future<void> showComponentPicker(
  BuildContext context, {
  required String parentId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ComponentPickerSheet(
        parentId: parentId,
        scrollController: scrollController,
      ),
    ),
  );
}

/// Active gear grouped by type, with checkboxes, minus everything that
/// cannot legally become a part of [parentId]: the item itself, its current
/// parts, and every ancestor and descendant. The repository re-checks on
/// insert; the exclusion here is so the impossible choice is simply absent.
class ComponentPickerSheet extends ConsumerStatefulWidget {
  final String parentId;
  final ScrollController scrollController;

  const ComponentPickerSheet({
    super.key,
    required this.parentId,
    required this.scrollController,
  });

  @override
  ConsumerState<ComponentPickerSheet> createState() =>
      _ComponentPickerSheetState();
}

class _ComponentPickerSheetState extends ConsumerState<ComponentPickerSheet> {
  final _selected = <String>{};
  bool _saving = false;

  List<EquipmentItem> _candidates(
    List<EquipmentItem> active,
    ComponentsIndex index,
  ) {
    final excluded = <String>{
      widget.parentId,
      for (final part in index.byParent[widget.parentId] ?? const [])
        part.componentEquipmentId,
      ...index.ancestorsOf(widget.parentId),
      ...index.descendantsOf(widget.parentId),
    };
    return [
      for (final item in active)
        if (!excluded.contains(item.id)) item,
    ];
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    final repository = ref.read(equipmentComponentRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cycleText = context.l10n.equipment_components_cycleError;
    try {
      for (final id in _selected) {
        await repository.addComponent(
          parentId: widget.parentId,
          componentId: id,
        );
      }
      navigator.pop();
    } on EquipmentComponentCycleException {
      messenger.showSnackBar(SnackBar(content: Text(cycleText)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeAsync = ref.watch(activeEquipmentProvider);
    final indexAsync = ref.watch(equipmentComponentsIndexProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.equipment_components_pickerTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton(
                onPressed: _selected.isEmpty || _saving ? null : _confirm,
                child: Text(
                  l10n.equipment_components_pickerConfirm(_selected.length),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: activeAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (active) {
              final index = indexAsync.value ?? ComponentsIndex.empty;
              final candidates = _candidates(active, index);
              if (candidates.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.equipment_components_pickerEmpty),
                  ),
                );
              }
              final grouped = <EquipmentType, List<EquipmentItem>>{};
              for (final item in candidates) {
                grouped.putIfAbsent(item.type, () => []).add(item);
              }
              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final entry in grouped.entries)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              entry.key.localizedName(l10n),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ),
                          for (final item in entry.value)
                            CheckboxListTile(
                              value: _selected.contains(item.id),
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _selected.add(item.id);
                                } else {
                                  _selected.remove(item.id);
                                }
                              }),
                              title: Text(item.name),
                              subtitle: item.fullName != item.name
                                  ? Text(item.fullName)
                                  : null,
                              secondary: Icon(equipmentTypeIcon(item.type)),
                              controlAffinity: ListTileControlAffinity.trailing,
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
