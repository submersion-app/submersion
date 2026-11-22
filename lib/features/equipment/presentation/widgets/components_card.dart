import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_components_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_list_pending.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_departed_status.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_totals_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_role_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/part_of_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// The Components card on the equipment detail page (issue #1487): the parts
/// this item is assembled from, each with its role, its own service dot,
/// inline edit, replace and remove actions, and drag-to-reorder. When the
/// item is itself a part of other assemblies, a "Part of" section lists them
/// above its own parts, which then sit under a "Contains" caption.
///
/// Lives on the detail page, not in a card editor, like every other cross-item
/// edge (service clocks, documents, unit configurations): a new item has no
/// id until it is saved.
class ComponentsCard extends ConsumerWidget {
  final String equipmentId;

  /// The open card's sitting (issue #4527, phase 3): every change to the parts
  /// is held there until Save, its "Update past dives?" asked when it is made.
  /// With no sitting given, the card reads only; during a sitting every view
  /// shows its parts.
  final EditSession<EquipmentItem>? editing;

  const ComponentsCard({super.key, required this.equipmentId, this.editing});

  /// [parts] once [change] has been applied in the open card's sitting.
  void _setInSitting(
    EditSession<EquipmentItem> session,
    List<EquipmentComponent> Function(List<EquipmentComponent> parts) change,
  ) {
    final parts = gearItemComponentsList.current(session);
    if (parts == null) return;
    gearItemComponentsList.set(session, change(parts));
  }

  Future<void> _editRole(
    BuildContext context,
    WidgetRef ref,
    EquipmentComponent part,
  ) async {
    final repository = ref.read(equipmentComponentRepositoryProvider);
    final suggestions = await repository.distinctRoles();
    if (!context.mounted) return;
    final role = await showComponentRoleDialog(
      context,
      initial: part.role,
      suggestions: suggestions.where((r) => r != part.role).toList(),
    );
    final session = editing;
    if (role == null || role == part.role || session == null) return;
    _setInSitting(
      session,
      (parts) => [
        for (final p in parts) p.id == part.id ? p.copyWith(role: role) : p,
      ],
    );
  }

  /// Removes the part from the template and from the planned dives that
  /// carry the assembly, and from the logged ones too when the diver asks
  /// for that (swap with history, issue #4283).
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    EquipmentComponent part,
  ) async {
    final session = editing;
    if (session == null) return;
    // The dive count the question is built from is a database read, and its
    // failure may not escape the icon callback with nothing shown to the
    // diver.
    final messenger = ScaffoldMessenger.of(context);
    // A part added in the sitting was never on a dive: it just goes.
    if (!(gearItemComponentsList.loaded(session) ?? const []).any(
      (c) => c.id == part.id,
    )) {
      _setInSitting(
        session,
        (parts) => [
          for (final p in parts)
            if (p.id != part.id) p,
        ],
      );
      return;
    }
    try {
      final choice = await askAssemblyHistory(
        context,
        ref,
        assemblyId: equipmentId,
        change: AssemblyHistoryChange.removed,
      );
      if (choice == null) return;
      rememberPartAnswer(session, part.componentEquipmentId, choice);
      _setInSitting(
        session,
        (parts) => [
          for (final p in parts)
            if (p.id != part.id) p,
        ],
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = RecordEditScope.maybeOf<EquipmentItem>(context);
    final session = editing ?? scope?.session;
    // Only the open card's editor acts.
    final readOnly = editing == null;
    if (session == null) return _build(context, ref, null, readOnly);
    return ListenableBuilder(
      listenable: gearItemComponentsList.changes(session),
      builder: (context, _) => _build(context, ref, session, readOnly),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? session,
    bool readOnly,
  ) {
    final l10n = context.l10n;
    final storedParts = ref.watch(equipmentComponentsProvider(equipmentId));
    final held = session == null
        ? null
        : gearItemComponentsList.current(session);
    final AsyncValue<List<EquipmentComponent>> partsAsync = held == null
        ? storedParts
        : AsyncValue.data(held);
    final loaded = session == null
        ? null
        : gearItemComponentsList.loaded(session);
    // The open card acts once its sitting has read the parts.
    final canAct = !readOnly && held != null;
    final partOfAsync = ref.watch(equipmentPartOfProvider(equipmentId));
    final partOf = partOfAsync.hasError
        ? const <PartOfEntry>[]
        : partOfAsync.value ?? const <PartOfEntry>[];
    // The rollup, not the own-clocks map: a part whose own sub-part is
    // overdue must light up here exactly as it does in the equipment
    // list, or the two disagree about the same part (#2260).
    final worstClocks =
        ref.watch(equipmentRollupClockProvider).value ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.equipment_components_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                RecordCardPencil(cardTitle: l10n.equipment_components_title),
                if (canAct && editing != null)
                  TextButton.icon(
                    onPressed: () => showComponentPicker(
                      context,
                      parentId: equipmentId,
                      editing: editing!,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.equipment_components_add),
                  ),
              ],
            ),
            const Divider(),
            if (editing case final session?)
              ?gearItemListPending(gearItemComponentsList, session),
            if (partOfAsync.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.common_error_tryAgain),
              ),
            if (partOf.isNotEmpty) ...[
              PartOfSection(entries: partOf),
              const Divider(),
              ComponentsSectionLabel(l10n.equipment_components_containsSection),
            ],
            partsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  Padding(padding: const EdgeInsets.all(8), child: Text('$e')),
              data: (parts) {
                if (parts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      // A part of something else is most likely a leaf, so
                      // its empty state must not read as missing parts.
                      partOf.isNotEmpty
                          ? l10n.equipment_components_emptyLeaf
                          : l10n.equipment_components_empty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                // Every part labelled as one list, so two identical parts
                // gain the detail that tells them apart (#2791, #1549).
                // The role is on the row too, so parts it already tells
                // apart gain no tie-break.
                final roles = {
                  for (final part in parts)
                    part.componentEquipmentId: _roleText(part, l10n),
                };
                final labels = equipmentRowLabelsOf(context, ref, [
                  for (final part in parts) ?part.component,
                ], shownWith: (item) => roles[item.id] ?? '');
                return _ComponentsList(
                  parts: parts,
                  readOnly: !canAct,
                  changed: (part) => loaded != null && !loaded.contains(part),
                  detailsFor: (part) =>
                      labels[part.componentEquipmentId]?.subtitleParts ??
                      const [],
                  dotColorFor: (part) => serviceSeverityDotColor(
                    context,
                    worstClocks[part.componentEquipmentId]?.status.severity,
                  ),
                  onEditRole: (part) => _editRole(context, ref, part),
                  onReplace: (part) => showComponentPicker(
                    context,
                    parentId: equipmentId,
                    replacing: part,
                    editing: editing!,
                  ),
                  onRemove: (part) => _remove(context, ref, part),
                  onReorder: (ids) => _setInSitting(editing!, (parts) {
                    final byId = {for (final p in parts) p.id: p};
                    return [for (final id in ids) ?byId[id]];
                  }),
                );
              },
            ),
            // What the parts add up to (issue #4443); hides itself when no
            // part declares a buoyancy or dry weight.
            AssemblyTotalsSection(assemblyId: equipmentId),
          ],
        ),
      ),
    );
  }
}

/// What a part's row says it does: its role in the assembly, or its type
/// when it has none.
String _roleText(EquipmentComponent part, AppLocalizations l10n) =>
    part.role.isNotEmpty
    ? part.role
    : (part.component?.type ?? EquipmentType.other).localizedName(l10n);

/// The reorderable rows. Holds its own copy of the order so a dragged row
/// lands where it was dropped at once; the provider's debounced refresh
/// would otherwise snap it back for up to 300 ms before catching up.
class _ComponentsList extends StatefulWidget {
  final List<EquipmentComponent> parts;
  final bool readOnly;

  /// Whether a part's row is the sitting's: added or changed in it.
  final bool Function(EquipmentComponent part) changed;
  final List<String> Function(EquipmentComponent part) detailsFor;
  final Color Function(EquipmentComponent part) dotColorFor;
  final void Function(EquipmentComponent part) onEditRole;
  final void Function(EquipmentComponent part) onReplace;
  final void Function(EquipmentComponent part) onRemove;
  final void Function(List<String> orderedIds) onReorder;

  const _ComponentsList({
    required this.parts,
    required this.readOnly,
    required this.changed,
    required this.detailsFor,
    required this.dotColorFor,
    required this.onEditRole,
    required this.onReplace,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  State<_ComponentsList> createState() => _ComponentsListState();
}

class _ComponentsListState extends State<_ComponentsList> {
  late List<EquipmentComponent> _parts = List.of(widget.parts);

  @override
  void didUpdateWidget(covariant _ComponentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh provider value (a part added, removed, renamed, or the persisted
    // order arriving) replaces the local copy.
    if (!listEquals(widget.parts, oldWidget.parts)) {
      _parts = List.of(widget.parts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      // onReorderItem already adjusts newIndex for the removed row, unlike
      // the deprecated onReorder.
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final moved = _parts.removeAt(oldIndex);
          _parts.insert(newIndex, moved);
        });
        widget.onReorder([for (final p in _parts) p.id]);
      },
      children: [
        for (final (index, part) in _parts.indexed)
          _PartTile(
            key: ValueKey(part.id),
            index: index,
            part: part,
            details: widget.detailsFor(part),
            dotColor: widget.dotColorFor(part),
            readOnly: widget.readOnly,
            changed: widget.changed(part),
            onEditRole: () => widget.onEditRole(part),
            onReplace: () => widget.onReplace(part),
            onRemove: () => widget.onRemove(part),
          ),
      ],
    );
  }
}

class _PartTile extends StatelessWidget {
  final int index;
  final EquipmentComponent part;

  /// Brand and model, identifier and any tie-break, from the list's row
  /// labels; they follow the role so the row still says what the part does.
  final List<String> details;
  final Color dotColor;
  final bool readOnly;
  final bool changed;
  final VoidCallback onEditRole;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  const _PartTile({
    super.key,
    required this.index,
    required this.part,
    required this.details,
    required this.dotColor,
    required this.readOnly,
    this.changed = false,
    required this.onEditRole,
    required this.onReplace,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = part.component;
    final name = item?.name ?? part.componentEquipmentId;
    final type = item?.type ?? EquipmentType.other;
    final departed = item == null ? null : departedStatusOf(item);
    final subtitle = [_roleText(part, l10n), ...details].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Icon(
            item == null ? equipmentTypeIcon(type) : equipmentItemIcon(item),
          ),
          Icon(Icons.circle, size: 10, color: dotColor),
        ],
      ),
      title: changed
          ? Row(
              children: [
                Flexible(child: Text(name)),
                const SizedBox(width: 6),
                const RecordChangedDot(),
              ],
            )
          : Text(name),
      subtitle: Row(
        children: [
          // Wraps rather than truncating: beside four action icons a phone
          // row has room for little more than the role, and the identifier
          // after it is the detail that tells identical parts apart.
          Flexible(
            child: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          if (departed != null) ...[
            const SizedBox(width: 8),
            Text(
              departed.localizedName(l10n),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push('/equipment/${part.componentEquipmentId}'),
      trailing: readOnly
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.equipment_components_editRole,
                  onPressed: onEditRole,
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: l10n.equipment_components_replace,
                  onPressed: onReplace,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.equipment_components_remove,
                  onPressed: onRemove,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: l10n.equipment_components_reorder,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
              ],
            ),
    );
  }
}
