part of 'dive_computer_adapter.dart';

/// The name of the profile [diverId], or null when there is no such profile.
typedef DiverNameLookup = Future<String?> Function(String diverId);

/// Which profile a download goes to (issue #2050), kept beside the adapter so
/// the adapter file does not grow further.
///
/// A computer is looked up in the active profile first and then across every
/// profile, so a computer that belongs to another profile is recognised
/// instead of registered a second time. When its owner is another existing
/// profile, the bundle carries an [ImportTargetChoice] and the import goes to
/// the chosen profile: the owner by default, or the active profile when the
/// diver turned "Add downloads to the computer's owner" off.
extension DiveComputerAdapterTarget on DiveComputerAdapter {
  /// The profile that started the download.
  String get activeDiverId => _activeDiverId;

  /// The profile this download's dives are written to.
  String get targetDiverId => _chosenDiverId ?? _activeDiverId;

  /// Whether the computer known so far names an owner other than the active
  /// profile, so [resolveTarget] has a profile to look up. When false the
  /// download goes to the active profile without waiting on a lookup.
  bool get mayBelongToAnotherProfile {
    final owner = computer?.diverId?.trim() ?? '';
    return owner.isNotEmpty &&
        _activeDiverId.isNotEmpty &&
        owner != _activeDiverId;
  }

  /// Works out the computer's owner from the computer known so far, and the
  /// starting choice when the diver has not made one.
  ///
  /// Called before the download for the first-sync cutoff, and again by
  /// [buildBundle]: a computer that turned out to be another unit has another
  /// owner, and a choice made for the old one is dropped.
  Future<void> resolveTarget() async {
    final candidate = computer?.diverId?.trim() ?? '';
    // Only a confirmed missing profile falls back to the active one; a
    // lookup that failed keeps the owner rather than filing the download in
    // the wrong log.
    final owner =
        mayBelongToAnotherProfile && !(await _lookUpDiver(candidate)).missing
        ? candidate
        : null;
    if (owner != _ownerDiverId) _chosenDiverId = null;
    _ownerDiverId = owner;
    if (owner == null) return;
    _chosenDiverId ??= await _followsOwner() ? owner : _activeDiverId;
  }
}

extension _DiveComputerAdapterTargetSupport on DiveComputerAdapter {
  /// Runs [find] for the active profile and, when that misses, across every
  /// profile. The active profile's record wins, so a computer the old
  /// behaviour registered under two profiles keeps using this profile's copy.
  /// An unscoped library (no active id) is searched once, as before.
  Future<T?> _findAcrossProfiles<T>(
    Future<T?> Function(String? diverId) find,
  ) async {
    final own = await find(_activeDiverId);
    if (own != null || _activeDiverId.isEmpty) return own;
    return find(null);
  }

  /// The diver's "Add downloads to the computer's owner", waiting for the
  /// settings to load so a saved "off" is not read as the default.
  Future<bool> _followsOwner() async {
    final given = _followComputerOwner;
    if (given != null) return given();
    final ref = _ref;
    if (ref == null) return true;
    try {
      await ref.read(settingsProvider.notifier).settingsLoaded;
    } catch (_) {
      // Logged where the load started; the defaults are the fallback.
    }
    return ref.read(settingsProvider).downloadsFollowComputerOwner;
  }

  /// The bundle's choice, or null when the download simply goes to the
  /// active profile.
  ImportTargetChoice? get _targetChoice {
    final owner = _ownerDiverId;
    if (owner == null) return null;
    return ImportTargetChoice(
      ownerDiverId: owner,
      chosenDiverId: targetDiverId,
    );
  }

  /// The import's per-profile outcome when its dives went to a profile other
  /// than the active one, so tagging, the logbook rules and the summary's
  /// "By profile" section follow that profile. Empty otherwise, as for any
  /// import into the active profile.
  Future<List<DiverImportOutcome>> _diverOutcomes(
    List<String> importedDiveIds,
  ) async {
    final target = targetDiverId;
    if (_activeDiverId.isEmpty || target == _activeDiverId) return const [];
    return [
      DiverImportOutcome(
        diverId: target,
        name: await _lookUpDiverName(target) ?? '',
        isNew: false,
        isActive: false,
        diveIds: importedDiveIds,
      ),
    ];
  }

  /// The name of [diverId], or null when it is missing or unknown.
  Future<String?> _lookUpDiverName(String diverId) async =>
      (await _lookUpDiver(diverId)).name;

  /// Looks up [diverId]: its name, and whether the profile is confirmed
  /// missing.
  ///
  /// A name found is remembered in [_diverNames]. A lookup that fails is not
  /// a missing profile: it reports the name remembered from earlier, if any,
  /// and `missing: false`, so a passing database error never reads as the
  /// profile having been deleted and silently sends the download elsewhere.
  Future<({String? name, bool missing})> _lookUpDiver(String diverId) async {
    try {
      final lookup = _diverName;
      final ref = _ref;
      final String? name;
      if (lookup != null) {
        name = await lookup(diverId);
      } else if (ref != null) {
        final diver = await ref
            .read(diverRepositoryProvider)
            .getDiverById(diverId);
        name = diver?.name;
      } else {
        name = null;
      }
      if (name == null) {
        _diverNames.remove(diverId);
      } else {
        _diverNames[diverId] = name;
      }
      return (name: name, missing: name == null);
    } catch (e, stackTrace) {
      DiveComputerAdapter._log.error(
        'Could not look up profile $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      return (name: _diverNames[diverId], missing: false);
    }
  }
}
