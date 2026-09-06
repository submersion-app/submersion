import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';

/// Open the equipment filter panel.
///
/// Every layout routes through here, so the three top-bar icons (phone app
/// bar, master-detail compact bar, table mode) cannot drift apart.
Future<void> showEquipmentFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EquipmentFilterSheet(ref: ref),
  );
}

/// Bottom sheet for filtering the equipment list by status and category.
///
/// Edits a local draft so nothing moves under the diver while they choose;
/// [equipmentFilterProvider] is written only on Apply, the same contract the
/// dive and site filter sheets use.
class EquipmentFilterSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const EquipmentFilterSheet({super.key, required this.ref});

  @override
  ConsumerState<EquipmentFilterSheet> createState() =>
      _EquipmentFilterSheetState();
}

class _EquipmentFilterSheetState extends ConsumerState<EquipmentFilterSheet> {
  // Local draft, mirroring EquipmentFilterState.
  EquipmentStatus? _status;
  bool _serviceDueOnly = false;
  EquipmentType? _type;

  @override
  void initState() {
    super.initState();
    final filter = widget.ref.read(equipmentFilterProvider);
    _status = filter.status;
    _serviceDueOnly = filter.serviceDueOnly;
    _type = filter.type;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.equipment_filter_title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: _clearAll,
                        child: Text(context.l10n.equipment_filter_clearAll),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatusSection(),
                      const SizedBox(height: 24),
                      _buildCategorySection(),
                    ],
                  ),
                ),
                // Outside the ListView: as lazy children the actions were
                // never built on desktop and looked clipped (#989).
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(context.l10n.equipment_filter_cancel),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('equipment_filter_apply'),
                          onPressed: _applyFilters,
                          child: Text(context.l10n.equipment_filter_apply),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The status axis: a single choice, so the chips behave like radio buttons
  /// -- the list can only read one provider.
  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.equipment_filter_section_status,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('equipment_filter_status_all'),
              label: Text(context.l10n.equipment_list_filterAll),
              selected: _status == null && !_serviceDueOnly,
              onSelected: (_) => setState(() {
                _status = null;
                _serviceDueOnly = false;
              }),
            ),
            ChoiceChip(
              key: const ValueKey('equipment_filter_status_serviceDue'),
              label: Text(context.l10n.equipment_list_filterServiceDue),
              selected: _serviceDueOnly,
              onSelected: (selected) => setState(() {
                _serviceDueOnly = selected;
                if (selected) _status = null;
              }),
            ),
            // needsService is excluded: the computed Service Due choice above
            // is what divers actually mean by it.
            for (final status in EquipmentStatus.values.where(
              (s) => s != EquipmentStatus.needsService,
            ))
              ChoiceChip(
                key: ValueKey('equipment_filter_status_${status.name}'),
                label: Text(status.localizedName(context.l10n)),
                selected: _status == status,
                onSelected: (selected) => setState(() {
                  _status = selected ? status : null;
                  if (selected) _serviceDueOnly = false;
                }),
              ),
          ],
        ),
      ],
    );
  }

  /// The category axis (#1274). Only categories the diver owns are offered,
  /// plus the current selection even if the gear behind it is gone, so the
  /// filter is always clearable from here.
  Widget _buildCategorySection() {
    final owned = ref.watch(ownedEquipmentTypesProvider);
    final types = EquipmentType.values
        .where((t) => owned.contains(t) || t == _type)
        .toList();

    if (types.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.equipment_filter_section_category,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('equipment_filter_type_all'),
              label: Text(context.l10n.equipment_list_typeFilterAll),
              selected: _type == null,
              onSelected: (_) => setState(() => _type = null),
            ),
            for (final type in types)
              ChoiceChip(
                key: ValueKey('equipment_filter_type_${type.name}'),
                avatar: Icon(equipmentTypeIcon(type), size: 18),
                label: Text(type.localizedName(context.l10n)),
                selected: _type == type,
                onSelected: (selected) =>
                    setState(() => _type = selected ? type : null),
              ),
          ],
        ),
      ],
    );
  }

  /// Clears the draft only; the list stays as it is until Apply.
  void _clearAll() {
    setState(() {
      _status = null;
      _serviceDueOnly = false;
      _type = null;
    });
  }

  void _applyFilters() {
    widget.ref
        .read(equipmentFilterProvider.notifier)
        .state = EquipmentFilterState(
      status: _status,
      serviceDueOnly: _serviceDueOnly,
      type: _type,
    );
    Navigator.of(context).pop();
  }
}
