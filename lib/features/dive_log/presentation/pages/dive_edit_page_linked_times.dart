part of 'dive_edit_page.dart';

/// Entry, exit and runtime kept in step on the edit form (issue #241): the
/// pickers and the runtime field, and how each moves the others. A part of the
/// page, so the page itself grows by one field and one setState seam.
extension _LinkedTimeEditing on _DiveEditPageState {
  Future<void> _editEntry() async {
    _runtimeEditBase = null;
    var before = _timeInputs();
    await _selectEntryDate();
    if (!mounted) return;
    _followEntry(before);
    before = _timeInputs();
    await _selectEntryTime();
    if (!mounted) return;
    _followEntry(before);
  }

  Future<void> _editExit() async {
    _runtimeEditBase = null;
    final before = _exitInput();
    final seededBefore = _seededTimes;
    await _selectExitDate();
    if (!mounted) return;
    await _selectExitTime();
    if (!mounted) return;
    // A recorded exit picked again at its own minute changes nothing; an
    // estimate confirmed at its minute becomes an exit the runtime follows.
    if (_exitInput() == before && identical(_seededTimes, seededBefore)) {
      return;
    }
    _showRuntimeOfExit();
  }

  /// Moves the exit with the entry, so the dive keeps its length (issue
  /// #241). [before] is the form's time inputs before the entry moved.
  void _followEntry(DiveTimeInputs before) {
    final entry = _entryInput();
    if (entry == before.entry) return;
    _showLinkedTimes(moveDiveEntry(before, entry, seeded: _seededTimes));
  }

  /// Moves the exit to entry plus the runtime the diver typed (issue #241),
  /// linking from the times before the runtime edit began. Blank, unreadable
  /// or zero text puts the exit back where it was.
  void _followRuntime() {
    final base = _runtimeEditBase ??= (
      exit: _exitInput(),
      exitDate: _exitDate,
      exitTime: _exitTime,
      seeded: _seededTimes,
    );
    final minutes = _savedNumber(_runtimeController, integer: true)?.toInt();
    if (minutes == null || minutes <= 0) {
      _updateTimes(() {
        _seededTimes = base.seeded;
        _exitDate = base.exitDate;
        _exitTime = base.exitTime;
      });
      return;
    }
    final form = _timeInputs();
    _showLinkedTimes(
      setDiveRuntime(
        DiveTimeInputs(
          entry: form.entry,
          exit: base.exit,
          bottomTimeMinutes: form.bottomTimeMinutes,
          runtimeMinutes: form.runtimeMinutes,
        ),
        minutes,
        seeded: base.seeded,
      ),
    );
  }

  /// Shows the exit a linked edit moved; the times re-seed the form, so the
  /// save writes them exactly.
  void _showLinkedTimes(SeededDiveTimes linked) {
    final exit = linked.shown.exit;
    _updateTimes(() {
      _seededTimes = linked;
      if (exit != null) {
        _exitDate = exit;
        _exitTime = TimeOfDay.fromDateTime(exit);
      }
    });
  }

  /// Shows exit minus entry as the runtime once the diver moves the exit
  /// (issue #241), blank for an exit before the entry, as the save reads it.
  void _showRuntimeOfExit() {
    final runtime = resolveDiveTimes(
      _timeInputs(),
      seeded: _seededTimes,
    ).runtime;
    _updateTimes(() {
      _runtimeController.text = runtime == null
          ? ''
          : _seedInt(runtime.inMinutes);
    });
  }
}
