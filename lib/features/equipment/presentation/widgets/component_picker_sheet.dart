import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_components_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/presentation/widgets/foldable_type_group_rows.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Opens the add-components sheet for [parentId]. With [replacing], the
/// sheet picks one item to take that row's place instead (issue #1487,
/// replace a part): same candidates, single select, the row keeps its role
/// and order. The choice is held in [editing], the assembly's sitting
/// (issue #4527), until Save.
Future<void> showComponentPicker(
  BuildContext context, {
  required String parentId,
  EquipmentComponent? replacing,
  required EditSession<EquipmentItem> editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ComponentPickerSheet(
        parentId: parentId,
        scrollController: scrollController,
        replacing: replacing,
        editing: editing,
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

  /// The assembly's sitting, which holds the choice until Save: its parts
  /// are the ones left out.
  final EditSession<EquipmentItem> editing;

  const ComponentPickerSheet({
    super.key,
    required this.parentId,
    required this.scrollController,
    this.replacing,
    required this.editing,
  });

  @override
  ConsumerState<ComponentPickerSheet> createState() =>
      _ComponentPickerSheetState();
}

class _ComponentPickerSheetState extends ConsumerState<ComponentPickerSheet>
    with FoldableTypeGroupsState<ComponentPickerSheet> {
  final _selected = <String>{};

  bool get _replacing => widget.replacing != null;

  List<EquipmentItem> _candidates(
    List<EquipmentItem> active,
    ComponentsIndex index,
  ) {
    final parts = gearItemComponentsList.current(widget.editing);
    final excluded = <String>{
      widget.parentId,
      for (final part in parts ?? index.byParent[widget.parentId] ?? const [])
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
    if (_selected.isEmpty) return;
    final replacing = widget.replacing;
    final messenger = ScaffoldMessenger.of(context);
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
    _hold(widget.editing, replacing, choice);
    Navigator.of(context).pop();
  }

  /// Holds the choice in the assembly's [session], with the answer to
  /// "Update past dives?" for each part it brings in.
  void _hold(
    EditSession<EquipmentItem> session,
    EquipmentComponent? replacing,
    AssemblyHistoryChoice choice,
  ) {
    final parts = gearItemComponentsList.current(session);
    if (parts == null) return;
    final items = {
      for (final item
          in ref.read(activeEquipmentProvider).value ?? const <EquipmentItem>[])
        item.id: item,
    };
    final ids = _selected.toList();
    for (final id in ids) {
      rememberPartAnswer(session, id, choice);
    }
    if (replacing != null) {
      final newId = ids.single;
      gearItemComponentsList.set(session, [
        for (final p in parts)
          p.id == replacing.id
              ? p.copyWith(componentEquipmentId: newId, component: items[newId])
              : p,
      ]);
      return;
    }
    final now = DateTime.now();
    gearItemComponentsList.set(session, [
      ...parts,
      for (final (i, id) in ids.indexed)
        EquipmentComponent(
          id: const Uuid().v4(),
          parentEquipmentId: widget.parentId,
          componentEquipmentId: id,
          sortOrder: parts.length + i,
          createdAt: now,
          updatedAt: now,
          component: items[id],
        ),
    ]);
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
                onPressed: _selected.isEmpty ? null : _confirm,
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
              // Labelled as one list, so identical candidates read differently
              // from each other (#1549).
              final labels = equipmentRowLabelsOf(context, ref, candidates);
              final grouped = <EquipmentType, List<EquipmentItem>>{};
              for (final item in candidates) {
                grouped.putIfAbsent(item.type, () => []).add(item);
              }
              // Groups follow the localized label, the same order the type
              // dropdown and filter chips use (#2937), not the order the rows
              // happened to arrive in.
              final groups = [
                for (final type in grouped.keys.sortedByLocalizedName(l10n))
                  (type, grouped[type]!),
              ];
              final firstFold = openTypeGroups == null;
              ensureOpenTypeGroups(groups, _selected);
              // Replacing a part, its type is where the diver will look.
              if (firstFold && openTypeGroups != null) {
                final replacedId = widget.replacing?.componentEquipmentId;
                for (final item in active) {
                  if (item.id != replacedId) continue;
                  openTypeGroups = {...openTypeGroups!, typeFoldKey(item.type)};
                  break;
                }
              }
              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                children: foldableTypeGroupRows(
                  context,
                  groups: groups,
                  open: openTypeGroups,
                  ticked: _selected,
                  onToggle: toggleTypeGroup,
                  rowBuilder: (item) => CheckboxListTile(
                    value: _selected.contains(item.id),
                    onChanged: (value) => _toggle(item.id, value == true),
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        switch (labels[item.id]?.subtitle) {
                          final detail? => Text(detail),
                          null => const SizedBox.shrink(),
                        },
                        ServiceStatusIndicatorFor(
                          equipmentId: item.id,
                          density: ServiceIndicatorDensity.compact,
                        ),
                      ],
                    ),
                    secondary: Icon(equipmentItemIcon(item)),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
