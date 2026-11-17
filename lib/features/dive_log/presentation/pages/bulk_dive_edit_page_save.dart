part of 'bulk_dive_edit_page.dart';

/// Saving bulk edit: the enabled rows and the collection changes, written to every selected dive at once.
extension _BulkDiveEditSave on _BulkDiveEditPageState {
  BulkScalarInputs _collectScalarInputs(UnitFormatter units) {
    final bulkVisibility = _bulkVisibility(units);
    // High-value Logistics + notes fields. Extended per group in later tasks.
    return BulkScalarInputs(
      diveCenterId: _selectedDiveCenter?.id,
      diveOperator: trimmedOrNull(_diveOperatorController.text),
      boatName: trimmedOrNull(_boatNameController.text),
      boatCaptain: trimmedOrNull(_boatCaptainController.text),
      tripId: _selectedTrip?.id,
      rating: _rating > 0 ? _rating : null,
      isFavorite: _bulkFavorite,
      excludedFromStats: _bulkExcludedFromStats,
      excludedFromGasStats: _bulkExcludedFromGasStats,
      waterType: _waterType?.name,
      visibilityMeters: bulkVisibility.meters,
      visibilityMinMeters: bulkVisibility.range?.minM,
      visibilityMaxMeters: bulkVisibility.range?.maxM,
      currentDirection: _currentDirection?.name,
      currentStrength: _currentStrength?.name,
      swellHeight: _savedNumber(
        _swellHeightController,
      ).map(units.depthToMeters),
      surfaceConditions: trimmedOrNull(_surfaceConditionsController.text),
      entryMethod: _entryMethod?.name,
      exitMethod: _exitMethod?.name,
      altitude: _savedNumber(_altitudeController).map(units.altitudeToMeters),
      surfacePressure: _savedNumber(_surfacePressureController).map(
        (mbar) => mbar / 1000, // Convert mbar to bar
      ),
      windSpeed: _savedNumber(_windSpeedController).map(units.windSpeedToMs),
      windDirection: _windDirection?.name,
      cloudCover: _cloudCover?.name,
      precipitation: _precipitation?.name,
      humidity: _savedNumber(_humidityController),
      weatherDescription: _weatherDescriptionController.text.isNotEmpty
          ? _weatherDescriptionController.text
          : null,
      diveMode: _diveMode.code,
      setpointLow: _setpointLow,
      setpointHigh: _setpointHigh,
      setpointDeco: _setpointDeco,
      scrubberType: _scrubberType,
      scrubberDuration: _scrubberDurationMinutes,
      notes: _notesController.text,
    );
  }

  Widget _collectionEntry({
    required BulkCollectionType type,
    required String label,
    required List<BulkCollectionMode> allowed,
    required Widget editor,
  }) {
    final mode = _collectionModes[type];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              BulkCollectionModeSelector(
                mode: mode,
                allowed: allowed,
                onChanged: (m) => _update(() {
                  if (m == null) {
                    _collectionModes.remove(type);
                  } else {
                    _collectionModes[type] = m;
                  }
                }),
              ),
            ],
          ),
        ),
        if (mode != null) editor,
      ],
    );
  }

  List<BulkCollectionOp> _collectCollectionOps() {
    final ops = <BulkCollectionOp>[];
    if (_bulkEnabled.contains(BulkField.site)) {
      ops.add(SiteOp(siteId: _selectedSite?.id));
    }
    if (_bulkEnabled.contains(BulkField.diverRole)) {
      ops.add(DiverRolesOp(roleIds: _diverRoleIds));
    }
    if (_tagDelta.addIds.isNotEmpty) {
      ops.add(TagsOp(mode: BulkCollectionMode.add, tagIds: _tagDelta.addIds));
    }
    if (_tagDelta.removeIds.isNotEmpty) {
      ops.add(
        TagsOp(mode: BulkCollectionMode.remove, tagIds: _tagDelta.removeIds),
      );
    }
    if (_diveTypeDelta.addIds.isNotEmpty) {
      ops.add(
        DiveTypesOp(
          mode: BulkCollectionMode.add,
          diveTypeIds: _diveTypeDelta.addIds,
        ),
      );
    }
    if (_diveTypeDelta.removeIds.isNotEmpty) {
      ops.add(
        DiveTypesOp(
          mode: BulkCollectionMode.remove,
          diveTypeIds: _diveTypeDelta.removeIds,
        ),
      );
    }
    for (final (mode, ids) in [
      (BulkCollectionMode.add, _courseDelta.addIds),
      (BulkCollectionMode.remove, _courseDelta.removeIds),
    ]) {
      if (ids.isNotEmpty) ops.add(DiveCoursesOp(mode: mode, courseIds: ids));
    }
    // Sets come off before any gear goes on, so a set removed and another
    // added in one edit cannot take gear the two share (#4284).
    if (_equipmentSetRemovals.isNotEmpty) {
      ops.add(
        EquipmentSetsOp(
          mode: BulkCollectionMode.remove,
          setIds: [for (final s in _equipmentSetRemovals) s.id],
        ),
      );
    }
    // A set with no gear has no gear op to ride on (issue #4525).
    if (_equipmentSetAdds.isNotEmpty) {
      ops.add(
        EquipmentSetsOp(
          mode: BulkCollectionMode.add,
          setIds: [for (final s in _equipmentSetAdds) s.id],
        ),
      );
    }
    ops.addAll(
      equipmentAddOps(
        equipmentAddIds(
          _equipmentDelta,
          _equipmentSetOf,
          onEveryDive: _equipmentOnEveryDive,
        ),
        _equipmentSetOf,
      ),
    );
    if (_equipmentDelta.removeIds.isNotEmpty) {
      ops.add(
        EquipmentOp(
          mode: BulkCollectionMode.remove,
          equipmentIds: _equipmentDelta.removeIds,
        ),
      );
    }
    // Membership and role are separate instructions. A row the user only
    // ticked on must not rewrite the role of links that already exist (#893).
    final membershipOnlyAdds = _buddyDelta.addIds
        .where((id) => !_buddyRoleById.containsKey(id))
        .toList();
    // A picked role on a buddy who is also being added rides the add, so the
    // links it creates carry that role from the start.
    final pickedRoleAdds = _buddyRoleById.keys
        .where(
          (id) =>
              !_buddyDelta.removeIds.contains(id) &&
              _buddyDelta.addIds.contains(id),
        )
        .toList();
    // A picked role with no membership change is role-only: rewrite the links
    // that exist and create none, so changing the role of a buddy who is on
    // some of the selection cannot add them to the rest (#1220).
    final roleOnlyUpdates = _buddyRoleById.keys
        .where(
          (id) =>
              !_buddyDelta.removeIds.contains(id) &&
              !_buddyDelta.addIds.contains(id),
        )
        .toList();
    if (membershipOnlyAdds.isNotEmpty) {
      ops.add(
        BuddiesOp(
          mode: BulkCollectionMode.add,
          buddies: membershipOnlyAdds.map(_buddyWithRole).toList(),
          overwriteRole: false,
        ),
      );
    }
    if (pickedRoleAdds.isNotEmpty) {
      ops.add(
        BuddiesOp(
          mode: BulkCollectionMode.add,
          buddies: pickedRoleAdds.map(_buddyWithRole).toList(),
        ),
      );
    }
    if (roleOnlyUpdates.isNotEmpty) {
      ops.add(
        BuddiesOp(
          mode: BulkCollectionMode.update,
          buddies: roleOnlyUpdates.map(_buddyWithRole).toList(),
        ),
      );
    }
    if (_buddyDelta.removeIds.isNotEmpty) {
      ops.add(
        BuddiesOp(
          mode: BulkCollectionMode.remove,
          buddies: _buddyDelta.removeIds.map(_buddyWithRole).toList(),
        ),
      );
    }
    final tanksMode = _collectionModes[BulkCollectionType.tanks];
    if (tanksMode == BulkCollectionMode.update) {
      // An empty mask would touch nothing; _saveBulk reports that separately
      // rather than sending a no-op op through the engine.
      if (_bulkTankSpecFields.isNotEmpty) {
        ops.add(
          TankSpecsOp(
            specs: _bulkTankSpecs,
            fields: _bulkTankSpecFields,
            // Only while Role is ticked: positions picked and then unticked
            // must not reach the dives (#4412).
            slotRoles: _bulkTankSpecFields.contains(TankSpecField.role)
                ? _bulkTankSlotRoles
                : null,
          ),
        );
      }
    } else if (tanksMode != null) {
      ops.add(
        TanksOp(
          mode: tanksMode,
          tanks: _tanks,
          onlyIfEmpty: _bulkTankOnlyIfEmpty,
        ),
      );
    }
    final weightsMode = _collectionModes[BulkCollectionType.weights];
    if (weightsMode != null) {
      ops.add(WeightsOp(mode: weightsMode, weights: _weights));
    }
    final sightingsMode = _collectionModes[BulkCollectionType.sightings];
    if (sightingsMode != null) {
      ops.add(SightingsOp(mode: sightingsMode, sightings: _sightings));
    }
    return ops;
  }

  Future<void> _saveBulk(UnitFormatter units) async {
    // An unreadable number must not reach a write across many dives.
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final ids = widget.diveIds;

    // Contradiction guard: mode = OC cannot carry rebreather settings.
    const rebreatherFields = {
      BulkField.setpointLow,
      BulkField.setpointHigh,
      BulkField.setpointDeco,
      BulkField.scrubberType,
      BulkField.scrubberDuration,
    };
    if (_bulkEnabled.contains(BulkField.diveMode) &&
        _diveMode == DiveMode.oc &&
        _bulkEnabled.any(rebreatherFields.contains)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.diveLog_bulkEdit_contradiction)),
      );
      return;
    }

    // The My role gate rides DiverRolesOp (#1221) and the Site gate SiteOp
    // (#3657), not a scalar column.
    final scalarFields = Set<BulkField>.from(_bulkEnabled)
      ..remove(BulkField.diverRole)
      ..remove(BulkField.site);
    String? notesAppend;
    if (_bulkEnabled.contains(BulkField.notes) && _bulkNotesAppend) {
      scalarFields.remove(BulkField.notes);
      notesAppend = _notesController.text;
    }
    final scalars = buildScalarCompanion(
      scalarFields,
      _collectScalarInputs(units),
    );
    final ops = _collectCollectionOps();
    final hasScalar = scalars.toColumns(false).isNotEmpty;
    if (!hasScalar &&
        (notesAppend == null || notesAppend.isEmpty) &&
        ops.isEmpty) {
      // An incomplete tank intent only blocks the save when it is the whole
      // request; alongside other changes it no-ops, as every other collection
      // does with an empty payload. Name the tank case so the hint is
      // actionable rather than the generic "nothing selected".
      final tanksUpdateEmpty =
          _collectionModes[BulkCollectionType.tanks] ==
              BulkCollectionMode.update &&
          _bulkTankSpecFields.isEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tanksUpdateEmpty
                ? l10n.diveLog_bulkEdit_tankSpecsNoFields
                : l10n.diveLog_bulkEdit_nothingSelected,
          ),
        ),
      );
      return;
    }

    // An in-place tank update skips dives with no tanks; warn before applying.
    final skipped = ops.any((o) => o is TankSpecsOp)
        ? await ref.read(diveRepositoryProvider).divesWithoutTanksCount(ids)
        : 0;
    // Roles by position leave dives whose tanks do not line up alone (#4412).
    final slotRoles = ops.whereType<TankSpecsOp>().firstOrNull?.slotRoles;
    final roleSkipped = slotRoles == null
        ? 0
        : await ref
              .read(diveRepositoryProvider)
              .divesWithSlotRoleMismatchCount(ids, slotRoles);
    if (!mounted) return;

    // Name every membership change up front: a stray removal otherwise lands
    // on every selected dive with nothing but "Apply changes?" to warn (#1754).
    final changes = summarizeBulkMembership([
      (
        title: l10n.diveLog_edit_section_tags,
        delta: _tagDelta,
        members: _tagMembers,
      ),
      (
        title: l10n.diveLog_edit_label_diveTypes,
        delta: _diveTypeDelta,
        members: _diveTypeMembers,
      ),
      (
        title: l10n.diveLog_edit_section_trainingCourses,
        delta: _courseDelta,
        members: _courseMembers,
      ),
      (
        title: l10n.diveLog_edit_section_equipment,
        delta: _equipmentDelta,
        // Only names the ids; the summary sorts them A to Z itself.
        members: [
          for (final e in _bulkGear)
            BulkMembershipItem(id: e.id, label: e.name),
        ],
      ),
      (
        title: l10n.diveLog_edit_group_buddies,
        delta: _buddyDelta,
        members: _buddyMembers,
      ),
      (
        title: l10n.diveLog_bulkEdit_equipmentSets,
        delta: MembershipDelta(
          [for (final s in _equipmentSetAdds) s.id],
          [for (final s in _equipmentSetRemovals) s.id],
        ),
        members: [
          for (final s in [..._equipmentSetAdds, ..._equipmentSetRemovals])
            BulkMembershipItem(id: s.id, label: s.name),
        ],
      ),
    ]);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.diveLog_bulkEdit_confirmTitle),
        content: skipped > 0 || roleSkipped > 0 || changes.isNotEmpty
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (changes.isNotEmpty)
                      BulkChangeSummary(
                        sections: changes,
                        addingHeading: l10n.diveLog_bulkEdit_confirmAdding(
                          ids.length,
                        ),
                        removingHeading: l10n.diveLog_bulkEdit_confirmRemoving(
                          ids.length,
                        ),
                      ),
                    if (skipped > 0)
                      Text(l10n.diveLog_bulkEdit_tankSpecsSkipped(skipped)),
                    if (roleSkipped > 0)
                      Text(l10n.diveLog_bulkEdit_tankRolesSkipped(roleSkipped)),
                  ],
                ),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.diveLog_bulkEdit_confirmApply),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _update(() => _isSaving = true);
    try {
      final service = ref.read(bulkDiveEditServiceProvider);
      final snapshot = await service.apply(
        BulkEditRequest(
          diveIds: ids,
          scalars: scalars,
          notesAppend: notesAppend,
          ops: ops,
        ),
      );
      // Queue a data-quality rescan of the edited dives (fire-and-forget).
      scheduleQualityScan(ids);
      scheduleSensorSummaryRefresh(ids);
      scheduleDerivedMetricsRefresh(ids);
      if (_bulkEnabled.contains(BulkField.visibility)) {
        _rememberVisibilityMode(_bulkVisibility(units));
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (widget.embedded) {
        widget.onSaved?.call(ids.first);
      } else if (widget.popOnSave) {
        context.pop();
      } else {
        context.go('/dives');
      }
      final stretched = tripDateStretchMessage(
        l10n,
        units,
        snapshot.tripDateStretches,
      );
      final applied = l10n.diveLog_bulkEdit_applied(ids.length);
      messenger.showSnackBar(
        SnackBar(
          content: Text(stretched == null ? applied : '$applied\n$stretched'),
          duration: const Duration(seconds: 5),
          // A SnackBar with an action defaults to persist: true, which makes the
          // auto-dismiss timer a no-op so the banner never hides on its own.
          // Force the 5s auto-dismiss and add a close icon so the banner can be
          // dismissed without tapping Undo (which would revert the edit). #406.
          persist: false,
          showCloseIcon: true,
          action: SnackBarAction(
            label: l10n.diveLog_bulkDelete_undo,
            onPressed: () => service.undo(snapshot),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.diveLog_edit_snackbar_errorSaving(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) _update(() => _isSaving = false);
    }
  }
}
