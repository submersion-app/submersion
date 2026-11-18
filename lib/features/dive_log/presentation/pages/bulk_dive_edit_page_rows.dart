part of 'bulk_dive_edit_page.dart';

/// The pickers and rows bulk edit shares in shape with a dive's own cards: site area, trip, dive center, tanks, visibility, weights and sightings.
extension _BulkDiveEditRows on _BulkDiveEditPageState {
  /// Where this dive probably was, from the dives logged around it: the
  /// site of the nearest dive of the same trip, else of one within a few
  /// days. For a dive with no GPS of its own, so the picker can lead with
  /// the sites of that area. Null when nothing says; never fails the picker.
  Future<SiteAreaAnchor?> _areaAnchor() async {
    try {
      final repository = ref.read(siteAreaAnchorRepositoryProvider);
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      return await repository.forDives(widget.diveIds, diverId: diverId);
    } catch (e, stackTrace) {
      _BulkDiveEditPageState._log.warning(
        'Could not work out the area of the dive for the site picker',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Every change of the dive's trip goes through here. Tank links point
  /// into one trip's cylinders, so a different trip (or none) drops them
  /// all at once, with their suggestion marks, and new tanks get a
  /// suggestion from the new trip.
  void _setTrip(Trip? trip, {bool markDirty = true}) {
    if (markDirty) _markDirty();
    final changed = trip?.id != _selectedTrip?.id;
    _update(() {
      _selectedTrip = trip;
      if (changed && _tanks.any((t) => t.tripCylinderId != null)) {
        _tanks = [
          for (final t in _tanks)
            t.tripCylinderId == null
                ? t
                : t.copyWith(clearTripCylinderId: true),
        ];
        _tanksDirty = true;
      }
    });
  }

  Future<void> _showTripPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => TripPickerSheet(
          scrollController: scrollController,
          selectedTrip: _selectedTrip,
          onTripSelected: (trip) {
            Navigator.of(sheetContext).pop();
            _setTrip(trip);
          },
          onCreateNewTrip: () {
            Navigator.of(sheetContext).pop(_createNewTripSentinel);
          },
        ),
      ),
    );

    if (result == _createNewTripSentinel && mounted) {
      final tripId = await newTripForDiveEdit(context, ref, _newTripFacts);
      if (tripId != null && mounted) {
        final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
        if (trip != null && mounted) _setTrip(trip);
      }
    }
  }

  /// What a trip created from this form learns from its dives (#3351): the
  /// selected dives in bulk edit, else the dive as the form holds it, saved
  /// or not.
  Future<List<SelectionDiveFacts>> _newTripFacts() =>
      loadSelectionTripFacts(widget.diveIds);

  Future<void> _showDiveCenterPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => DiveCenterPickerSheet(
          scrollController: scrollController,
          selectedCenter: _selectedDiveCenter,
          // Centers near the chosen site first (#3379); the dives being
          // edited have no one position of their own.
          reference: resolveDiveCenterPickerReference(site: _selectedSite),
          onCenterSelected: (center) {
            Navigator.of(sheetContext).pop();
            _markDirty();
            _update(() => _selectedDiveCenter = center);
          },
          onCreateNewCenter: () {
            Navigator.of(sheetContext).pop(_createNewDiveCenterSentinel);
          },
        ),
      ),
    );

    if (result == _createNewDiveCenterSentinel && mounted) {
      final centerId = await context.push<String>('/dive-centers/new');
      if (centerId != null && mounted) {
        final repo = ref.read(diveCenterRepositoryProvider);
        final center = await repo.getDiveCenterById(centerId);
        if (center != null && mounted) {
          _markDirty();
          _update(() => _selectedDiveCenter = center);
        }
      }
    }
  }

  void _addTank() {
    final settings = ref.read(settingsProvider);
    _update(() {
      _markDirty();
      _tanksDirty = true;
      _tanks.add(
        DiveTank(
          id: _uuid.v4(),
          volume: _defaultPreset?.volumeLiters ?? settings.defaultTankVolume,
          workingPressure: _defaultPreset?.workingPressureBar,
          startPressure: settings.defaultStartPressure,
          endPressure: 50.0,
          gasMix: const GasMix(),
          role: _tanks.isEmpty ? TankRole.backGas : TankRole.stage,
          material: _defaultPreset?.material,
          order: _tanks.length,
          presetName: _defaultPreset?.name,
        ),
      );
    });
  }

  void _removeTank(int index) {
    _update(() {
      _markDirty();
      _tanksDirty = true;
      _tanks.removeAt(index);
      // Update order for remaining tanks
      for (var i = 0; i < _tanks.length; i++) {
        _tanks[i] = _tanks[i].copyWith(order: i);
      }
    });
  }

  /// The visibility field's value converted to meters, or null when the field
  /// is empty or does not parse. See [parseVisibilityInput].
  double? _visibilityMetersInput(UnitFormatter units) =>
      parseVisibilityInput(_visibilityController.text, units);

  VisibilityScale get _visibilityScale =>
      ref.read(settingsProvider).visibilityScale;

  /// Remembers the mode [saved] was entered in for the next new dive. A
  /// convenience after a save that already succeeded, so a failure is
  /// logged, never reported as a failed save.
  void _rememberVisibilityMode(StoredVisibility saved) {
    final mode = saved.modeToRemember;
    if (mode == null) return;
    unawaited(
      ref
          .read(visibilityInputModeProvider.notifier)
          .remember(mode)
          .catchError(
            (Object e) => _BulkDiveEditPageState._log.warning(
              'Could not remember the visibility mode: $e',
            ),
          ),
    );
  }

  /// The Range | Precise visibility input (issue #3226), shared by the dive
  /// form and bulk edit.
  Widget _visibilityInput(
    UnitFormatter units, {
    String? Function(String?)? validator,
  }) {
    final scale = ref.watch(settingsProvider.select((s) => s.visibilityScale));
    final band = effectiveVisibilityBand(
      band: _visibilityBand,
      rangeTouched: _rangeTouched,
      original: StoredVisibility.none,
      scale: scale,
    );
    return VisibilityInput(
      mode: _visibilityMode,
      onModeChanged: (m) {
        _update(() => _visibilityMode = m);
        _markDirty();
      },
      controller: _visibilityController,
      depthSymbol: units.depthSymbol,
      inputValidator: validator ?? numberValidator(context),
      onPreciseChanged: (_) => _update(() => _preciseTouched = true),
      band: band,
      onBandChanged: (b) {
        _update(() {
          _visibilityBand = b;
          _rangeTouched = true;
        });
        _markDirty();
      },
      caption: visibilityEntryCaption(
        mode: _visibilityMode,
        preciseMeters: _visibilityMetersInput(units),
        band: band,
        preciseTouched: _preciseTouched,
        rangeTouched: _rangeTouched,
        original: StoredVisibility.none,
        scale: scale,
        l10n: context.l10n,
        units: units,
      ),
    );
  }

  Widget _weightChild(UnitFormatter units) {
    // The selected dives' gear differs from dive to dive, so the total is
    // the weight rows alone.
    final totalWeight = editorWeightTotalKg(_weights, const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormOverline(
          label: context.l10n.diveLog_edit_section_weight,
          trailingText: totalWeight == null
              ? null
              : context.l10n.diveLog_edit_weightTotal(
                  units.formatWeight(totalWeight),
                ),
          actions: [
            FormOverlineAction(
              label: context.l10n.diveLog_edit_weightPreset_use,
              icon: Icons.fitness_center,
              onPressed: _applyWeightPreset,
            ),
            if (_weights.any((w) => w.amountKg > 0))
              FormOverlineAction(
                label: context.l10n.diveLog_edit_weightPreset_save,
                icon: Icons.bookmark_add_outlined,
                onPressed: _saveWeightsAsPreset,
              ),
          ],
        ),
        if (_weights.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final weight in _weights)
                  DiveWeightEntryRow(
                    key: ValueKey(weight.id),
                    weight: weight,
                    units: units,
                    onChanged: _replaceWeight,
                    onRemove: () => _update(() {
                      _markDirty();
                      _weights = [
                        for (final w in _weights)
                          if (w.id != weight.id) w,
                      ];
                    }),
                  ),
              ],
            ),
          ),
        FormAppendRow(
          label: context.l10n.diveLog_edit_addWeightEntry,
          onTap: () {
            _update(() {
              _markDirty();
              _weights = [
                ..._weights,
                DiveWeight(
                  id: _uuid.v4(),
                  diveId: '',
                  weightType: WeightType.integrated,
                  amountKg: 0,
                ),
              ];
            });
          },
        ),
      ],
    );
  }

  Future<void> _applyWeightPreset() async {
    final preset = await showModalBottomSheet<WeightPreset>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) =>
            WeightPresetPickerSheet(scrollController: scrollController),
      ),
    );
    if (preset == null || !mounted) return;
    _update(() {
      _markDirty();
      _weights = preset.toDiveWeights(diveId: '', newId: _uuid.v4);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.diveLog_edit_weightPreset_applied)),
    );
  }

  /// Save the current weighting as a named, reusable preset (issue #1609).
  Future<void> _saveWeightsAsPreset() async {
    // Resolve the diver the same way weightPresetsProvider does -- fall back to
    // the default diver when the current-diver pref is unset, so "Save as
    // preset" works wherever "Use preset" does.
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    final name = await NamePromptDialog.show(
      context,
      title: context.l10n.diveLog_edit_weightPreset_saveTitle,
      label: context.l10n.diveLog_edit_weightPreset_nameLabel,
      confirmLabel: context.l10n.common_action_save,
    );
    if (name == null || !mounted) return;

    final weights = _weights.where((w) => w.amountKg > 0).toList();
    if (weights.isEmpty) return;
    await ref
        .read(weightPresetRepositoryProvider)
        .createFromWeights(
          diverId: diverId,
          displayName: name,
          weights: weights,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_weightPreset_saved(name)),
        ),
      );
    }
  }

  /// Stores an edited weight row. The row keeps its own fields current, and
  /// the Form's onChanged marks the page dirty; the page rebuilds only when
  /// the amount or placement changed, which the Total and "Save as preset"
  /// above the rows read. A name alone shows nowhere outside its row.
  void _replaceWeight(DiveWeight updated) {
    final previous = _weights.firstWhere((w) => w.id == updated.id);
    final next = [for (final w in _weights) w.id == updated.id ? updated : w];
    if (previous.amountKg == updated.amountKg &&
        previous.weightType == updated.weightType) {
      _weights = next;
    } else {
      _update(() => _weights = next);
    }
  }

  Widget _sightingsChild() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: SightingsEditor(
        sightings: _sightings,
        diveId: '',
        onChanged: (sightings) => _update(() {
          _markDirty();
          _sightings = sightings;
        }),
        // Bulk edit spans dives that may be at different sites, so there
        // is no one site to suggest from.
        siteId: null,
        siteName: _selectedSite?.name,
      ),
    );
  }
}
