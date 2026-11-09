import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owner_sections.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_fold_summary.dart';
import 'package:submersion/features/equipment/presentation/utils/picker_group_folds.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_type_fold_header.dart';
import 'package:submersion/shared/widgets/collapsible_group_header.dart';
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

  /// Leave out the components of an assembly the picker also offers
  /// (#2514), since picking the assembly brings them, behind a switch that
  /// lists them again. Set by the callers that pick the gear a diver dives
  /// with, and by the trip's Gear tab, where a packed assembly takes its
  /// parts along. The cylinder pickers leave it off: they need a twinset's
  /// single tanks.
  final bool hideAssemblyParts;

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
    this.hideAssemblyParts = false,
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

  /// The open groups (issue #3364), worked out once when the picker first
  /// has gear: closed except where the ticks are, or the only group. Never
  /// saved; it lasts as long as the sheet.
  Set<String>? _open;

  /// Every group on screen, so a tap before [_open] is worked out starts
  /// from every group open, as drawn.
  Set<String> _shownGroups = const {};

  /// Groups the diver closed while the filter was on, when every group
  /// starts open. Dropped when the filter clears.
  Set<String> _closedWhileFiltered = const {};
  bool _wasFiltered = false;

  bool _isOpen(String key, {required bool filtered}) => filtered
      ? !_closedWhileFiltered.contains(key)
      : (_open?.contains(key) ?? true);

  void _toggleGroup(String key, {required bool filtered}) {
    Set<String> flip(Set<String> keys) =>
        keys.contains(key) ? ({...keys}..remove(key)) : {...keys, key};
    setState(() {
      if (filtered) {
        _closedWhileFiltered = flip(_closedWhileFiltered);
      } else {
        _open = flip(_open ?? _shownGroups);
      }
    });
  }

  /// "2 of 8 selected" for a closed group holding ticks, so a tick is never
  /// hidden without a trace.
  String? _tickSummary(BuildContext context, List<EquipmentItem> items) {
    if (!_multiSelect) return null;
    final ticked = tickedIn(items.map((e) => e.id), _picked.keys.toSet());
    return ticked == 0
        ? null
        : foldedSelectionSummary(
            context.l10n,
            selected: ticked,
            total: items.length,
          );
  }

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
    // Components of an assembly the picker offers wait behind a switch
    // (#2514). Until the index loads, or if it fails, nothing is hidden.
    final componentsAsync = widget.hideAssemblyParts
        ? ref.watch(equipmentComponentsIndexProvider)
        : null;
    final components = componentsAsync == null || componentsAsync.hasError
        ? ComponentsIndex.empty
        : componentsAsync.value ?? ComponentsIndex.empty;
    final showParts =
        widget.hideAssemblyParts &&
        ref.watch(equipmentPickerShowAssemblyPartsProvider);
    final callerOffered = widget
        ._callerAllowed(
          (equipmentAsync.value ?? const <EquipmentItem>[]).where(
            (e) => !selectedEquipmentIds.contains(e.id),
          ),
        )
        .toList();
    final partIds = assemblyPartsAmong(
      components,
      callerOffered,
      attached: selectedEquipmentIds,
    );
    final hiddenPartIds = showParts ? const <String>{} : partIds;
    // What the list can show before the diver's own filter, and what the
    // filter sheet derives its chips from, so no chip matches only hidden
    // parts.
    final offerable = [
      for (final e in callerOffered)
        if (!hiddenPartIds.contains(e.id)) e,
    ];
    // As with left-kit gear: only when it would bring back a row the list
    // then shows, or to switch it back.
    final offersPartsSwitch =
        showParts ||
        filter.apply([
          for (final e in callerOffered)
            if (partIds.contains(e.id)) e,
        ]).isNotEmpty;
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
        onPressed: () => _showFilter(context, ref, offerable),
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
        if (offersPartsSwitch)
          SwitchListTile(
            key: const Key('equipment-picker-show-assembly-parts'),
            dense: true,
            title: Text(context.l10n.diveLog_equipmentPicker_showAssemblyParts),
            value: showParts,
            onChanged: (value) =>
                ref
                        .read(equipmentPickerShowAssemblyPartsProvider.notifier)
                        .state =
                    value,
          ),
        const Divider(height: 1),
        Expanded(
          child: equipmentAsync.when(
            data: (equipmentList) {
              // Three narrowings, kept separate because each empties the list
              // for a different reason and the diver deserves to be told
              // which: gear already on the dive (unselected), the caller's
              // own constraints (the transmitter registry offers cylinders
              // only, dive pickers hide spare gear and the components of
              // offered assemblies), and finally the filter the diver chose.
              // The first two make offerable, built in build() so the filter
              // sheet shares it; this builder applies the third.
              final unselected = equipmentList
                  .where((e) => !selectedEquipmentIds.contains(e.id))
                  .toList();
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

              // Likewise when what the diver's filter would show is only
              // components of an assembly the list offers (#2514): the whole
              // filter, so this names only rows the switch above brings
              // back. Checked before Spare: the switch fixes it on the spot,
              // while Spare gear needs a trip to the item.
              final onlyPartsLeft = filter.apply([
                for (final e in unselected)
                  if (hiddenPartIds.contains(e.id)) e,
              ]).isNotEmpty;

              if (available.isEmpty) {
                return _EmptyState(
                  message: equipmentList.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_noEquipment
                      : unselected.isEmpty
                      ? context.l10n.diveLog_equipmentPicker_allSelected
                      : onlyPartsLeft
                      ? context.l10n.diveLog_equipmentPicker_allAssemblyParts
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
                      : onlySpareLeft && !onlyPartsLeft
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
              // Folding (issue #3364): each owner's shared gear is an outer
              // group, types are groups of their own inside it or at the
              // top level. While the filter is on, every group is open.
              final filtered = filter.hasActiveFilters;
              if (_wasFiltered && !filtered) _closedWhileFiltered = const {};
              _wasFiltered = filtered;
              final arranged = [
                for (final section in sections)
                  (
                    section: section,
                    ownerKey: section.ownerId == null
                        ? null
                        : ownerFoldKey(section.ownerId!),
                    groups: arrangeEquipment(
                      section.items,
                      arrangement,
                      typeLabel: (type) => type.localizedName(context.l10n),
                    ),
                  ),
              ];
              // Worked out once the parts index has settled: before it, parts
              // still listed could make one group look like several.
              _shownGroups = {
                for (final a in arranged) ...{
                  ?a.ownerKey,
                  for (final group in a.groups)
                    if (group.type case final type?)
                      typeFoldKey(type, parentKey: a.ownerKey),
                },
              };
              final indexSettled =
                  componentsAsync == null ||
                  componentsAsync.hasValue ||
                  componentsAsync.hasError;
              if (_open == null && available.isNotEmpty && indexSettled) {
                _open = initialOpenPickerGroups(
                  {
                    for (final a in arranged) ...{
                      ?a.ownerKey: a.section.items.map((e) => e.id),
                      for (final group in a.groups)
                        if (group.type case final type?)
                          typeFoldKey(type, parentKey: a.ownerKey): group.items
                              .map((e) => e.id),
                    },
                  },
                  _picked.keys.toSet(),
                  containers: {for (final a in arranged) ?a.ownerKey},
                );
              }
              bool isOpen(String key) => _isOpen(key, filtered: filtered);
              final rows = <_PickerRow>[
                for (final (i, a) in arranged.indexed) ...[
                  if (a.section.ownerId != null &&
                      (i == 0 || arranged[i - 1].section.ownerId == null))
                    _SectionRow(context.l10n.equipment_sharedWithMe),
                  if (a.ownerKey case final owner?)
                    _OwnerHeaderRow(
                      foldKey: owner,
                      title: context.l10n.equipment_picker_ownerHeader(
                        ownerName(a.section.ownerId!),
                      ),
                      items: a.section.items,
                      isOpen: isOpen(owner),
                    ),
                  if (a.ownerKey == null || isOpen(a.ownerKey!))
                    for (final group in a.groups)
                      if (group.type case final type?) ...[
                        _HeaderRow(
                          type,
                          foldKey: typeFoldKey(type, parentKey: a.ownerKey),
                          nested: a.ownerKey != null,
                          items: group.items,
                          isOpen: isOpen(
                            typeFoldKey(type, parentKey: a.ownerKey),
                          ),
                        ),
                        if (isOpen(typeFoldKey(type, parentKey: a.ownerKey)))
                          for (final equipment in group.items)
                            _ItemRow(equipment, showTypeLabel: false),
                      ] else
                        for (final equipment in group.items)
                          _ItemRow(equipment, showTypeLabel: true),
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
                  _OwnerHeaderRow(
                    :final foldKey,
                    :final title,
                    :final items,
                    :final isOpen,
                  ) =>
                    CollapsibleGroupHeader(
                      key: ValueKey('equipment-owner-fold-$foldKey'),
                      label: title,
                      countLabel: context.l10n.equipment_location_groupCount(
                        items.length,
                      ),
                      isExpanded: isOpen,
                      onTap: () => _toggleGroup(foldKey, filtered: filtered),
                      summary: _tickSummary(context, items),
                      titleWeight: FontWeight.w700,
                      isHeading: true,
                    ),
                  _HeaderRow(
                    :final type,
                    :final foldKey,
                    :final nested,
                    :final items,
                    :final isOpen,
                  ) =>
                    EquipmentTypeFoldHeader(
                      foldKey: foldKey,
                      type: type,
                      count: items.length,
                      isExpanded: isOpen,
                      nested: nested,
                      onTap: () => _toggleGroup(foldKey, filtered: filtered),
                      summary: _tickSummary(context, items),
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
  ///
  /// [selectable] is what the picker can actually show: gear already on the
  /// dive is excluded, and so is anything the caller's own constraints or
  /// the hidden assembly parts rule out. Deriving the chips from the full
  /// active list would offer a chip (such as Spare, when hidden) that could
  /// only ever produce an empty list.
  Future<void> _showFilter(
    BuildContext context,
    WidgetRef ref,
    List<EquipmentItem> selectable,
  ) async {
    final current = ref.read(equipmentPickerFilterProvider);
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

/// One owner's shared gear, folding as a group with its types inside
/// (issue #3364).
class _OwnerHeaderRow extends _PickerRow {
  const _OwnerHeaderRow({
    required this.foldKey,
    required this.title,
    required this.items,
    required this.isOpen,
  });

  final String foldKey;
  final String title;
  final List<EquipmentItem> items;
  final bool isOpen;
}

class _HeaderRow extends _PickerRow {
  const _HeaderRow(
    this.type, {
    required this.foldKey,
    required this.nested,
    required this.items,
    required this.isOpen,
  });

  final EquipmentType type;
  final String foldKey;

  /// Inside an owner's group, so indented under it.
  final bool nested;
  final List<EquipmentItem> items;
  final bool isOpen;
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
