part of 'equipment_picker_sheet.dart';

/// The picker's folds (issue #3364): each owner's shared gear is an outer
/// group, types are groups of their own inside it or at the top level.
/// Closed at open except where the ticks are, or the only group of gear;
/// every group open while the filter is on. Never saved.
mixin _PickerFolds on ConsumerState<EquipmentPickerSheet> {
  Map<String, EquipmentItem> get _picked;
  bool get _multiSelect;

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

  /// The picker's rows: section labels, foldable owner and type headings,
  /// and the items of every open group.
  List<_PickerRow> _pickerRows(
    BuildContext context, {
    required List<OwnerSection> sections,
    required EquipmentArrangement arrangement,
    required List<EquipmentItem> available,
    required bool filtered,
    required bool indexSettled,
    required String Function(String ownerId) ownerName,
  }) {
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
    if (_open == null && available.isNotEmpty && indexSettled) {
      _open = initialOpenPickerGroups(
        {
          for (final a in arranged) ...{
            ?a.ownerKey: a.section.items.map((e) => e.id),
            for (final group in a.groups)
              if (group.type case final type?)
                typeFoldKey(type, parentKey: a.ownerKey): group.items.map(
                  (e) => e.id,
                ),
          },
        },
        _picked.keys.toSet(),
        containers: {for (final a in arranged) ?a.ownerKey},
      );
    }
    bool isOpen(String key) => _isOpen(key, filtered: filtered);
    return [
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
                isOpen: isOpen(typeFoldKey(type, parentKey: a.ownerKey)),
              ),
              if (isOpen(typeFoldKey(type, parentKey: a.ownerKey)))
                for (final equipment in group.items)
                  _ItemRow(equipment, showTypeLabel: false),
            ] else
              for (final equipment in group.items)
                _ItemRow(equipment, showTypeLabel: true),
      ],
    ];
  }

  /// The heading for an owner's or a type's group row.
  Widget _foldHeader(
    BuildContext context,
    _PickerRow row, {
    required bool filtered,
  }) => switch (row) {
    _OwnerHeaderRow(
      :final foldKey,
      :final title,
      :final items,
      :final isOpen,
    ) =>
      CollapsibleGroupHeader(
        key: ValueKey('equipment-owner-fold-$foldKey'),
        label: title,
        countLabel: context.l10n.equipment_location_groupCount(items.length),
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
    _ => throw ArgumentError.value(row, 'row', 'not a group heading'),
  };
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
