import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owner_sections.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_owner_chip.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_picker_filter_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/max_width_fraction.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/picker_header_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/shared_gear_note_line.dart';

/// Equipment picker bottom sheet.
///
/// Single-select with [onEquipmentSelected]: tapping a row picks it. With
/// [onEquipmentConfirmed] it is multi-select instead (issue #2175): every
/// row has a checkbox, as in the add-components sheet, and nothing reaches
/// the caller until Add is pressed.
class EquipmentPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final Set<String> selectedEquipmentIds;

  /// When set, only gear of this type is offered (the transmitter registry
  /// editor lists cylinders only).
  final EquipmentType? typeFilter;

  /// Leave out [EquipmentStatus.spare] gear (#1803). Set by the callers that
  /// pick the gear a diver dives with (dive edit, bulk edit, the planner,
  /// the weight rig), where a shelf of spare hoses and O-rings would only
  /// bury the gear actually worn. The transmitter registry leaves it off.
  final bool hideSpare;

  /// Offer a switch that adds retired and sold gear (#3210). Set by the
  /// callers that log what a dive used, where a dive entered after the fact
  /// may well have used gear since retired. The planner, trips and the
  /// weight rig look ahead and leave it off.
  final bool offerLeftKit;

  /// Called with the row that was tapped. The caller closes the sheet.
  final void Function(EquipmentItem)? onEquipmentSelected;

  /// Makes the sheet multi-select (issue #2175): called with every ticked
  /// item, in the order ticked, when Add is pressed. The caller closes the
  /// sheet. Cancel closes it without calling this.
  final void Function(List<EquipmentItem>)? onEquipmentConfirmed;

  /// Replaces the default "Select Equipment" title, for a caller whose pick
  /// means something more specific (filling a tank from a cylinder).
  final String? title;

  /// A line under the header saying what picking does, when that is not
  /// simply "add it to the dive".
  final String? hint;

  /// A note per item that is also on another profile's overlapping dive
  /// (issue #2853). Only the dive editor passes it.
  final String? Function(String equipmentId)? overlapNote;

  const EquipmentPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedEquipmentIds,
    this.typeFilter,
    this.hideSpare = false,
    this.offerLeftKit = false,
    this.onEquipmentSelected,
    this.onEquipmentConfirmed,
    this.title,
    this.hint,
    this.overlapNote,
  }) : assert(
         (onEquipmentSelected == null) != (onEquipmentConfirmed == null),
         'Pass onEquipmentSelected or onEquipmentConfirmed, not both',
       );

  /// The caller's own constraints on what may be offered, before the
  /// diver's filter: the [typeFilter] and [hideSpare].
  Iterable<EquipmentItem> _callerAllowed(Iterable<EquipmentItem> equipment) =>
      equipment
          .where((e) => typeFilter == null || e.type == typeFilter)
          .where((e) => !hideSpare || e.status != EquipmentStatus.spare);

  @override
  ConsumerState<EquipmentPickerSheet> createState() =>
      _EquipmentPickerSheetState();
}

class _EquipmentPickerSheetState extends ConsumerState<EquipmentPickerSheet> {
  /// The ticked items by id, in the order ticked. Kept as items, not ids, so
  /// a tick outlives its row being filtered out of the list.
  Map<String, EquipmentItem> _picked = const {};

  bool get _multiSelect => widget.onEquipmentConfirmed != null;

  void _toggle(EquipmentItem item, bool checked) {
    setState(() {
      _picked = checked
          ? {..._picked, item.id: item}
          : {
              for (final entry in _picked.entries)
                if (entry.key != item.id) entry.key: entry.value,
            };
    });
  }

  /// One gear row: tap to pick, or a checkbox to tick when multi-select.
  Widget _itemTile(BuildContext context, EquipmentItem item, Widget? subtitle) {
    final avatar = CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        equipmentTypeIcon(item.type),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    if (_multiSelect) {
      return CheckboxListTile(
        value: _picked.containsKey(item.id),
        onChanged: (value) => _toggle(item, value == true),
        secondary: avatar,
        title: Text(item.name),
        subtitle: subtitle,
        controlAffinity: ListTileControlAffinity.trailing,
      );
    }
    return ListTile(
      leading: avatar,
      title: Text(item.name),
      subtitle: subtitle,
      // Capped so a rollup label naming a long part cannot take the row
      // from the title (issue #1981).
      trailing: MaxWidthFraction(
        fraction: kListTileTrailingMaxWidthFraction,
        child: ServiceStatusIndicatorFor(
          equipmentId: item.id,
          density: ServiceIndicatorDensity.compact,
        ),
      ),
      onTap: () => widget.onEquipmentSelected!(item),
    );
  }

  /// The type name leads when there is no type heading to say it, then the
  /// details that tell this item from its neighbours.
  Widget? _subtitle(
    BuildContext context,
    List<String> parts,
    EquipmentItem item, {
    required bool showTypeLabel,
    required bool showOwner,
  }) {
    final overlapNote = widget.overlapNote;
    final all = [
      if (showTypeLabel) item.type.localizedName(context.l10n),
      // Sold, Lost or Retired, as the equipment badges read it.
      if (item.hasLeftKit) item.effectiveStatus.localizedName(context.l10n),
      ...parts,
    ];
    final text = all.isEmpty ? null : Text(all.join(' · '));
    final note = overlapNote?.call(item.id);
    if (!showOwner && note == null && !_multiSelect) return text;
    // Another profile's shared gear names its owner (issue #2046). Below the
    // text, as on the equipment list, so the width-capped trailing column
    // keeps only the service indicator (issue #1981).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?text,
        // The checkbox has the trailing slot, so the service status sits
        // under the name, as in the add-components sheet.
        if (_multiSelect)
          ServiceStatusIndicatorFor(
            equipmentId: item.id,
            density: ServiceIndicatorDensity.compact,
          ),
        if (showOwner)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: EquipmentOwnerChip(ownerId: item.diverId),
          ),
        if (note != null)
          SharedGearNoteLine(
            note,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEquipmentIds = widget.selectedEquipmentIds;
    final offerLeftKit = widget.offerLeftKit;
    final hideSpare = widget.hideSpare;
    final typeFilter = widget.typeFilter;
    // Active gear by default; retired items are reachable from the
    // Equipment page's Retired filter (#636), and from here through the
    // left-kit switch when the caller offers it (#3210).
    final activeAsync = ref.watch(activeEquipmentProvider);
    // Retired and sold gear joins only on request (#3210); arranging sorts
    // the combined list, so appending it is enough.
    final leftKit = offerLeftKit
        ? ref.watch(leftKitEquipmentProvider).value ?? const <EquipmentItem>[]
        : const <EquipmentItem>[];
    final showLeftKit =
        offerLeftKit && ref.watch(equipmentPickerShowLeftKitProvider);
    final equipmentAsync = showLeftKit
        ? activeAsync.whenData((active) => [...active, ...leftKit])
        : activeAsync;
    final arrangement = ref.watch(equipmentArrangementProvider);
    final filter = ref.watch(equipmentPickerFilterProvider);
    // The switch only when it would add something the list then shows,
    // after the diver's own filter too, or to switch it back.
    final offersLeftKitSwitch =
        showLeftKit ||
        filter
            .apply(
              widget
                  ._callerAllowed(
                    leftKit.where((e) => !selectedEquipmentIds.contains(e.id)),
                  )
                  .toList(),
            )
            .isNotEmpty;
    // Shared gear (issue #2046) gets its own section and an owner chip.
    final multipleDivers = ref.watch(hasMultipleDiversProvider);
    final activeDiverId = ref.watch(validatedCurrentDiverIdProvider).value;
    final names = ref.watch(diverNamesByIdProvider).value ?? const {};

    final listControls = [
      IconButton(
        icon: Badge(
          // Only when something is narrowed, so the diver can see at a
          // glance why gear they own is missing from the list.
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
    ];

    final title = Text(
      widget.title ?? context.l10n.diveLog_equipmentPicker_title,
      style: Theme.of(context).textTheme.titleLarge,
      // Cancel and Add leave the title less room than the close icon does,
      // so it wraps before it is cut short.
      maxLines: _multiSelect ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _multiSelect
              // Filter and sort share the title row when the title fits
              // beside them, and drop below Cancel and Add when it does not.
              ? PickerHeaderLayout(
                  title: title,
                  listControls: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: listControls,
                  ),
                  actions: _ConfirmButtons(
                    count: _picked.length,
                    onConfirm: () =>
                        widget.onEquipmentConfirmed!(_picked.values.toList()),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flexible with an ellipsis: three icon buttons take a
                    // fixed ~144dp, and an inflexible title overflowed a 320dp
                    // phone by 362px in French, whose title is 23 characters.
                    Flexible(child: title),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...listControls,
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
        if (widget.hint case final hint?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (offersLeftKitSwitch)
          SwitchListTile(
            key: const Key('equipment-picker-show-left-kit'),
            dense: true,
            title: Text(context.l10n.diveLog_equipmentPicker_showLeftKit),
            value: showLeftKit,
            onChanged: (value) =>
                ref.read(equipmentPickerShowLeftKitProvider.notifier).state =
                    value,
          ),
        const Divider(height: 1),
        Expanded(
          child: equipmentAsync.when(
            data: (equipmentList) {
              // Three narrowings, kept separate because each empties the list
              // for a different reason and the diver deserves to be told
              // which: gear already on the dive, the caller's own constraints
              // (the transmitter registry offers cylinders only, dive pickers
              // hide spare gear), and finally the filter the diver chose.
              final unselected = equipmentList
                  .where((e) => !selectedEquipmentIds.contains(e.id))
                  .toList();
              final offerable = widget._callerAllowed(unselected).toList();
              final available = filter.apply(offerable);

              // Which axis to blame when nothing is left. Applying the type
              // axis alone says whether the category really holds nothing:
              // if it does hold something, the status axis is what emptied
              // the list and blaming the category would be a lie. This also
              // covers the caller's own typeFilter, since offerable is
              // already narrowed by it.
              final typeFilterOnly = EquipmentPickerFilter(type: filter.type);
              final typeMatches = typeFilterOnly.apply(offerable);

              // True when the only gear left in the chosen category (or in
              // the whole picker, with no category chosen) is spare, so the
              // empty state points at the status rather than claiming the
              // diver owns nothing, has added everything, or has no gear of
              // that type.
              final onlySpareLeft =
                  hideSpare &&
                  typeMatches.isEmpty &&
                  typeFilterOnly
                      .apply(unselected)
                      .any(
                        (e) =>
                            e.status == EquipmentStatus.spare &&
                            (typeFilter == null || e.type == typeFilter),
                      );

              if (available.isEmpty) {
                return _EmptyState(
                  message: equipmentList.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_noEquipment
                      : unselected.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_allSelected
                      : onlySpareLeft
                      ? context.l10n.diveLog_equipmentPicker_allSpare
                      : typeMatches.isEmpty
                      ? context.l10n.equipment_list_emptyState_noTypeMatch
                      : context.l10n.equipment_list_emptyState_noStatusMatch,
                  // With retired or sold gear behind the switch above, the
                  // switch is the way forward, not adding or removing gear
                  // (#3210).
                  hint: offersLeftKitSwitch && !showLeftKit
                      ? null
                      : equipmentList.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_addFromTab
                      : unselected.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_removeToAdd
                      : onlySpareLeft
                      ? context.l10n.diveLog_equipmentPicker_spareHint
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
              // Labelled as one list, because telling identical items apart
              // means comparing the rows the diver is looking at (#1549).
              final labels = equipmentRowLabelsOf(context, ref, available);
              // The diver's own gear first, then what other profiles share
              // with it, one section per owner (issue #2046).
              String ownerName(String id) =>
                  names[id] ?? context.l10n.equipment_owner_unknown;
              final sections = multipleDivers
                  ? sectionsByOwner(
                      available,
                      activeDiverId: activeDiverId,
                      ownerName: ownerName,
                    )
                  : [(ownerId: null, items: available)];
              final rows = <_PickerRow>[
                for (final (i, section) in sections.indexed) ...[
                  if (section.ownerId != null &&
                      (i == 0 || sections[i - 1].ownerId == null))
                    _SectionRow(context.l10n.equipment_sharedWithMe),
                  if (section.ownerId case final owner?)
                    _SectionRow(
                      context.l10n.equipment_picker_ownerHeader(
                        ownerName(owner),
                      ),
                    ),
                  for (final group in arrangeEquipment(
                    section.items,
                    arrangement,
                    typeLabel: (type) => type.localizedName(context.l10n),
                  )) ...[
                    if (group.type != null) _HeaderRow(group.type!),
                    for (final equipment in group.items)
                      _ItemRow(equipment, showTypeLabel: group.type == null),
                  ],
                ],
              ];

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: rows.length,
                itemBuilder: (context, index) => switch (rows[index]) {
                  _SectionRow(:final title) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  _HeaderRow(:final type) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: EquipmentGroupHeader(type: type),
                  ),
                  _ItemRow(:final item, :final showTypeLabel) => _itemTile(
                    context,
                    item,
                    _subtitle(
                      context,
                      labels[item.id]?.subtitleParts ?? const [],
                      item,
                      showTypeLabel: showTypeLabel,
                      showOwner: showsOwnerChip(
                        item,
                        activeDiverId,
                        multipleDivers: multipleDivers,
                      ),
                    ),
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
    // dive is excluded, and so is anything the caller's own constraints rule
    // out. Deriving them from the full active list would offer a chip (such
    // as Spare, when hidden) that could only ever produce an empty list.
    final selectable = widget
        ._callerAllowed(
          equipment.where((e) => !widget.selectedEquipmentIds.contains(e.id)),
        )
        .toList();
    final presentTypes = selectable.map((e) => e.type).toSet();
    // The status each row reads, as the filter matches it (#3210).
    final presentStatuses = selectable.map((e) => e.effectiveStatus).toSet();

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

/// Cancel and "Add N", the multi-select header's buttons (issue #2175).
class _ConfirmButtons extends StatelessWidget {
  const _ConfirmButtons({required this.count, required this.onConfirm});

  /// How many items are ticked; Add is disabled at zero.
  final int count;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    // The header never offers more than its own width, so a long
    // translation at a large text size shrinks the pair rather than
    // overflowing it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_action_cancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: count == 0 ? null : onConfirm,
            child: Text(context.l10n.equipment_components_pickerConfirm(count)),
          ),
        ],
      ),
    );
  }
}

/// One row of the picker list, as data rather than a built widget so the
/// list stays lazy.
sealed class _PickerRow {
  const _PickerRow();
}

/// A section title: "Shared with me", or one owner's name (issue #2046).
class _SectionRow extends _PickerRow {
  const _SectionRow(this.title);

  final String title;
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
