part of 'dive_edit_page.dart';

/// Using an equipment set on the dive form (issue #4525): its gear, then
/// the weights and cylinders it carries. A part of the page, so the page
/// itself grows by one setState seam and its four call sites.
extension _SetBundleApplying on _DiveEditPageState {
  /// Puts [set] on the form. [items] is its gear as the caller loaded it.
  /// [auto] is an apply nobody asked for (the default set, a location
  /// match): it asks nothing, overwrites nothing and leaves the form clean.
  Future<void> _useSet(
    EquipmentSet set,
    List<EquipmentItem> items, {
    required bool auto,
  }) async {
    final covered = await _coveredByOuterSet(set);
    if (!mounted) return;
    final absorbedWeights = await _absorbIncludedSets(set, auto: auto);
    if (!mounted) return;
    await _addGear(items, viaSetId: set.id, markDirty: !auto);
    if (!mounted) return;

    SetBundle? bundle;
    try {
      bundle = await ref.read(setBundleProvider(set.id).future);
    } catch (_) {
      // Sets unavailable (no database in a widget test): gear only.
      bundle = null;
    }
    if (bundle == null || !mounted) return;
    await _applySetWeights(
      set,
      bundle,
      absorbedWeights,
      auto: auto,
      coveredByOuterSet: covered,
    );
    if (!mounted) return;
    await _applySetCylinders(set, bundle, auto: auto);
  }

  /// Whether a set already on the form includes [set]: its lead is then
  /// already counted, and adding it again would double it.
  Future<bool> _coveredByOuterSet(EquipmentSet set) async {
    final others = {
      for (final row in _gearRows)
        if (row.viaSetId != null && row.viaSetId != set.id) row.viaSetId!,
    };
    if (others.isEmpty) return false;
    try {
      final onForm = await ref
          .read(equipmentSetRepositoryProvider)
          .getAllSets(ids: others.toList());
      return onForm.any((outer) => outer.includedSetIds.contains(set.id));
    } catch (_) {
      // Sets unavailable: the question is asked as usual.
      return false;
    }
  }

  /// A picked set absorbs the sets it includes that are already on the
  /// form: their gear takes its tag, so the dive shows one set. Returns the
  /// weights those sets filled in between them, or null when none was on
  /// the form.
  Future<List<WeightEntryDraft>?> _absorbIncludedSets(
    EquipmentSet set, {
    required bool auto,
  }) async {
    final onForm = {for (final row in _gearRows) ?row.viaSetId};
    final absorbed = [
      for (final id in set.includedSetIds)
        if (id != set.id && onForm.contains(id)) id,
    ];
    if (absorbed.isEmpty) return null;

    var weights = const <WeightEntryDraft>[];
    try {
      final bundles = await ref.read(setBundleLoaderProvider).load(absorbed);
      weights = [for (final b in bundles) ...b.weights];
    } catch (_) {
      // The tags still move; the weights question is then asked as usual.
    }
    if (!mounted) return weights;
    final rows = [
      for (final row in _gearRows)
        absorbed.contains(row.viaSetId)
            ? GearProvenance(
                equipmentId: row.equipmentId,
                viaEquipmentId: row.viaEquipmentId,
                viaSetId: set.id,
              )
            : row,
    ];
    _applyBundleChange(() {
      if (!auto) _markDirty();
      _gearProvenance = rows;
    });
    return weights;
  }

  Future<void> _applySetWeights(
    EquipmentSet set,
    SetBundle bundle,
    List<WeightEntryDraft>? absorbedWeights, {
    required bool auto,
    bool coveredByOuterSet = false,
  }) async {
    List<DiveWeight> fromSet() =>
        bundle.toDiveWeights(diveId: widget.diveId ?? '', newId: _uuid.v4);
    var step = planSetWeights(
      onDive: _weights,
      bundleWeights: bundle.weights,
      absorbedWeights: absorbedWeights,
      auto: auto,
      coveredByOuterSet: coveredByOuterSet,
    );
    var add = false;
    if (step == SetWeightsStep.ask) {
      final units = UnitFormatter(ref.read(settingsProvider));
      final choice = await showSetWeightsChoiceDialog(
        context,
        setName: set.name,
        setTotal: units.formatWeight(bundle.totalWeightKg),
        currentTotal: units.formatWeight(
          _weights.fold<double>(0, (sum, w) => sum + w.amountKg),
        ),
      );
      if (!mounted) return;
      switch (choice) {
        case SetWeightsChoice.add:
          add = true;
          step = SetWeightsStep.fill;
        case SetWeightsChoice.replace:
          step = SetWeightsStep.replace;
        case SetWeightsChoice.keep || null:
          step = SetWeightsStep.leave;
      }
    }
    if (step != SetWeightsStep.fill && step != SetWeightsStep.replace) return;
    _applyBundleChange(() {
      if (!auto) _markDirty();
      _weights = [if (add) ..._weights, ...fromSet()];
    });
  }

  Future<void> _applySetCylinders(
    EquipmentSet set,
    SetBundle bundle, {
    required bool auto,
  }) async {
    if (bundle.cylinders.isEmpty) return;
    const adapter = DiveTankConfigAdapter();
    // A new dive still holding its untouched starter tank takes the set's
    // cylinders whole, gas included: the merge below never writes a mix
    // onto a matched tank, and the starter's air is nobody's choice. A tank
    // a scan or a cylinder tag prefilled is the diver's data and merges.
    final untouchedStarter =
        !_tanksDirty &&
        !_firstTankPrefilled &&
        !widget.isEditing &&
        _tanks.length == 1;
    var result = adapter.apply(
      tanks: untouchedStarter ? const <DiveTank>[] : _tanks,
      items: bundle.cylinders,
      newId: (_) => _uuid.v4(),
    );
    if (result.overwrites.isNotEmpty && !auto) {
      final confirmed = await confirmCylinderOverwrites(
        context,
        configName: set.name,
        overwrites: result.overwrites,
        tanks: _tanks,
        units: UnitFormatter(ref.read(settingsProvider)),
      );
      // Declining keeps the gear and weights already applied.
      if (!confirmed || !mounted) return;
      result = adapter.apply(
        tanks: _tanks,
        items: bundle.cylinders,
        newId: (_) => _uuid.v4(),
        overwrite: true,
      );
    }
    if (!result.changed) return;
    final tanks = result.tanks;
    _applyBundleChange(() {
      if (!auto) _markDirty();
      // Also stops the default tank preset, which loads late, from
      // rewriting cylinders the set just placed.
      _tanksDirty = true;
      _tankRowGeneration++;
      _tanks
        ..clear()
        ..addAll(tanks);
    });
  }
}
