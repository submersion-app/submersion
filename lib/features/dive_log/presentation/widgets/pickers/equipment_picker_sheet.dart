import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_picker_filter_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Equipment picker bottom sheet
class EquipmentPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final Set<String> selectedEquipmentIds;

  /// When set, only gear of this type is offered (the transmitter registry
  /// editor lists cylinders only).
  final EquipmentType? typeFilter;
  final void Function(EquipmentItem) onEquipmentSelected;

  const EquipmentPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedEquipmentIds,
    this.typeFilter,
    required this.onEquipmentSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only active gear belongs in the dive-edit picker; retired items are
    // reachable from the Equipment page's Retired filter (#636).
    final equipmentAsync = ref.watch(activeEquipmentProvider);
    final arrangement = ref.watch(equipmentArrangementProvider);
    final filter = ref.watch(equipmentPickerFilterProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible with an ellipsis: three icon buttons take a fixed
              // ~144dp, and an inflexible title overflowed a 320dp phone by
              // 362px in French, whose title is 23 characters.
              Flexible(
                child: Text(
                  context.l10n.diveLog_equipmentPicker_title,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Badge(
                      // Only when something is narrowed, so the diver can see
                      // at a glance why gear they own is missing from the list.
                      isLabelVisible: filter.hasActiveFilters,
                      child: const Icon(Icons.filter_list),
                    ),
                    tooltip: context.l10n.equipment_filter_title,
                    onPressed: () => _showFilter(
                      context,
                      ref,
                      equipmentAsync.value ?? const <EquipmentItem>[],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sort),
                    tooltip: context.l10n.equipment_list_sortTooltip,
                    onPressed: () => showEquipmentArrangeSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.common_action_close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: equipmentAsync.when(
            data: (equipmentList) {
              // Three narrowings, kept separate because each empties the list
              // for a different reason and the diver deserves to be told
              // which: gear already on the dive, the caller's own constraint
              // (the transmitter registry offers cylinders only), and finally
              // the filter the diver chose.
              final unselected = equipmentList
                  .where((e) => !selectedEquipmentIds.contains(e.id))
                  .toList();
              final offerable = typeFilter == null
                  ? unselected
                  : unselected.where((e) => e.type == typeFilter).toList();
              final available = filter.apply(offerable);

              // Which axis to blame when nothing is left. Applying the type
              // axis alone says whether the category really holds nothing:
              // if it does hold something, the status axis is what emptied
              // the list and blaming the category would be a lie. This also
              // covers the caller's own typeFilter, since offerable is
              // already narrowed by it.
              final typeMatches = EquipmentPickerFilter(
                type: filter.type,
              ).apply(offerable);

              if (available.isEmpty) {
                return _EmptyState(
                  message: equipmentList.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_noEquipment
                      : unselected.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_allSelected
                      : typeMatches.isEmpty
                      ? context.l10n.equipment_list_emptyState_noTypeMatch
                      : context.l10n.equipment_list_emptyState_noStatusMatch,
                  hint: equipmentList.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_addFromTab
                      : unselected.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_removeToAdd
                      : null,
                  onClearFilter: filter.hasActiveFilters
                      ? () =>
                            ref
                                .read(equipmentPickerFilterProvider.notifier)
                                .state = EquipmentPickerFilter
                                .none
                      : null,
                );
              }

              // Filtering happens before arranging, so a type whose every
              // item is already on the dive (or filtered out) contributes no
              // empty heading.
              //
              // Rows are a lightweight data model, not widgets: a diver with a
              // large inventory is exactly who #1576 is about, and building
              // every ListTile up front would defeat ListView.builder's lazy
              // construction on open and on every filter or arrangement
              // change. Widgets are built in itemBuilder, so only visible rows
              // cost anything.
              final rows = <_PickerRow>[
                for (final group in arrangeEquipment(
                  available,
                  arrangement,
                  typeLabel: (type) => type.localizedName(context.l10n),
                )) ...[
                  if (group.type != null) _HeaderRow(group.type!),
                  for (final equipment in group.items)
                    _ItemRow(equipment, showTypeLabel: group.type == null),
                ],
              ];

              return ListView.builder(
                controller: scrollController,
                itemCount: rows.length,
                itemBuilder: (context, index) => switch (rows[index]) {
                  _HeaderRow(:final type) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EquipmentGroupHeader(type: type),
                  ),
                  _ItemRow(:final item, :final showTypeLabel) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        equipmentTypeIcon(item.type),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: showTypeLabel
                        ? Text(item.type.localizedName(context.l10n))
                        : null,
                    onTap: () => onEquipmentSelected(item),
                  ),
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                context.l10n.diveLog_equipmentPicker_errorLoading(
                  error.toString(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Offers only the types and statuses actually present in the picker, plus
  /// whatever is currently selected, so a filter is always clearable and no
  /// chip matches nothing.
  Future<void> _showFilter(
    BuildContext context,
    WidgetRef ref,
    List<EquipmentItem> equipment,
  ) async {
    final current = ref.read(equipmentPickerFilterProvider);
    // Derived from what the picker can actually show: gear already on the
    // dive is excluded, and so is anything the caller's own typeFilter
    // rules out. Deriving them from the full active list would offer a chip
    // that could only ever produce an empty list.
    final selectable = equipment
        .where((e) => !selectedEquipmentIds.contains(e.id))
        .where((e) => typeFilter == null || e.type == typeFilter)
        .toList();
    final presentTypes = selectable.map((e) => e.type).toSet();
    final presentStatuses = selectable.map((e) => e.status).toSet();

    final chosen = await showEquipmentPickerFilterSheet(
      context,
      current: current,
      availableTypes: EquipmentType.values
          .where((t) => presentTypes.contains(t) || t == current.type)
          .toList(),
      availableStatuses: EquipmentStatus.values
          .where((s) => presentStatuses.contains(s) || s == current.status)
          .toList(),
    );
    if (chosen == null) return;
    ref.read(equipmentPickerFilterProvider.notifier).state = chosen;
  }
}

/// One row of the picker list, as data rather than a built widget so the
/// list stays lazy.
sealed class _PickerRow {
  const _PickerRow();
}

class _HeaderRow extends _PickerRow {
  const _HeaderRow(this.type);

  final EquipmentType type;
}

class _ItemRow extends _PickerRow {
  const _ItemRow(this.item, {required this.showTypeLabel});

  final EquipmentItem item;

  /// Only when no heading names the type already.
  final bool showTypeLabel;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.hint, this.onClearFilter});

  final String message;
  final String? hint;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (onClearFilter != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClearFilter,
              child: Text(context.l10n.equipment_filter_clearAll),
            ),
          ],
        ],
      ),
    );
  }
}
