part of 'bulk_dive_edit_page.dart';

/// Form rows of bulk edit: each row is gated by its own switch, and the sections that hold them.
extension _BulkDiveEditForm on _BulkDiveEditPageState {
  Widget _gatedRow(BulkField field, Widget child) {
    return BulkFieldGate(
      enabled: _bulkEnabled.contains(field),
      onChanged: (v) => _update(() {
        if (v) {
          _bulkEnabled.add(field);
        } else {
          _bulkEnabled.remove(field);
        }
        _markDirty();
      }),
      child: child,
    );
  }

  Widget _buildBulkForm(UnitFormatter units) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      onChanged: _markDirty,
      child: ResponsiveFormColumns(
        children: [
          FormSection(
            label: context.l10n.diveLog_bulkEdit_groupLogistics,
            expanded: true,
            onToggle: null,
            children: [
              _gatedRow(
                BulkField.site,
                FormRow.picker(
                  label: l10n.diveLog_edit_row_site,
                  value: _selectedSite?.name,
                  placeholder: l10n.diveLog_edit_row_notSet,
                  onTap: _showBulkSitePicker,
                  onClear: _selectedSite == null
                      ? null
                      : () => _update(() => _selectedSite = null),
                ),
              ),
              _gatedRow(
                BulkField.diveCenter,
                FormRow.picker(
                  label: l10n.diveLog_edit_row_diveCenter,
                  value: _selectedDiveCenter?.name,
                  placeholder: l10n.diveLog_edit_row_notSet,
                  onTap: _showDiveCenterPicker,
                  onClear: _selectedDiveCenter == null
                      ? null
                      : () => _update(() => _selectedDiveCenter = null),
                ),
              ),
              for (final (field, label, controller) in [
                (
                  BulkField.diveOperator,
                  l10n.diveLog_edit_row_diveOperator,
                  _diveOperatorController,
                ),
                (
                  BulkField.boatName,
                  l10n.diveLog_edit_row_boatName,
                  _boatNameController,
                ),
                (
                  BulkField.boatCaptain,
                  l10n.diveLog_edit_row_boatCaptain,
                  _boatCaptainController,
                ),
              ])
                _gatedRow(
                  field,
                  FormRow.text(
                    label: label,
                    controller: controller,
                    alwaysEditing: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              _gatedRow(
                BulkField.trip,
                FormRow.picker(
                  label: l10n.diveLog_edit_row_trip,
                  value: _selectedTrip?.name,
                  placeholder: l10n.diveLog_edit_row_notSet,
                  onTap: _showTripPicker,
                  onClear: _selectedTrip == null
                      ? null
                      : () => _setTrip(null, markDirty: false),
                ),
              ),
              _gatedRow(
                BulkField.rating,
                FormRow.rating(
                  label: l10n.diveLog_edit_section_rating,
                  value: _rating,
                  onChanged: (v) => _update(() => _rating = v),
                  clearTooltip: l10n.common_action_clearRating,
                ),
              ),
              _gatedRow(
                BulkField.isFavorite,
                FormRow.toggle(
                  label: context.l10n.diveLog_bulkEdit_fieldFavorite,
                  value: _bulkFavorite,
                  onChanged: (v) => _update(() => _bulkFavorite = v),
                ),
              ),
              _gatedRow(
                BulkField.excludedFromStats,
                FormRow.toggle(
                  label: context.l10n.diveLog_bulkEdit_fieldExcludeFromStats,
                  value: _bulkExcludedFromStats,
                  onChanged: (v) => _update(() => _bulkExcludedFromStats = v),
                ),
              ),
              _gatedRow(
                BulkField.excludedFromGasStats,
                FormRow.toggle(
                  label: context.l10n.diveLog_bulkEdit_fieldExcludeFromGasStats,
                  value: _bulkExcludedFromGasStats,
                  onChanged: (v) =>
                      _update(() => _bulkExcludedFromGasStats = v),
                ),
              ),
            ],
          ),
          _buildBulkConditionsSection(units),
          _buildBulkWeatherSection(units),
          _buildBulkRebreatherSection(units),
          _buildBulkCollectionsSection(units),
          FormSection(
            label: l10n.diveLog_edit_section_notes,
            expanded: true,
            onToggle: null,
            children: [
              _gatedRow(
                BulkField.notes,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.diveLog_bulkEdit_notesSet),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.diveLog_bulkEdit_notesAppend),
                        ),
                      ],
                      selected: {_bulkNotesAppend},
                      onSelectionChanged: (s) =>
                          _update(() => _bulkNotesAppend = s.first),
                    ),
                    const SizedBox(height: 8),
                    MarkdownNotesField(
                      controller: _notesController,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The bulk visibility value: bulk has no stored shape to keep, so the
  /// active mode's value is the input (issue #3226).
  StoredVisibility _bulkVisibility(UnitFormatter units) =>
      resolveVisibilityEntry(
        mode: _visibilityMode,
        preciseMeters: _visibilityMetersInput(units),
        band: _visibilityBand,
        preciseTouched: true,
        rangeTouched: true,
        original: StoredVisibility.none,
        scale: _visibilityScale,
      );

  Widget _enumDropdown<T extends Object>({
    required T? value,
    required List<T> options,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T?>(
      initialValue: value,
      items: <DropdownMenuItem<T?>>[
        DropdownMenuItem<T?>(
          value: null,
          child: Text(context.l10n.diveLog_edit_notSpecified),
        ),
        for (final o in options)
          DropdownMenuItem<T?>(value: o, child: Text(label(o))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildBulkConditionsSection(UnitFormatter units) {
    return FormSection(
      label: context.l10n.diveLog_edit_section_conditions,
      expanded: true,
      onToggle: null,
      children: [
        _gatedRow(
          BulkField.waterType,
          FormRow.custom(
            label: context.l10n.diveLog_edit_label_waterType,
            child: _enumDropdown<WaterType>(
              value: _waterType,
              options: WaterType.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() {
                _waterType = v;
              }),
            ),
          ),
        ),
        _gatedRow(
          BulkField.visibility,
          _visibilityInput(
            units,
            validator: _bulkValidator(BulkField.visibility),
          ),
        ),
        _gatedRow(
          BulkField.currentDirection,
          FormRow.custom(
            label: context.l10n.diveLog_edit_label_currentDirection,
            child: _enumDropdown<CurrentDirection>(
              value: _currentDirection,
              options: CurrentDirection.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() => _currentDirection = v),
            ),
          ),
        ),
        _gatedRow(
          BulkField.currentStrength,
          FormRow.custom(
            label: context.l10n.diveLog_edit_label_currentStrength,
            child: _enumDropdown<CurrentStrength>(
              value: _currentStrength,
              options: CurrentStrength.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() => _currentStrength = v),
            ),
          ),
        ),
        _gatedRow(
          BulkField.swellHeight,
          FormRow.text(
            label: context.l10n.diveLog_edit_label_swellHeight,
            controller: _swellHeightController,
            suffixText: units.depthSymbol,
            keyboardType: TextInputType.number,
            alwaysEditing: true,
            inputValidator: _bulkValidator(BulkField.swellHeight),
          ),
        ),
        _gatedRow(
          BulkField.surfaceConditions,
          FormRow.text(
            label: context.l10n.diveLog_edit_label_surfaceConditions,
            controller: _surfaceConditionsController,
            alwaysEditing: true,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        _gatedRow(
          BulkField.entryMethod,
          FormRow.custom(
            label: context.l10n.diveLog_edit_label_entryMethod,
            child: _enumDropdown<EntryMethod>(
              value: _entryMethod,
              options: EntryMethod.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() => _entryMethod = v),
            ),
          ),
        ),
        _gatedRow(
          BulkField.exitMethod,
          FormRow.custom(
            label: context.l10n.diveLog_edit_label_exitMethod,
            child: _enumDropdown<EntryMethod>(
              value: _exitMethod,
              options: EntryMethod.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() => _exitMethod = v),
            ),
          ),
        ),
        _gatedRow(
          BulkField.altitude,
          FormRow.text(
            label: context.l10n.diveLog_edit_label_altitude,
            controller: _altitudeController,
            keyboardType: TextInputType.number,
            alwaysEditing: true,
            inputValidator: _bulkValidator(BulkField.altitude),
          ),
        ),
        _gatedRow(
          BulkField.surfacePressure,
          FormRow.text(
            label: context.l10n.diveLog_edit_label_surfacePressure,
            controller: _surfacePressureController,
            keyboardType: TextInputType.number,
            alwaysEditing: true,
            inputValidator: _bulkValidator(BulkField.surfacePressure),
          ),
        ),
      ],
    );
  }

  Widget _buildBulkWeatherSection(UnitFormatter units) {
    return FormSection(
      label: context.l10n.diveLog_bulkEdit_groupWeather,
      expanded: true,
      onToggle: null,
      children: [
        _gatedRow(
          BulkField.windSpeed,
          FormRow.text(
            label: context.l10n.diveLog_edit_label_windSpeed,
            controller: _windSpeedController,
            keyboardType: TextInputType.number,
            alwaysEditing: true,
            inputValidator: _bulkValidator(BulkField.windSpeed),
          ),
        ),
        _gatedRow(
          BulkField.windDirection,
          FormRow.custom(
            label: context.l10n.diveLog_edit_label_windDirection,
            child: _enumDropdown<CurrentDirection>(
              value: _windDirection,
              options: CurrentDirection.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() => _windDirection = v),
            ),
          ),
        ),
        _gatedRow(
          BulkField.cloudCover,
          FormRow.custom(
            label: context.l10n.diveLog_edit_label_cloudCover,
            child: _enumDropdown<CloudCover>(
              value: _cloudCover,
              options: CloudCover.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() => _cloudCover = v),
            ),
          ),
        ),
        _gatedRow(
          BulkField.precipitation,
          FormRow.custom(
            label: context.l10n.diveLog_edit_label_precipitation,
            child: _enumDropdown<Precipitation>(
              value: _precipitation,
              options: Precipitation.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() => _precipitation = v),
            ),
          ),
        ),
        _gatedRow(
          BulkField.humidity,
          FormRow.text(
            label: context.l10n.diveLog_edit_label_humidity,
            controller: _humidityController,
            keyboardType: TextInputType.number,
            alwaysEditing: true,
            inputValidator: _bulkValidator(BulkField.humidity),
          ),
        ),
        _gatedRow(
          BulkField.weatherDescription,
          FormRow.text(
            label: context.l10n.diveLog_edit_label_weatherDescription,
            controller: _weatherDescriptionController,
            alwaysEditing: true,
          ),
        ),
      ],
    );
  }

  /// The number validator for bulk row [field], or none while the row is
  /// switched off: text in a row that will not be written must not block
  /// the save (#1900 review).
  FormFieldValidator<String>? _bulkValidator(BulkField field) =>
      _bulkEnabled.contains(field) ? numberValidator(context) : null;

  /// A bulk-edit number. It has no controller of its own, so it owns one
  /// through [_bulkNumberControllers]; [_saveBulk] validates the form first,
  /// so unreadable text never reaches the bulk write.
  Widget _bulkNumberField(
    BulkField field,
    ValueChanged<double?> onChanged, {
    bool integer = false,
  }) {
    final controller = _bulkNumberControllers.putIfAbsent(
      field,
      TextEditingController.new,
    );
    return NumberField(
      controller: controller,
      integer: integer,
      // A switched-off row is not written, so it cannot block the save.
      validates: _bulkEnabled.contains(field),
      decoration: const InputDecoration(isDense: true),
      onChanged: (read) => switch (read) {
        NumberValue(:final value) => onChanged(value),
        NumberBlank() => onChanged(null), // clears the setting, as before
        NumberInvalid() => null, // keep the last readable value
      },
    );
  }

  Widget _buildBulkRebreatherSection(UnitFormatter units) {
    return FormSection(
      label: context.l10n.diveLog_bulkEdit_groupRebreather,
      expanded: true,
      onToggle: null,
      children: [
        _gatedRow(
          BulkField.diveMode,
          FormRow.custom(
            label: context.l10n.diveLog_diveMode_title,
            child: _enumDropdown<DiveMode>(
              value: _diveMode,
              options: DiveMode.values,
              label: (v) => v.localizedName(context.l10n),
              onChanged: (v) => _update(() => _diveMode = v ?? DiveMode.oc),
            ),
          ),
        ),
        _gatedRow(
          BulkField.setpointLow,
          FormRow.custom(
            label: context.l10n.diveLog_bulkEdit_fieldSetpointLow,
            child: _bulkNumberField(
              BulkField.setpointLow,
              (v) => _setpointLow = v,
            ),
          ),
        ),
        _gatedRow(
          BulkField.setpointHigh,
          FormRow.custom(
            label: context.l10n.diveLog_bulkEdit_fieldSetpointHigh,
            child: _bulkNumberField(
              BulkField.setpointHigh,
              (v) => _setpointHigh = v,
            ),
          ),
        ),
        _gatedRow(
          BulkField.setpointDeco,
          FormRow.custom(
            label: context.l10n.diveLog_bulkEdit_fieldSetpointDeco,
            child: _bulkNumberField(
              BulkField.setpointDeco,
              (v) => _setpointDeco = v,
            ),
          ),
        ),
        _gatedRow(
          BulkField.scrubberType,
          FormRow.custom(
            label: context.l10n.diveLog_bulkEdit_fieldScrubberType,
            child: TextFormField(
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) => _scrubberType = v.isEmpty ? null : v,
            ),
          ),
        ),
        _gatedRow(
          BulkField.scrubberDuration,
          FormRow.custom(
            label: context.l10n.diveLog_bulkEdit_fieldScrubberDuration,
            child: _bulkNumberField(
              BulkField.scrubberDuration,
              (v) => _scrubberDurationMinutes = v?.toInt(),
              integer: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bulkTanksEditor(UnitFormatter units) {
    // Update edits the tanks each dive already has, so it takes a template plus
    // a field mask instead of a tank list (#797).
    if (_collectionModes[BulkCollectionType.tanks] ==
        BulkCollectionMode.update) {
      return BulkTankSpecsEditor(
        specs: _bulkTankSpecs,
        fields: _bulkTankSpecFields,
        slotRoles: _bulkTankSlotRoles,
        onSlotRolesChanged: (r) => _update(() {
          _markDirty();
          _bulkTankSlotRoles = r;
        }),
        onSpecsChanged: (t) => _update(() {
          _markDirty();
          _bulkTankSpecs = t;
        }),
        onFieldsChanged: (f) => _update(() {
          _markDirty();
          _bulkTankSpecFields = f;
        }),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _tanks.length; i++)
          TankRow(
            key: ValueKey(_tanks[i].id),
            tank: _tanks[i],
            tankNumber: i + 1,
            units: units,
            onChanged: (t) => _update(() {
              _markDirty();
              _tanks[i] = t;
            }),
            onRemove: () => _removeTank(i),
          ),
        TextButton.icon(
          onPressed: _addTank,
          icon: const Icon(Icons.add),
          label: Text(context.l10n.diveLog_edit_addTank),
        ),
        if (_collectionModes[BulkCollectionType.tanks] ==
            BulkCollectionMode.add)
          CheckboxListTile(
            value: _bulkTankOnlyIfEmpty,
            onChanged: (v) => _update(() => _bulkTankOnlyIfEmpty = v ?? false),
            title: Text(context.l10n.diveLog_bulkEdit_tankOnlyIfEmpty),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
      ],
    );
  }

  /// Localized name of the role currently staged for the bulk "My role" gate,
  /// or null when no role is staged (the row then shows its placeholder).
  String? _bulkDiverRoleLabel() {
    // Watched before the null check so the row stays subscribed while no role
    // is staged and relabels itself once the role list resolves.
    final rolesById =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    if (_diverRoleIds.isEmpty) return null;
    return rolesForIds(
      _diverRoleIds,
      rolesById,
    ).joinedLocalizedNames(context.l10n);
  }

  /// What the My role row says when no set is staged: Mixed when the
  /// selected dives' sets differ, otherwise Not set. A set the dives share is
  /// the row's value from the start, not a placeholder.
  String _bulkDiverRolePlaceholder() {
    final l10n = context.l10n;
    return _diverRolesMixed
        ? l10n.diveLog_bulkEdit_buddyRoleMixed
        : l10n.diveLog_edit_row_notSet;
  }

  Future<void> _showBulkDiverRolePicker() async {
    // Awaited rather than read off the AsyncValue: nothing here watches the
    // role list, so a plain read can hand back a still-loading empty list.
    final roles = await ref.read(allDiveRolesProvider.future);
    if (!mounted) return;
    final selection = await showDiveRoleSelector(
      context,
      title: context.l10n.buddies_picker_selectMyRole,
      roles: roles,
      hiddenRoleIds: ref.read(
        hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles),
      ),
      allowEmpty: true,
      selectedRoleIds: _diverRoleIds,
    );
    if (selection == null || !mounted) return;
    _update(() {
      _markDirty();
      _diverRoleIds = [for (final r in selection) r.id];
    });
  }

  /// The role ids to show for a buddy row, or null when the selection has no
  /// single answer: the buddy's links disagree across the selected dives, so
  /// [_existingBuddyRoleIds] (unanimous only) has nothing for them.
  List<String>? _bulkBuddyRoleIds(String id) {
    final picked = _buddyRoleById[id];
    if (picked != null) return [for (final r in picked) r.id];
    final existing = _existingBuddyRoleIds[id];
    if (existing != null) return existing;
    // Not on any selected dive yet (a fresh picker add): the link the save
    // will create defaults to Buddy, so say so rather than "Mixed".
    return (_buddyCounts[id] ?? 0) == 0 ? const [DiveRole.buddyId] : null;
  }

  String _bulkBuddyRoleLabel(String id) {
    final rolesById =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final roleIds = _bulkBuddyRoleIds(id);
    if (roleIds == null) return context.l10n.diveLog_bulkEdit_buddyRoleMixed;
    return rolesForIds(roleIds, rolesById).joinedLocalizedNames(context.l10n);
  }

  Future<void> _showBulkBuddyRolePicker(BulkMembershipItem item) async {
    final roles = await ref.read(allDiveRolesProvider.future);
    if (!mounted) return;
    final selection = await showDiveRoleSelector(
      context,
      title: context.l10n.buddies_picker_selectRole(item.label),
      roles: roles,
      hiddenRoleIds: ref.read(
        hiddenBuiltInIdsProvider(BuiltInCatalog.diveRoles),
      ),
      selectedRoleIds: _bulkBuddyRoleIds(item.id) ?? const [],
      keepRoleIds: [...?_existingBuddyRoleIds[item.id]],
      onCreateCustomRole: (name) => ref
          .read(diveRoleListNotifierProvider.notifier)
          .addDiveRoleByName(name),
    );
    if (selection == null || !mounted) return;
    _update(() {
      _markDirty();
      _buddyRoleById[item.id] = selection.isEmpty
          ? [DiveRole.builtInBuddy()]
          : selection;
    });
  }
}
