part of 'dive_edit_page.dart';

/// The gas switch list under the cylinders (issue #32): how the page loads
/// it, answers the editor and saves it. A part of the page, so the page
/// itself grows by its five fields, one setState seam and four call sites.
extension _GasSwitchEditing on _DiveEditPageState {
  /// With one breathing cylinder there is nothing to switch to (a suit
  /// inflation bottle is not one, issue #4243); a gauge dive logs no gas; a
  /// planned dive's switches belong to the plan.
  bool get _gasSwitchesVisible => gasSwitchesEditable(
    breathingTankCount: breathingTanks(_tanks).length,
    mode: _diveMode,
    isPlanned: _isPlanned,
  );

  /// The switches that apply to the dive's primary computer: its own plus
  /// any that carry no computer. Another computer's are left alone, and a
  /// dive with no primary computer shows the untagged ones only.
  Future<List<GasSwitch>> _loadGasSwitches(Dive dive) async {
    final withTank = await ref
        .read(diveRepositoryProvider)
        .getGasSwitchesForDive(dive.id);
    final computer = dive.computerId;
    return _inTimeOrder([
      for (final g in withTank)
        if (g.gasSwitch.shownInEditor(computer)) g.gasSwitch,
    ]);
  }

  /// Time order, ties broken by id so two rows at one second (a time being
  /// typed over another) never swap between builds.
  static List<GasSwitch> _inTimeOrder(List<GasSwitch> switches) =>
      [...switches]..sort(
        (a, b) => a.timestamp != b.timestamp
            ? a.timestamp.compareTo(b.timestamp)
            : a.id.compareTo(b.id),
      );

  /// The latest second a switch may fall on: the profile's last sample,
  /// else the runtime field, else the bottom time, else exit minus entry;
  /// null when nothing says how long the dive was.
  int? get _gasSwitchMaxTimestamp {
    final profile = _existingDive?.profile;
    if (profile != null && profile.isNotEmpty) return profile.last.timestamp;
    final runtime = _savedNumber(_runtimeController, integer: true);
    if (runtime != null) return runtime.toInt() * 60;
    final bottomTime = _savedNumber(_durationController, integer: true);
    if (bottomTime != null) return bottomTime.toInt() * 60;
    final exit = _exitInput();
    if (exit != null) {
      final seconds = exit.difference(_entryInput()).inSeconds;
      if (seconds > 0) return seconds;
    }
    return null;
  }

  /// The earliest second a switch may fall on: 0, else the profile's first
  /// sample or a loaded switch when either lies before it. A second
  /// computer can start before the primary one (#4296), and a switch it
  /// logged then must not block the save (#4335).
  int get _gasSwitchMinTimestamp {
    final profile = _existingDive?.profile ?? const <DiveProfilePoint>[];
    final profileStart = profileTimeDomain(profile).min;
    return profileStart < _loadedGasSwitchFloor
        ? profileStart
        : _loadedGasSwitchFloor;
  }

  /// What the editor changes to match the cylinder pressures (#4335), or
  /// null before they load, on a new dive, and off open circuit.
  GasSwitchEdits? get _detectedGasSwitchEdits {
    final diveId = widget.diveId;
    if (diveId == null || _diveMode != DiveMode.oc) return null;
    final detected = ref.watch(detectedGasSwitchesProvider(diveId)).value;
    if (detected == null) return null;
    // The detector places a starting switch at the profile's first sample,
    // which a computer can log after 0; a row there is the starting row.
    final profile = _existingDive?.profile ?? const <DiveProfilePoint>[];
    final firstSample = profile.isEmpty
        ? 0
        : profile.map((p) => p.timestamp).reduce((a, b) => a < b ? a : b);
    return detectedGasSwitchEdits(
      switches: _gasSwitches,
      tanks: _tanks,
      detected: detected,
      diveStart: firstSample > 0 ? firstSample : 0,
    );
  }

  DiveTank? get _gasSwitchStartingTank => startingTankOf(
    tanks: _tanks,
    switches: _gasSwitches,
    diveStart: 0,
    onLoop: _diveMode == DiveMode.ccr || _diveMode == DiveMode.scr,
  );

  Widget? _buildGasSwitchesChild(UnitFormatter units) {
    if (!_gasSwitchesVisible) return null;
    final diveId = widget.diveId;
    final profile = _existingDive?.profile ?? const <DiveProfilePoint>[];
    final detected = _detectedGasSwitchEdits;
    // .value keeps the last result through a reload, so the chips stay put
    // while a pressure write is read back.
    return GasSwitchesEditor(
      switches: _gasSwitches,
      tanks: _tanks,
      units: units,
      maxTimestamp: _gasSwitchMaxTimestamp,
      minTimestamp: _gasSwitchMinTimestamp,
      startingTank: _gasSwitchStartingTank,
      removedWithTankCount: _removedSwitchNotice,
      onChanged: _onGasSwitchChanged,
      onRemove: _removeGasSwitch,
      onAdd: _addGasSwitch,
      onTimeSettled: _onGasSwitchTimeSettled,
      breathStarts: diveId == null
          ? const {}
          : ref.watch(cylinderBreathStartsProvider(diveId)).value ?? const {},
      onPickTime: canPickOnProfile(profile)
          ? (sw) => _pickGasSwitchTime(sw, profile, units)
          : null,
      detectedEditCount: detected == null ? 0 : gasSwitchEditCount(detected),
      onFillDetected: detected == null
          ? null
          : () => _fillDetectedGasSwitches(detected),
    );
  }

  /// Applies [edits]: re-points the rows it names and adds a row for each
  /// switch it adds, with the depth filled from the profile as a typed time
  /// would. One edit like any other, undone by leaving without saving.
  /// Only reached with edits to make: the editor shows the action for a
  /// positive count alone.
  void _fillDetectedGasSwitches(GasSwitchEdits edits) {
    final now = DateTime.now();
    _updateGasSwitches(() {
      _markDirty();
      _gasSwitchesDirty = true;
      _removedSwitchNotice = 0;
      _gasSwitches = _inTimeOrder([
        for (final s in _gasSwitches)
          if (edits.retanked[s.id] case final tankId?)
            s.copyWith(tankId: tankId)
          else
            s,
        for (final missed in edits.added)
          GasSwitch(
            id: _uuid.v4(),
            diveId: widget.diveId ?? '',
            timestamp: missed.t,
            tankId: missed.tankId,
            depth: _profileDepthForSwitch(missed.t) ?? missed.depth,
            createdAt: now,
          ),
      ]);
    });
  }

  /// Picks [sw]'s time on the profile. A picked time is the same edit as a
  /// typed one followed by leaving the field.
  Future<void> _pickGasSwitchTime(
    GasSwitch sw,
    List<DiveProfilePoint> profile,
    UnitFormatter units,
  ) async {
    final diveId = widget.diveId;
    // Awaited, not read as a value: the breath starts above keep the family
    // loaded while this section shows, but a pick made before it finishes
    // loading still gets the recorded pressures.
    final recorded = diveId == null
        ? null
        : await ref
              .read(tankPressuresProvider(diveId).future)
              .then<Map<String, List<TankPressurePoint>>?>(
                (value) => value,
                onError: (Object _) => null,
              );
    if (!mounted) return;
    final seconds = await showGasSwitchTimeSheet(
      context,
      profile: profile,
      initialSeconds: sw.timestamp,
      units: units,
      tanks: _tanks,
      tankId: sw.tankId,
      tankPressures: {for (final tank in _tanks) tank.id: ?recorded?[tank.id]},
      gasSwitches: [
        for (final other in _gasSwitches)
          if (other.id != sw.id)
            if (_tanks.where((t) => t.id == other.tankId).firstOrNull
                case final tank?)
              GasSwitchWithTank(
                gasSwitch: other,
                tankName: tank.name ?? '',
                gasMix: tank.gasMix.name,
                o2Fraction: tank.gasMix.o2 / 100,
                heFraction: tank.gasMix.he / 100,
              ),
      ],
    );
    if (!mounted || seconds == null || seconds == sw.timestamp) return;
    _onGasSwitchChanged(sw.copyWith(timestamp: seconds), GasSwitchField.time);
    _onGasSwitchTimeSettled(sw.id);
  }

  /// A time field was left: now the row takes its place in time order,
  /// which it must not do while the time is still being typed.
  void _onGasSwitchTimeSettled(String id) {
    final ordered = _inTimeOrder(_gasSwitches);
    if (listEquals(ordered, _gasSwitches)) return;
    _updateGasSwitches(() => _gasSwitches = ordered);
  }

  /// The profile's depth at [timestamp], or null; with no profile there is
  /// nothing to fill from and the depth stands.
  double? _profileDepthForSwitch(int timestamp) {
    final profile = _existingDive?.profile ?? const <DiveProfilePoint>[];
    return profileDepthAt(profile, timestamp);
  }

  void _onGasSwitchChanged(GasSwitch updated, GasSwitchField field) {
    _updateGasSwitches(() {
      _markDirty();
      _gasSwitchesDirty = true;
      _removedSwitchNotice = 0;
      var next = updated;
      if (field == GasSwitchField.depth) {
        _depthTouchedSwitchIds = {..._depthTouchedSwitchIds, updated.id};
      } else if (field == GasSwitchField.time &&
          !_depthTouchedSwitchIds.contains(updated.id) &&
          (_existingDive?.profile.isNotEmpty ?? false)) {
        final depth = _profileDepthForSwitch(updated.timestamp);
        next = depth == null
            ? updated.copyWith(clearDepth: true)
            : updated.copyWith(depth: depth);
      }
      _gasSwitches = [for (final s in _gasSwitches) s.id == next.id ? next : s];
    });
  }

  /// A new row a minute after the last switch (at the start with none),
  /// within the dive, onto the first breathing cylinder not breathed at that
  /// moment (see [newGasSwitchTank]); none without a breathing cylinder.
  void _addGasSwitch() {
    var timestamp = 0;
    for (final s in _gasSwitches) {
      if (s.timestamp + 60 > timestamp) timestamp = s.timestamp + 60;
    }
    final max = _gasSwitchMaxTimestamp;
    if (max != null && timestamp > max) timestamp = max;
    final tank = newGasSwitchTank(
      tanks: _tanks,
      switches: _gasSwitches,
      timestamp: timestamp,
      startingTankId: _gasSwitchStartingTank?.id,
    );
    if (tank == null) return;
    final added = GasSwitch(
      id: _uuid.v4(),
      diveId: widget.diveId ?? '',
      timestamp: timestamp,
      tankId: tank.id,
      depth: _profileDepthForSwitch(timestamp),
      createdAt: DateTime.now(),
    );
    _updateGasSwitches(() {
      _markDirty();
      _gasSwitchesDirty = true;
      _removedSwitchNotice = 0;
      _gasSwitches = _inTimeOrder([..._gasSwitches, added]);
    });
  }

  void _removeGasSwitch(String id) {
    _updateGasSwitches(() {
      _markDirty();
      _gasSwitchesDirty = true;
      _removedSwitchNotice = 0;
      _gasSwitches = [
        for (final s in _gasSwitches)
          if (s.id != id) s,
      ];
    });
  }

  /// Runs inside the setState that removes or replaces cylinders: a switch
  /// whose cylinder is no longer in [_tanks] goes with it, whether the
  /// cylinder was removed by hand or swapped for a copy under a new id
  /// (Apply last dive), and the list says how many until the next edit. A
  /// switch left pointing at a gone cylinder would be saved against a row
  /// the dive save has just deleted.
  void _dropGasSwitchesWithoutTank() {
    final tankIds = {for (final t in _tanks) t.id};
    final kept = [
      for (final s in _gasSwitches)
        if (tankIds.contains(s.tankId)) s,
    ];
    final dropped = _gasSwitches.length - kept.length;
    if (dropped == 0) return;
    _gasSwitches = kept;
    _gasSwitchesDirty = true;
    _removedSwitchNotice = dropped;
  }

  /// After the dive and its cylinders are written. A list the diver never
  /// touched writes nothing, so the dive keeps today's re-parse behaviour.
  /// Dirty alone, not visibility: a cylinder removed from a planned dive
  /// takes its switches with it and marks the plan edited too, which is
  /// harmless since the planned-dive fill does not read the flag.
  Future<void> _saveGasSwitches(String? savedDiveId) async {
    if (savedDiveId == null || !_gasSwitchesDirty) return;
    await DiverGasSwitchWriter().save(
      diveId: savedDiveId,
      switches: [for (final s in _gasSwitches) s.copyWith(diveId: savedDiveId)],
      loadedIds: _loadedGasSwitchIds,
    );
    // What is stored now is what a further save on this page diffs against.
    _loadedGasSwitchIds = {for (final s in _gasSwitches) s.id};
    _gasSwitchesDirty = false;
  }
}
