part of 'equipment_set_detail_page.dart';

/// The equipment set page's read sections, its bar and its menu. Each
/// section is a card of the sitting, drawn from the record the page shows:
/// the sitting's while unlocked.
mixin _EquipmentSetDetailPageSections
    on
        ConsumerState<EquipmentSetDetailPage>,
        FigureSelection<EquipmentSetDetailPage>,
        RecordEditHost<EquipmentSetDetailPage, EquipmentSet>,
        _EquipmentSetDetailPageEditing {
  FigureModelMemo get _memo;

  /// The page for [shown], the set its cards draw, and [stored], the set
  /// as read.
  Widget _buildContent(
    BuildContext context,
    EquipmentSet shown,
    EquipmentSet stored,
  ) {
    // The gear the set applies, as the sitting has it while unlocked
    // (Question 4): its own and that of the sets it includes.
    final items = setItemsShown(ref, shown, stored) ?? const <EquipmentItem>[];
    // Labelled as one list, so identical items in the set read differently
    // from each other (#1549).
    final labels = equipmentRowLabelsOf(context, ref, items);
    // Arranged the same way as the gear lists on a dive, so a set reads the
    // way the diver reads their rig (#1486, #1576). The figure numbers items
    // in this same order, so its labels and the list's badges agree.
    final groups = arrangeEquipment(
      items,
      ref.watch(equipmentArrangementProvider),
      typeLabel: (type) => type.localizedName(context.l10n),
    );
    final ordered = [for (final group in groups) ...group.items];
    // The items are what the set applies: its own gear and that of the sets
    // it includes (issue #4525). Rows from an included set say which.
    final appliedCount = identical(shown, stored)
        ? (stored.items?.length ?? stored.itemCount)
        : items.length;
    final setsById = {
      for (final s
          in ref.watch(equipmentSetsProvider).valueOrNull ??
              const <EquipmentSet>[])
        s.id: s,
    };
    // Parts are told apart from items by the components index (which the
    // rows' assembly chips load anyway). Until it loads, every part would
    // count as an item of its own and be numbered, then vanish and renumber
    // the rest, so the figure waits for it; if it fails to load, the figure
    // still shows, treating nothing as a part.
    final componentsAsync = ref.watch(equipmentComponentsIndexProvider);
    final components = componentsAsync.hasError
        ? ComponentsIndex.empty
        : componentsAsync.value;
    final model = shown.showFigure && components != null
        ? _composedFigure(
            ordered,
            // In a sitting the list is built afresh each time: its members
            // and the gear they are read from say whether it changed.
            itemsKey: identical(shown, stored)
                ? stored.items
                : (
                    [for (final item in ordered) item.id].join('|'),
                    ref.watch(allEquipmentProvider).value,
                  ),
            components: components,
            arrangement: ref.watch(equipmentArrangementProvider),
            locale: Localizations.localeOf(context),
          )
        : null;
    // The figure can be hidden per set; without it the list's numbers would
    // point at nothing, so they go too.
    final numberById = model == null
        ? const <String, int>{}
        : {for (final p in model.numbered) p.item.id: p.number};
    // The widest badge the rows will show, at the diver's text size: the
    // highest number takes the most digits.
    final badgeSlot = model == null
        ? null
        : FigureNumberBadge.widthFor(
            model.itemCount,
            24,
            textScaler: MediaQuery.textScalerOf(context),
          );
    // Members the diver can no longer see (a share was removed, issue
    // #2046) stay in the set, marked. Null until the list loads.
    final visibleIds = ref
        .watch(allEquipmentProvider)
        .value
        ?.map((e) => e.id)
        .toSet();
    // A blank name being typed leaves the figure the set's stored name.
    final figureTitle = shown.name.trim().isEmpty ? stored.name : shown.name;
    final showsBundle =
        shown.carriesBeyondGear || _showsWhileEmpty(EquipmentSetCardId.bundle);
    final showsFigure =
        model != null && ordered.isNotEmpty ||
        _showsWhileEmpty(EquipmentSetCardId.figure);

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _framed(
            EquipmentSetCardId.header,
            _buildHeaderCard(context, shown, appliedCount),
          ),
          const SizedBox(height: 24),
          if (showsFigure) ...[
            _framed(
              EquipmentSetCardId.figure,
              _cornerPencil(
                context,
                EquipmentSetCardId.figure,
                Card(
                  key: figureKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: model == null || ordered.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : GearFigure(
                            model: model,
                            title: figureTitle,
                            selectedItemId: selectedFigureItemId,
                            selectionSerial: figureSelectionSerial,
                            onItemTap: (placed) =>
                                selectFigureItem(placed.item.id),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          _framed(
            EquipmentSetCardId.members,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titleRow(
                  context,
                  context.l10n.equipment_setDetail_equipmentInSetTitle,
                  EquipmentSetCardId.members,
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  _buildEmptyMembers(context)
                else
                  for (final group in groups) ...[
                    if (group.type != null)
                      EquipmentGroupHeader(type: group.type!),
                    ...group.items.map(
                      (item) => _buildEquipmentTile(
                        context,
                        item,
                        labels,
                        numberById[item.id],
                        badgeSlot: badgeSlot,
                        noLongerShared:
                            visibleIds != null && !visibleIds.contains(item.id),
                        fromSetName: includedSourceOf(
                          shown,
                          item.id,
                          setsById,
                        )?.name,
                      ),
                    ),
                  ],
              ],
            ),
          ),
          if (showsBundle) ...[
            const SizedBox(height: 16),
            _framed(
              EquipmentSetCardId.bundle,
              _cornerPencil(
                context,
                EquipmentSetCardId.bundle,
                shown.carriesBeyondGear
                    ? SetBundleSummaryCard(set: shown)
                    : const Card(child: SizedBox(width: double.infinity)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _framed(
            EquipmentSetCardId.geofences,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titleRow(
                  context,
                  context.l10n.equipment_setDetail_geofencesTitle,
                  EquipmentSetCardId.geofences,
                ),
                const SizedBox(height: 8),
                _buildGeofenceRows(context, shown.geofences),
              ],
            ),
          ),
        ],
      ),
    );

    final menu = _buildMenu(context, shown);
    final bar = AppBar(
      title: Text(shown.name),
      actions: [lockButton(shown), menu],
    );
    return editScaffold(
      record: stored,
      shown: shown,
      lockedBar: bar,
      unlockedActions: [menu],
      content: body,
    );
  }

  /// The header block: the set's name, its Default chip, its description,
  /// auto-apply when it is on, and the count of what it applies (calculated).
  Widget _buildHeaderCard(
    BuildContext context,
    EquipmentSet set,
    int appliedCount,
  ) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.folder,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // The name and its chip take the whole row but the
                      // pencil, the chip right after the name.
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                set.name,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            if (set.isDefault) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  context.l10n.equipment_sets_defaultBadge,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                      ),
                      RecordCardPencil(
                        cardTitle: _cardTitle(
                          context,
                          EquipmentSetCardId.header,
                        ),
                      ),
                    ],
                  ),
                  if (set.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    MarkdownNotesView(
                      set.description,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                  // Shown nowhere before the page edited in place (decision
                  // 7).
                  if (set.autoApplyOnComputerImport) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.download_done, size: 16, color: muted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            context
                                .l10n
                                .equipment_setEdit_computerAutoApplySwitch_title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    appliedCount == 1
                        ? context.l10n.equipment_sets_itemCountSingular(
                            appliedCount,
                          )
                        : context.l10n.equipment_sets_itemCountPlural(
                            appliedCount,
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The Members card with no gear: its pencil opens the editor
  /// (Call 6).
  Widget _buildEmptyMembers(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.backpack_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.equipment_setDetail_emptySet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeofenceRows(
    BuildContext context,
    List<EquipmentSetGeofence> fences,
  ) => fences.isEmpty
      ? Text(context.l10n.equipment_setDetail_noGeofences)
      : Column(
          children: [
            for (final g in fences)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(
                  g.label ?? context.l10n.equipment_geofenceEditor_title,
                ),
              ),
          ],
        );

  /// A section's title, with the card's pencil.
  Widget _titleRow(BuildContext context, String title, EquipmentSetCardId id) =>
      Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          RecordCardPencil(cardTitle: _cardTitle(context, id)),
        ],
      );

  /// [card], a card with no title row, with the pencil in its top corner.
  /// Locked, the pencil takes no room.
  Widget _cornerPencil(
    BuildContext context,
    EquipmentSetCardId id,
    Widget card,
  ) {
    return Stack(
      children: [
        card,
        PositionedDirectional(
          top: 8,
          end: 8,
          child: RecordCardPencil(cardTitle: _cardTitle(context, id)),
        ),
      ],
    );
  }

  String _cardTitle(BuildContext context, EquipmentSetCardId id) =>
      equipmentSetEditCards[id]!.title(context);

  /// The composed figure, reused while its inputs are unchanged.
  FigureModel _composedFigure(
    List<EquipmentItem> ordered, {
    required Object? itemsKey,
    required ComponentsIndex components,
    required EquipmentArrangement arrangement,
    required Locale locale,
  }) => _memo.of(
    (itemsKey, components, arrangement, locale),
    () => composeFigure(figureInputsFromItems(ordered, components: components)),
  );

  /// One member of the set. [number] is its figure number, shown as the
  /// legend badge; child items and assembly parts have none. While the
  /// figure shows, every row leads with a slot [badgeSlot] wide (the widest
  /// badge at the diver's text size), holding the badge or nothing, so every
  /// name starts at the same place. Null when it is off.
  /// [noLongerShared] marks a member another profile stopped sharing.
  Widget _buildEquipmentTile(
    BuildContext context,
    EquipmentItem item,
    Map<String, EquipmentRowLabel> labels,
    int? number, {
    double? badgeSlot,
    bool noLongerShared = false,
    String? fromSetName,
  }) {
    final selected = item.id == selectedFigureItemId;
    final scheme = Theme.of(context).colorScheme;
    final highlight = selected ? figureHighlightFor(scheme) : null;
    return Card(
      key: figureRowKey(item.id),
      margin: const EdgeInsets.only(bottom: 8),
      color: highlight?.fill,
      child: ListTile(
        textColor: highlight?.onFill,
        iconColor: highlight?.onFill,
        onTap: () => context.push('/equipment/${item.id}'),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeSlot != null) ...[
              SizedBox(
                width: badgeSlot,
                child: number == null
                    ? null
                    : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FigureNumberBadge(
                          number: number,
                          selected: selected,
                          onTap: () =>
                              selectFigureItem(item.id, revealFigure: true),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
            ],
            CircleAvatar(
              backgroundColor: scheme.tertiaryContainer,
              child: Icon(
                equipmentItemIcon(item),
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
        title: Text(item.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The type stands in for a missing brand and model, as it always
            // has here; an identifier or a tie-break detail follows it
            // rather than replacing it, or "ID P2" alone would not say what
            // the item is.
            Text(
              [
                if (item.fullName == item.name)
                  item.type.localizedName(context.l10n),
                ...?labels[item.id]?.subtitleParts,
                if (noLongerShared) context.l10n.equipment_set_noLongerShared,
                if (fromSetName != null)
                  context.l10n.equipment_setDetail_fromSet(fromSetName),
              ].join(' · '),
            ),
            AssemblyChips(itemId: item.id),
            ServiceStatusIndicatorFor(
              equipmentId: item.id,
              density: ServiceIndicatorDensity.compact,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  /// The bar's menu. Show figure and Set as default are the Figure and
  /// header cards' (Question 1), and Delete is a whole-record operation
  /// under the lock.
  Widget _buildMenu(BuildContext context, EquipmentSet set) {
    // Nothing acts on a set not yet created (plan 11, call 3).
    if (isCreating) return const SizedBox.shrink();
    final controller = editController;
    return PopupMenuButton<String>(
      onSelected: (value) => _handleMenuAction(context, value, set),
      itemBuilder: (context) => [
        changeLogHistoryMenuItem(
          context,
          rootTable: 'equipment_sets',
          rootId: set.id,
        ),
        // Clone (issue #2156), just above Delete. It creates another set,
        // so it works locked.
        PopupMenuItem(
          value: _EquipmentSetDetailPageState._cloneAction,
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: Text(context.l10n.equipment_menu_clone),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        ...recordOperationMenuCaption<String>(context, controller),
        PopupMenuItem(
          value: 'delete',
          enabled: recordOperationsAvailable(controller),
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text(
              context.l10n.equipment_setDetail_deleteMenuItem,
              style: const TextStyle(color: Colors.red),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    EquipmentSet set,
  ) async {
    if (action == _EquipmentSetDetailPageState._cloneAction) {
      await cloneEquipmentSet(context, set.id);
      return;
    }
    if (action == 'delete') {
      recordOperationRunnerOf(
        editController,
        record: 'equipment set ${set.id}',
      )(() => _confirmDelete(context, set.id));
    }
  }

  /// Asks, then deletes; whether it was deleted.
  Future<bool> _confirmDelete(BuildContext context, String setId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.equipment_setDetail_deleteDialog_title),
        content: Text(context.l10n.equipment_setDetail_deleteDialog_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.equipment_setDetail_deleteDialog_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.equipment_setDetail_deleteDialog_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await ref.read(equipmentSetListNotifierProvider.notifier).deleteSet(setId);
    if (context.mounted) {
      context.go('/equipment');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.equipment_setDetail_snackbar_deleted),
        ),
      );
    }
    return true;
  }
}
