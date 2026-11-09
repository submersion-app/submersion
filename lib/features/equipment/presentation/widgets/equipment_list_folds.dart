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

  /// The outermost fold keys last published to
  /// [equipmentOuterGroupKeysProvider], so it is written only on change.
  List<String> _publishedOuterKeys = const [];

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
    return layout;
  }

  /// Tells Collapse all and the menu which outermost groups are on screen,
  /// after the frame and only on change. Every other body (empty, loading,
  /// error, table) publishes none, so the menu never offers to fold groups
  /// that are gone, such as the previous diver's places.
  void _publishOuterKeys(List<String> keys) {
    if (listEquals(keys, _publishedOuterKeys)) return;
    _publishedOuterKeys = keys;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(equipmentOuterGroupKeysProvider.notifier).state = keys;
    });
  }

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
    if (ref.read(equipmentOuterGroupKeysProvider).isEmpty) return const [];
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
        folds.collapseAll();
        return true;
    }
    return false;
  }
}
