part of 'bulk_dive_edit_page.dart';

/// The collections of bulk edit (gear, sets, tags, dive types, courses, buddies): what the selected dives hold now, and what the diver adds or removes.
extension _BulkDiveEditCollections on _BulkDiveEditPageState {
  Widget _buildBulkCollectionsSection(UnitFormatter units) {
    final l10n = context.l10n;
    final total = widget.diveIds.length;
    final labels = diveBulkMembershipLabels(l10n);
    const ownedModes = [BulkCollectionMode.add, BulkCollectionMode.replace];
    // Only an assembly or a part gets a chip row, as on the equipment list;
    // plain gear keeps the status line as its whole subtitle.
    final componentIndex = ref.watch(equipmentComponentsIndexProvider).value;
    final gearRows = _bulkGearRows(ref.watch(equipmentArrangementProvider));
    return FormSection(
      label: context.l10n.diveLog_bulkEdit_groupCollections,
      expanded: true,
      onToggle: null,
      children: [
        BulkMembershipEditor(
          title: l10n.diveLog_edit_section_tags,
          total: total,
          labels: labels,
          items: _tagMembers,
          counts: _tagCounts,
          onAdd: _bulkAddTags,
          onChanged: (d) => _update(() => _tagDelta = d),
        ),
        BulkMembershipEditor(
          title: l10n.diveLog_edit_label_diveTypes,
          total: total,
          labels: labels,
          items: _diveTypeMembers,
          counts: _diveTypeCounts,
          onAdd: _bulkAddDiveTypes,
          onChanged: (d) => _update(() => _diveTypeDelta = d),
        ),
        BulkMembershipEditor(
          title: l10n.diveLog_edit_section_trainingCourses,
          total: total,
          labels: labels,
          items: _courseMembers,
          counts: _courseCounts,
          onAdd: _bulkAddCourses,
          onChanged: (d) => _update(() => _courseDelta = d),
        ),
        BulkMembershipEditor(
          title: l10n.diveLog_edit_section_equipment,
          total: total,
          labels: labels,
          items: gearRows.items,
          counts: _equipmentCounts,
          onAdd: _bulkAddEquipment,
          secondaryAction: BulkGearActions(onUseSet: _bulkUseEquipmentSet),
          headerBuilder: (item) => switch (gearRows.headings[item.id]) {
            final type? => EquipmentGroupHeader(type: type),
            null => null,
          },
          onChanged: (d) => _update(() => _equipmentDelta = d),
          ensureOn: _equipmentEnsureOn,
          // Assembly and part-of chips, as on the equipment list (#1487). They
          // go under the name, not in the trailing slot: a long assembly name
          // there squeezed the row to one character per line (#2276).
          detailBuilder: (item) =>
              componentIndex != null &&
                  (componentIndex.isAssembly(item.id) ||
                      componentIndex.parentIdsOf(item.id).isNotEmpty)
              ? AssemblyChips(itemId: item.id)
              : null,
        ),
        if (_equipmentSetAdds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final staged in _equipmentSetAdds)
                  InputChip(
                    key: ValueKey('bulk-used-set-${staged.id}'),
                    avatar: const Icon(Icons.folder_special, size: 18),
                    label: Text(staged.name),
                    onDeleted: () => _update(
                      () => _equipmentSetAdds = [
                        for (final s in _equipmentSetAdds)
                          if (s.id != staged.id) s,
                      ],
                    ),
                  ),
              ],
            ),
          ),
        BulkEquipmentSetRemovals(
          sets: _equipmentSetRemovals,
          onPick: _bulkRemoveEquipmentSet,
          onUnstage: (id) => _update(
            () => _equipmentSetRemovals = [
              for (final s in _equipmentSetRemovals)
                if (s.id != id) s,
            ],
          ),
        ),
        BulkMembershipEditor(
          title: l10n.diveLog_edit_group_buddies,
          total: total,
          labels: labels,
          items: _buddyMembers,
          counts: _buddyCounts,
          onAdd: _bulkAddBuddies,
          onChanged: (d) => _update(() => _buddyDelta = d),
          // Each dive_buddies link carries roles, so the row needs an
          // affordance membership alone cannot express (#1220). It sits under
          // the name, not in the trailing slot, because a set of roles can be
          // long (#1221, as #2276 did for assembly chips).
          detailBuilder: (item) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: ValueKey('buddy-role-${item.id}'),
              onPressed: () => _showBulkBuddyRolePicker(item),
              child: Text(
                _bulkBuddyRoleLabel(item.id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        // The diver's own role is a scalar column, not a membership row, so it
        // rides the gate lane. It sits with Buddies because that is where the
        // single-dive editor keeps it (#1220).
        _gatedRow(
          BulkField.diverRole,
          FormRow.picker(
            label: l10n.diveLog_bulkEdit_fieldMyRole,
            value: _bulkDiverRoleLabel(),
            placeholder: _bulkDiverRolePlaceholder(),
            onTap: _showBulkDiverRolePicker,
            onClear: _diverRoleIds.isEmpty
                ? null
                : () => _update(() {
                    _markDirty();
                    _diverRoleIds = const [];
                  }),
          ),
        ),
        _collectionEntry(
          type: BulkCollectionType.weights,
          label: context.l10n.diveLog_bulkEdit_collectionWeights,
          allowed: ownedModes,
          editor: _weightChild(units),
        ),
        _collectionEntry(
          type: BulkCollectionType.tanks,
          label: context.l10n.diveLog_bulkEdit_collectionTanks,
          // Tanks alone can be edited in place, keeping their pressures (#797).
          allowed: const [
            BulkCollectionMode.add,
            BulkCollectionMode.update,
            BulkCollectionMode.replace,
          ],
          editor: _bulkTanksEditor(units),
        ),
        _collectionEntry(
          type: BulkCollectionType.sightings,
          label: context.l10n.diveLog_edit_section_marineLife,
          allowed: ownedModes,
          editor: _sightingsChild(),
        ),
      ],
    );
  }

  /// The bulk Site row's picker. Unlike [_showSitePicker] it only stages the
  /// site: the snap onto water type, entry/exit and dive types happens per
  /// dive in the bulk service, so the form's own rows keep what the diver
  /// set (#3657).
  Future<void> _showBulkSitePicker() async {
    if (_openingSitePicker) return;
    _openingSitePicker = true;
    try {
      final areaAnchor = await _areaAnchor();
      if (!mounted) return;
      final site = await pickOrCreateSite(
        context,
        ref,
        selectedSiteId: _selectedSite?.id,
        areaAnchor: areaAnchor,
      );
      if (site != null && mounted) {
        _markDirty();
        _update(() => _selectedSite = site);
      }
    } finally {
      _openingSitePicker = false;
    }
  }

  /// Load the members (with per-item dive counts) of every id-based reference
  /// collection across the selected dives, so each tri-state editor can show
  /// its all/some/none state.
  Future<void> _loadBulkMembers() async {
    final ids = widget.diveIds;
    final repo = ref.read(diveRepositoryProvider);
    final equipCounts = await repo.equipmentCountsForDives(ids);
    final tagCounts = await repo.tagCountsForDives(ids);
    final typeCounts = await repo.diveTypeCountsForDives(ids);
    final courseCounts = await repo.courseCountsForDives(ids);
    final buddyRepo = ref.read(buddyRepositoryProvider);
    final buddyCounts = await buddyRepo.buddyCountsForDives(ids);
    final buddyRoles = await buddyRepo.unanimousBuddyRolesForDives(ids);
    final diverRoleSets = await DiveRoleLinkRepository().diverRoleIdsForDives(
      ids,
    );

    final equip = await EquipmentRepository().getEquipmentByIds(
      equipCounts.keys.toList(),
    );
    final allTags = await ref.read(tagsProvider.future);
    final allTypes = await ref.read(diveTypesProvider.future);
    final allCourses = await ref.read(allCoursesProvider.future);
    final allBuddies = await buddyRepo.getAllBuddies();
    if (!mounted) return;

    final tagName = {for (final t in allTags) t.id: t.name};
    final typeName = {
      for (final t in allTypes) t.id: t.localizedName(context.l10n),
    };
    final buddyMap = {for (final b in allBuddies) b.id: b};
    // The count queries group by id with no ORDER BY, so sort each member list
    // by label to keep the bulk editor's row order stable across loads/devices.
    // Gear needs no sort here: it renders through the gear arrangement, whose
    // comparisons all end in a total tie-break.
    int byLabel(BulkMembershipItem a, BulkMembershipItem b) =>
        compareTextForSort(a.label, b.label);
    _update(() {
      _equipmentCounts = equipCounts;
      _bulkGear = equip;
      _tagCounts = tagCounts;
      _tagMembers = [
        for (final id in tagCounts.keys)
          BulkMembershipItem(
            id: id,
            label: tagName[id] ?? id,
            icon: Icons.label_outline,
          ),
      ]..sort(byLabel);
      _diveTypeCounts = typeCounts;
      _diveTypeNames
        ..clear()
        ..addAll(typeName);
      _diveTypeMembers = [
        for (final id in typeCounts.keys)
          BulkMembershipItem(
            id: id,
            label: typeName[id] ?? id,
            icon: Icons.scuba_diving,
          ),
      ]..sort(byLabel);
      _courseCounts = courseCounts;
      final courseName = {for (final c in allCourses) c.id: c.name};
      _courseMembers = [
        for (final id in courseCounts.keys)
          BulkMembershipItem(
            id: id,
            label: courseName[id] ?? id,
            icon: Icons.school_outlined,
          ),
      ]..sort(byLabel);
      _buddyCounts = buddyCounts;
      final distinctDiverSets = {
        for (final set in diverRoleSets.values) set.join('|'),
      };
      _diverRolesMixed = distinctDiverSets.length > 1;
      _existingDiverRoleIds = _diverRolesMixed
          ? null
          : diverRoleSets.values.firstOrNull;
      // A set every dive shares is the row's starting value, so the picker
      // opens with it ticked and enabling the gate keeps it rather than
      // replacing it with nothing.
      if (!_diverRolesMixed) _diverRoleIds = _existingDiverRoleIds ?? const [];
      _buddyById
        ..clear()
        ..addAll(buddyMap);
      _existingBuddyRoleIds
        ..clear()
        ..addAll(buddyRoles);
      _buddyMembers = [
        for (final id in buddyCounts.keys)
          BulkMembershipItem(
            id: id,
            label: buddyMap[id]?.name ?? id,
            icon: Icons.person_outline,
          ),
      ]..sort(byLabel);
    });
  }

  /// The bulk equipment rows in the diver's gear arrangement, headings
  /// included, as the single-dive gear list shows them (#2274).
  BulkGearRows _bulkGearRows(EquipmentArrangement arrangement) {
    final l10n = context.l10n;
    return arrangeBulkGearRows(
      _bulkGear,
      arrangement,
      typeLabel: (type) => type.localizedName(l10n),
    );
  }

  void _bulkAddEquipment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentPickerSheet(
          scrollController: scrollController,
          selectedEquipmentIds: _bulkGear.map((e) => e.id).toSet(),
          hideSpare: true,
          hideAssemblyParts: true,
          offerLeftKit: true,
          onEquipmentConfirmed: (items) {
            _update(() => _bulkGear = withBulkGear(_bulkGear, items));
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _bulkUseEquipmentSet() async {
    // The sheet closes on the tap, as before; the members are filtered once
    // it has, so a second tap cannot land while the filter is running.
    final picked =
        await showModalBottomSheet<
          ({EquipmentSet set, List<EquipmentItem> items})
        >(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => EquipmentSetPickerSheet(
              scrollController: scrollController,
              onSetSelected: (set, items) =>
                  Navigator.of(context).pop((set: set, items: items)),
            ),
          ),
        );
    if (picked == null || !mounted) return;
    final set = picked.set;
    final items = await _bulkUsableSetItems(picked.items);
    if (!mounted) return;
    if (items.isEmpty) {
      // Nothing to list among the gear, so the set itself is staged, when
      // it carries weights or tanks to apply. A set with neither, whose
      // gear cannot go on these dives, would change nothing.
      if (!set.carriesBeyondGear) return;
      _markDirty();
      _update(
        () => _equipmentSetAdds = withStagedSet(_equipmentSetAdds, (
          id: set.id,
          name: set.name,
        )),
      );
      return;
    }
    _update(() {
      _bulkGear = withBulkGear(_bulkGear, items);
      // Rows already listed keep whatever the user set them to, so
      // appending alone would let an unchecked row remove a set item
      // from every dive (#1754). Switch the whole set on.
      _equipmentEnsureOn = (
        serial: (_equipmentEnsureOn?.serial ?? 0) + 1,
        ids: {for (final item in items) item.id},
      );
      // An item the diver switched off since an earlier set put it
      // on is this set's now, not the earlier one's.
      final on = equipmentSwitchedOn(
        _equipmentDelta,
        onEveryDive: _equipmentOnEveryDive,
      );
      _equipmentSetOf = withSetItems(_equipmentSetOf, set.id, [
        for (final item in items) item.id,
      ], isOn: on.contains);
    });
  }

  /// The members of a set bulk "Use Set" applies: one another profile owns
  /// and has not shared with the diver stays in the set but is not applied
  /// (#2046), as when the set is used on one dive. An unreadable diver
  /// applies every member, as before sharing.
  Future<List<EquipmentItem>> _bulkUsableSetItems(
    List<EquipmentItem> items,
  ) async {
    if (items.isEmpty) return items;
    String? diverId;
    try {
      diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    } catch (_) {
      diverId = null;
    }
    if (diverId == null) return items;
    final usable = await EquipmentRepository().usableSetMemberIds([
      for (final i in items) i.id,
    ], diverId);
    return usableSetItems(items, usable.toSet());
  }

  /// Stages a set to come off every selected dive with the gear it brought
  /// (#4284). Nothing is written until the edit is applied.
  Future<void> _bulkRemoveEquipmentSet() async {
    final set = await pickEquipmentSetToRemove(context);
    if (set == null || !mounted) return;
    // A staged removal is an unsaved change: leaving warns about it.
    _markDirty();
    _update(
      () => _equipmentSetRemovals = withStagedSet(_equipmentSetRemovals, set),
    );
  }

  void _bulkAddTags() {
    var picked = <Tag>[];
    showDialog<void>(
      context: context,
      // The StatefulBuilder wraps the whole dialog, not just its content, so
      // the Browse action in the button row can restage `picked` too.
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(context.l10n.diveLog_edit_section_tags),
          content: TagInputWidget(
            selectedTags: picked,
            onTagsChanged: (t) => setSt(() => picked = t),
          ),
          actions: [
            TextButton(
              // `ctx` is inside the dialog route, so the picker lands on the
              // same (root) navigator and opens above the dialog (#1366).
              onPressed: () => _showTagPickerFor(
                host: ctx,
                selected: picked,
                onPicked: (tags) => setSt(() => picked = tags),
              ),
              child: Text(context.l10n.tags_action_browse),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.diveLog_edit_cancel),
            ),
            FilledButton(
              onPressed: () {
                _addTagMembers(picked);
                Navigator.pop(ctx);
              },
              child: Text(context.l10n.diveLog_edit_add),
            ),
          ],
        ),
      ),
    );
  }

  void _addTagMembers(List<Tag> tags) {
    _update(() {
      final existing = _tagMembers.map((e) => e.id).toSet();
      _tagMembers = [
        ..._tagMembers,
        for (final t in tags)
          if (!existing.contains(t.id))
            BulkMembershipItem(
              id: t.id,
              label: t.name,
              icon: Icons.label_outline,
            ),
      ];
    });
  }

  void _bulkAddDiveTypes() {
    var picked = <String>[];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.diveLog_edit_label_diveTypes),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (ctx, setSt) => DiveTypeMultiSelectField(
              selectedTypeIds: picked,
              allowEmpty: true,
              onChanged: (ids) => setSt(() => picked = ids),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.diveLog_edit_cancel),
          ),
          FilledButton(
            onPressed: () {
              _addDiveTypeMembers(picked);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.diveLog_edit_add),
          ),
        ],
      ),
    );
  }

  void _addDiveTypeMembers(List<String> ids) {
    _update(() {
      final existing = _diveTypeMembers.map((e) => e.id).toSet();
      _diveTypeMembers = [
        ..._diveTypeMembers,
        for (final id in ids)
          if (!existing.contains(id))
            BulkMembershipItem(
              id: id,
              label: _diveTypeNames[id] ?? id,
              icon: Icons.scuba_diving,
            ),
      ];
    });
  }

  /// Opens the course checklist and adds the picked courses as members, each
  /// starting "on all" in the membership editor (#2515).
  Future<void> _bulkAddCourses() async {
    var picked = <String>[];
    await showCourseMultiPickerSheet(
      context,
      selectedCourseIds: const [],
      onChanged: (ids) => picked = ids,
    );
    if (!mounted || picked.isEmpty) return;
    final names = {
      for (final c in ref.read(courseListNotifierProvider).value ?? const [])
        c.id: c.name,
    };
    _update(() {
      final existing = {for (final m in _courseMembers) m.id};
      _courseMembers = [
        ..._courseMembers,
        for (final id in picked)
          if (!existing.contains(id))
            BulkMembershipItem(
              id: id,
              label: names[id] ?? id,
              icon: Icons.school_outlined,
            ),
      ];
    });
  }

  void _bulkAddBuddies() {
    var picked = <BuddyWithRole>[];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.diveLog_edit_group_buddies),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (ctx, setSt) => BuddyPicker(
              selectedBuddies: picked,
              onChanged: (b) => setSt(() => picked = b),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.diveLog_edit_cancel),
          ),
          FilledButton(
            onPressed: () {
              _addBuddyMembers(picked);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.diveLog_edit_add),
          ),
        ],
      ),
    );
  }

  void _addBuddyMembers(List<BuddyWithRole> buddies) {
    _update(() {
      final existing = _buddyMembers.map((e) => e.id).toSet();
      for (final bwr in buddies) {
        _buddyById[bwr.buddy.id] = bwr.buddy;
        _buddyRoleById[bwr.buddy.id] = bwr.roles;
      }
      _buddyMembers = [
        ..._buddyMembers,
        for (final bwr in buddies)
          if (!existing.contains(bwr.buddy.id))
            BulkMembershipItem(
              id: bwr.buddy.id,
              label: bwr.buddy.name,
              icon: Icons.person_outline,
            ),
      ];
    });
  }

  BuddyWithRole _buddyWithRole(String id) => BuddyWithRole(
    buddy:
        _buddyById[id] ??
        Buddy(
          id: id,
          name: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    roles: _rolesForBuddy(id),
  );

  /// Picked roles win; otherwise reuse the set the buddy already has across
  /// the selection so a membership-only add cannot demote them to Buddy. Only
  /// the ids reach the database, so unresolved ids stay synthetic (#893).
  List<DiveRole> _rolesForBuddy(String id) {
    final picked = _buddyRoleById[id];
    if (picked != null) return picked;
    final existing = _existingBuddyRoleIds[id];
    return existing == null
        ? [DiveRole.builtInBuddy()]
        : [for (final r in existing) DiveRole.synthetic(r)];
  }

  /// Opens the previously-used-tag picker (#1171) over [selected], so tagging
  /// stays consistent without having to recall earlier spellings. See
  /// [showTagPickerSheet] for when to pass [host].
  void _showTagPickerFor({
    required List<Tag> selected,
    required ValueChanged<List<Tag>> onPicked,
    BuildContext? host,
  }) => showTagPickerSheet(
    context,
    selected: selected,
    onPicked: onPicked,
    host: host,
  );

  /// The gear rows already on every selected dive.
  Set<String> get _equipmentOnEveryDive {
    final total = widget.diveIds.length;
    return {
      for (final e in _equipmentCounts.entries)
        if (total > 0 && e.value >= total) e.key,
    };
  }
}
