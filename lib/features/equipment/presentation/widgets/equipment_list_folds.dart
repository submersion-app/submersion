part of 'equipment_list_content.dart';

/// The Equipment list's folds (issue #4184): the reveal that keeps an item
/// opened from outside the list visible, Expand all and Collapse all, and
/// the outermost groups the menu offers to fold.
mixin _EquipmentListFolds on ConsumerState<EquipmentListContent> {
  /// The item a selection from outside the list's own rows opened (issue
  /// #4184): a deep link, a new item, the detail item restored at launch,
  /// or the item open when a filter clears. Every build opens the folds
  /// hiding it, so folds or places that land later cannot hide it either.
  /// Held here, never saved.
  String? _revealTarget;

  /// Groups the diver folded or opened themselves since [_revealTarget] was
  /// set: the reveal leaves those alone, so the diver can always fold the
  /// group holding the open item.
  Set<String> _dismissed = const {};

  /// The folds opened for [_revealTarget] this build.
  Set<String> _revealed = const {};

  /// The selection the last build handled, so a new one is noticed once.
  String? _seenSelection;

  /// The item a tap or an arrow key in the list just selected: not an
  /// outside selection, so it moves no reveal and no row under the pointer.
  String? _listSelectedId;

  /// Whether the last build had a filter on, so its clearing is noticed.
  bool _wasFiltered = false;

  /// The open item when the filter came on: only a different one, opened
  /// during the filter, is revealed when it clears.
  String? _openWhenFiltered;

  /// The items on screen this build, in order: what a Shift-click range
  /// walks, so a range across a folded group skips the items inside it.
  List<String> _visibleItemIds = const [];

  /// The outermost fold keys on screen this build: the places when the list
  /// groups by location, the types otherwise. What Collapse all folds, and
  /// empty whenever the body shows no headings (empty, loading, error,
  /// table), so the menu never offers to fold groups that are gone, such as
  /// the previous diver's places. Read when the menu opens.
  List<String> _outerKeys = const [];

  /// The rows for this build, with the folds hiding [_revealTarget] opened.
  ///
  /// [selectedId] is the selection the page rests on. A new one that did
  /// not come from the list's own rows becomes the reveal target, and so
  /// does the open item when a filter clears.
  EquipmentRowLayout _foldedLayout({
    required String? selectedId,
    required List<EquipmentGroup> groups,
    required List<EquipmentLocationSection>? sections,
    required Set<String> folds,
  }) {
    if (selectedId != _seenSelection) {
      _seenSelection = selectedId;
      if (selectedId != null && selectedId != _listSelectedId) {
        _revealTarget = selectedId;
        _dismissed = const {};
      }
      _listSelectedId = null;
    }
    // A row opened while a filter showed every group open would vanish
    // into a saved fold when the filter clears, so it is revealed then. The
    // item open before the filter keeps whatever the diver folded.
    final filtered = ref.watch(
      effectiveEquipmentFilterProvider.select((f) => f.hasActiveFilters),
    );
    final open = widget.selectedId ?? ref.read(highlightedEquipmentIdProvider);
    if (!_wasFiltered && filtered) _openWhenFiltered = open;
    if (_wasFiltered &&
        !filtered &&
        open != null &&
        open != _openWhenFiltered) {
      _revealTarget = open;
      _dismissed = const {};
    }
    _wasFiltered = filtered;
    EquipmentRowLayout layOut(Set<String> revealed) => layoutEquipmentRows(
      groups: groups,
      sections: sections,
      collapsed: folds.difference(revealed),
    );
    var layout = layOut(const {});
    // The target's path does not depend on the folds, so the first layout
    // finds it; a second opens whatever on it is folded now.
    _revealed = {
      for (final key in layout.foldKeysByItem[_revealTarget] ?? const [])
        if (folds.contains(key) && !_dismissed.contains(key)) key,
    };
    if (_revealed.isNotEmpty) layout = layOut(_revealed);
    _visibleItemIds = [
      for (final row in layout.rows)
        if (row is EquipmentItemRow) row.item.id,
    ];
    return layout;
  }

  bool get _isSelectionMode;
  Set<String> get _selectedIds;

  /// A folded group's "N of M selected" in selection mode, or null.
  String? _selectionSummary(BuildContext context, List<EquipmentItem> items) =>
      _isSelectionMode
      ? foldedTickSummary(context.l10n, items.map((e) => e.id), _selectedIds)
      : null;

  /// A place's heading (issue #4184), with a divider above every place but
  /// the first. Its summary shows only while folded, so it is worked out
  /// only then.
  Widget _locationHeading(
    BuildContext context,
    EquipmentLocationHeadingRow row,
    Set<String> folds,
  ) => KeyboardListItem(
    navigationKey: equipmentGroupNavKey(row.foldKey),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!row.isFirst) const Divider(height: 1),
        EquipmentLocationGroupHeader(
          location: row.location,
          count: row.items.length,
          isExpanded: row.isExpanded,
          onTap: () => _toggleFold(row.foldKey, folds),
          summary: row.isExpanded
              ? null
              : (_selectionSummary(context, row.items) ??
                    foldedLocationSummary(context.l10n, row.typeCounts)),
        ),
      ],
    ),
  );

  /// A type's heading (issue #4184), indented under its place. Folded, it
  /// says how many items inside need service, from [urgency].
  Widget _typeHeading(
    BuildContext context,
    EquipmentTypeHeadingRow row,
    Set<String> folds,
    Map<String, ServiceClockStatus> urgency,
  ) => KeyboardListItem(
    navigationKey: equipmentGroupNavKey(row.foldKey),
    child: EquipmentTypeFoldHeader(
      foldKey: row.foldKey,
      type: row.type,
      count: row.items.length,
      isExpanded: row.isExpanded,
      nested: row.parentKey != null,
      onTap: () => _toggleFold(row.foldKey, folds),
      summary: row.isExpanded
          ? null
          : (_selectionSummary(context, row.items) ??
                foldedTypeSummary(
                  context.l10n,
                  serviceDueCount: row.items
                      .where(
                        (e) =>
                            (urgency[e.id]?.severity ??
                                ServiceClockSeverity.ok) !=
                            ServiceClockSeverity.ok,
                      )
                      .length,
                )),
    ),
  );

  /// Whether the group [foldKey] shows its rows: not folded, or folded but
  /// opened for an outside selection.
  bool _isOpen(String foldKey, Set<String> folds) =>
      !folds.contains(foldKey) || _revealed.contains(foldKey);

  /// Folds or opens [foldKey], which the reveal then leaves alone. Folding
  /// a group that is only open for an outside selection writes nothing,
  /// since the saved state already has it folded.
  void _toggleFold(String foldKey, Set<String> folds) {
    final revealedOnly = _revealed.contains(foldKey) && folds.contains(foldKey);
    setState(() => _dismissed = {..._dismissed, foldKey});
    if (revealedOnly) return;
    ref.read(equipmentFoldsProvider.notifier).toggle(foldKey);
  }

  /// Ends the reveal: Expand all and Collapse all are the diver's own word
  /// on every group.
  void _endReveal() => setState(() {
    _revealTarget = null;
    _dismissed = const {};
  });

  static const _expandAllValue = 'fold_expand_all';
  static const _collapseAllValue = 'fold_collapse_all';

  /// Expand all and Collapse all (issue #4184), offered while the list shows
  /// headings. Read as the menu opens, like the view mode.
  List<PopupMenuEntry<String>> _foldMenuEntries(BuildContext context) {
    if (_outerKeys.isEmpty) return const [];
    PopupMenuItem<String> entry(String value, IconData icon, String label) =>
        PopupMenuItem<String>(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              // Wraps rather than overflows: some translations are long.
              Flexible(child: Text(label)),
            ],
          ),
        );
    return [
      entry(
        _expandAllValue,
        Icons.unfold_more,
        context.l10n.equipment_list_expandAllGroups,
      ),
      entry(
        _collapseAllValue,
        Icons.unfold_less,
        context.l10n.equipment_list_collapseAllGroups,
      ),
      const PopupMenuDivider(),
    ];
  }

  /// Runs a fold menu entry; false when [value] is not one.
  bool _handleFoldMenu(String value) {
    final folds = ref.read(equipmentFoldsProvider.notifier);
    switch (value) {
      case _expandAllValue:
        _endReveal();
        folds.expandAll();
        return true;
      case _collapseAllValue:
        _endReveal();
        folds.collapseAll(_outerKeys);
        return true;
    }
    return false;
  }
}
