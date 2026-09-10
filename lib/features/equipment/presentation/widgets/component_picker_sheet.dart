import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the add-components sheet for [parentId]. With [replacing], the
/// sheet picks one item to take that row's place instead (issue #1487,
/// replace a part): same candidates, single select, the row keeps its role
/// and order.
Future<void> showComponentPicker(
  BuildContext context, {
  required String parentId,
  EquipmentComponent? replacing,
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
        replacing: replacing,
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

  /// The template row being replaced, or null when adding.
  final EquipmentComponent? replacing;

  const ComponentPickerSheet({
    super.key,
    required this.parentId,
    required this.scrollController,
    this.replacing,
  });

  @override
  ConsumerState<ComponentPickerSheet> createState() =>
      _ComponentPickerSheetState();
}

class _ComponentPickerSheetState extends ConsumerState<ComponentPickerSheet> {
  final _selected = <String>{};
  bool _saving = false;

  bool get _replacing => widget.replacing != null;

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

  void _toggle(String id, bool checked) {
    setState(() {
      if (!checked) {
        _selected.remove(id);
      } else if (_replacing) {
        // One item takes the row's place, so a second tap moves the choice.
        _selected
          ..clear()
          ..add(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _saving) return;
    final replacing = widget.replacing;
    final messenger = ScaffoldMessenger.of(context);
    final cycleText = context.l10n.equipment_components_cycleError;
    // Asked once per batch, before any write, so a cancel costs nothing.
    // The count behind the question is a database read, so it fails like
    // any write below rather than escaping the button callback.
    AssemblyHistoryChoice? choice;
    try {
      choice = await askAssemblyHistory(
        context,
        ref,
        assemblyId: widget.parentId,
        change: replacing == null
            ? AssemblyHistoryChange.added
            : AssemblyHistoryChange.replaced,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (choice == null || !mounted) return;
    setState(() => _saving = true);
    final repository = ref.read(equipmentComponentRepositoryProvider);
    final dives = ref.read(diveRepositoryProvider);
    final alsoPast = choice == AssemblyHistoryChoice.alsoPast;
    // What actually reached the template, so a partial save can drop those
    // from the selection: they stop being candidates once they are parts,
    // and a selected id with no row left on screen cannot be unticked.
    final applied = <String>[];
    var popped = false;
    try {
      // A snapshot: the checkboxes are disabled while saving, but a copy
      // keeps the loop safe regardless of what mutates the set later.
      final ids = _selected.toList();
      final changes = <GearHistoryRewrite>[];
      try {
        if (replacing != null) {
          final newId = ids.single;
          await repository.replaceComponent(replacing.id, newId);
          applied.add(newId);
          changes.add(
            GearPartReplaced(
              oldPartId: replacing.componentEquipmentId,
              newPartId: newId,
            ),
          );
        } else {
          for (final id in ids) {
            await repository.addComponent(
              parentId: widget.parentId,
              componentId: id,
            );
            applied.add(id);
            changes.add(GearPartAdded(id));
          }
        }
      } finally {
        // One pass over the dives for the whole batch rather than one per
        // part, and it runs even when a later part was refused, so what
        // reached the template and what reached the dives cannot drift.
        if (alsoPast && changes.isNotEmpty) {
          await dives.rewriteAssemblyOnPastDives(widget.parentId, changes);
        }
      }
      popped = true;
      // The sheet may have been swiped away or dismissed during the awaits;
      // popping then would take the page underneath instead.
      if (mounted) Navigator.of(context).pop();
    } on EquipmentComponentCycleException {
      messenger.showSnackBar(SnackBar(content: Text(cycleText)));
    } catch (e) {
      // Any other failure (a closed database, a constraint) must not leave
      // the sheet disabled with no way out.
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (!popped && mounted) {
        setState(() {
          _selected.removeAll(applied);
          _saving = false;
        });
      }
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
                  _replacing
                      ? l10n.equipment_components_pickerReplaceTitle
                      : l10n.equipment_components_pickerTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton(
                onPressed: _selected.isEmpty || _saving ? null : _confirm,
                child: Text(
                  _replacing
                      ? l10n.equipment_components_pickerReplaceConfirm
                      : l10n.equipment_components_pickerConfirm(
                          _selected.length,
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              // Wait for the index as well as the gear: with an empty index
              // the sheet would briefly offer the item itself and its
              // relatives, which the repository would then refuse.
              if (!activeAsync.hasValue || !indexAsync.hasValue) {
                final error = activeAsync.error ?? indexAsync.error;
                if (error != null) return Center(child: Text('$error'));
                return const Center(child: CircularProgressIndicator());
              }
              final active = activeAsync.requireValue;
              final index = indexAsync.requireValue;
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
              // Groups follow the enum's declared order, the same order the
              // type dropdown and filter chips use, not the order the rows
              // happened to arrive in.
              final groups = [
                for (final type in EquipmentType.values)
                  if (grouped[type] case final items?) (type, items),
              ];
              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final (type, items) in groups)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              type.localizedName(l10n),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ),
                          for (final item in items)
                            CheckboxListTile(
                              value: _selected.contains(item.id),
                              // Frozen while the adds run, so the selection
                              // being saved is the one that was confirmed.
                              onChanged: _saving
                                  ? null
                                  : (value) => _toggle(item.id, value == true),
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
