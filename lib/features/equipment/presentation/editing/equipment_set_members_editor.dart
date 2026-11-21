import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/widgets/foldable_type_group_rows.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_equipment_checkbox_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// What the set page shows as the gear [shown] applies: the stored set's
/// own items when [shown] is it and was read with them, else the gear as a
/// sitting has it ([setItemsInSitting]), once the diver's gear and sets have
/// loaded.
List<EquipmentItem>? setItemsShown(
  WidgetRef ref,
  EquipmentSet shown,
  EquipmentSet stored,
) => identical(shown, stored) && stored.items != null
    ? stored.items
    : setItemsShownFrom(
        shown,
        stored,
        // The last read held through a reload, so a sitting does not
        // fall back to the stored gear meanwhile.
        every: ref.watch(allEquipmentProvider).value,
        sets: ref.watch(equipmentSetsProvider).value,
      );

/// [setItemsShown] from the diver's gear ([every]) and sets ([sets]) as
/// already read: [stored]'s items until both have loaded.
List<EquipmentItem>? setItemsShownFrom(
  EquipmentSet shown,
  EquipmentSet stored, {
  required List<EquipmentItem>? every,
  required List<EquipmentSet>? sets,
}) {
  final items = stored.items;
  if ((identical(shown, stored) && items != null) ||
      every == null ||
      sets == null) {
    return items;
  }
  return setItemsInSitting(
    shown,
    storedItems: items ?? const [],
    everyItem: every,
    allSets: sets,
  );
}

/// The Members card's editor (issue #4527, phase 3): the diver's active
/// gear grouped by type, folding, each a checkbox, as the set form listed it
/// (Call 3). An assembly's parts wait behind a switch unless ticked or
/// touched (#2514); members no longer shared stay, listed without a
/// checkbox (#2046). The Figure card above is the live figure, so the rows
/// carry no numbers.
class EquipmentSetMembersEditor extends ConsumerStatefulWidget {
  const EquipmentSetMembersEditor({super.key, required this.session});

  final EditSession<EquipmentSet> session;

  @override
  ConsumerState<EquipmentSetMembersEditor> createState() =>
      _EquipmentSetMembersEditorState();
}

class _EquipmentSetMembersEditorState
    extends ConsumerState<EquipmentSetMembersEditor>
    with FoldableTypeGroupsState<EquipmentSetMembersEditor> {
  EditSession<EquipmentSet> get _session => widget.session;

  /// Whether the list also shows the parts of the assemblies it lists.
  bool _showParts = false;

  /// Rows ticked or unticked here, which stay listed so a tick can be undone
  /// in place.
  Set<String> _touchedIds = const {};

  // The editor rebuilds itself on each change to the sitting, so every
  // provider it reads is read in its own build.
  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
  }

  @override
  void didUpdateWidget(EquipmentSetMembersEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      oldWidget.session.removeListener(_onSessionChanged);
      widget.session.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ticked = _session.working.equipmentIds.toSet();
    return ref
        .watch(activeEquipmentProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(l10n.equipment_setEdit_errorMessage('$error')),
          ),
          data: (equipment) => _buildList(context, equipment, ticked),
        );
  }

  Widget _buildList(
    BuildContext context,
    List<EquipmentItem> equipment,
    Set<String> ticked,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Members the diver can no longer see stay, without a checkbox.
    final visibleIds = ref
        .watch(allEquipmentProvider)
        .value
        ?.map((e) => e.id)
        .toSet();
    final unshared = unsharedSetMembers(_session.stored, visibleIds);
    if (equipment.isEmpty && unshared.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              l10n.equipment_setEdit_noEquipmentAvailable,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.equipment_setEdit_addEquipmentFirst,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final componentsAsync = ref.watch(equipmentComponentsIndexProvider);
    final components = componentsAsync.hasError
        ? ComponentsIndex.empty
        : componentsAsync.value;
    final partIds = assemblyPartsAmong(
      components ?? ComponentsIndex.empty,
      equipment,
    ).difference({...ticked, ..._touchedIds});
    final listed = _showParts
        ? equipment
        : [
            for (final e in equipment)
              if (!partIds.contains(e.id)) e,
          ];
    final groups = arrangeEquipment(
      listed,
      ref.watch(equipmentArrangementProvider),
      typeLabel: (type) => type.localizedName(l10n),
    );
    final labels = equipmentRowLabelsOf(context, ref, listed);
    final typeGroups = [for (final group in groups) (group.type, group.items)];
    ensureOpenTypeGroups(typeGroups, ticked);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.equipment_setEdit_selectEquipmentSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_showParts || partIds.isNotEmpty)
          SwitchListTile(
            key: const Key('set-edit-show-assembly-parts'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.diveLog_equipmentPicker_showAssemblyParts),
            value: _showParts,
            onChanged: (v) => setState(() => _showParts = v),
          ),
        if (unshared.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                for (final item in unshared)
                  ListTile(
                    enabled: false,
                    title: Text(item.name),
                    subtitle: Text(l10n.equipment_set_noLongerShared),
                  ),
              ],
            ),
          ),
        ...foldableTypeGroupRows(
          context,
          groups: typeGroups,
          open: openTypeGroups,
          ticked: ticked,
          onToggle: toggleTypeGroup,
          rowBuilder: (item) => SetEquipmentCheckboxRow(
            item: item,
            detail: labels[item.id]?.subtitle,
            isSelected: ticked.contains(item.id),
            number: null,
            badgeSlot: null,
            flashing: false,
            onBadgeTap: () {},
            onChanged: (value) {
              setState(() => _touchedIds = {..._touchedIds, item.id});
              _session.set(
                setMembersField,
                membersTicked(_session, item.id, value ?? false),
              );
            },
          ),
        ),
      ],
    );
  }
}
