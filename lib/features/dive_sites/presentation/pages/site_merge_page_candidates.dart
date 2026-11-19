part of 'site_merge_page.dart';

/// The sites to merge, in the order asked, and their expected species'
/// union.
class _MergeLoadData {
  final List<DiveSite> sites;
  final List<Species> expectedSpecies;

  const _MergeLoadData({required this.sites, required this.expectedSpecies});
}

/// One distinct value a field can take, and the first site that has it.
class _MergeFieldCandidate<T> {
  final String siteId;
  final String siteName;
  final T value;

  const _MergeFieldCandidate({
    required this.siteId,
    required this.siteName,
    required this.value,
  });
}

/// A site's coordinates, as the two fields show them.
class _CoordinateCandidate {
  final String latitudeText;
  final String longitudeText;

  const _CoordinateCandidate({
    required this.latitudeText,
    required this.longitudeText,
  });
}

/// The merge's candidates: each field's distinct values across the sites,
/// the one chosen, and the cycle button that moves to the next.
mixin _SiteMergeCandidates on _SiteMergeFields {
  final Map<String, List<_MergeFieldCandidate<String>>> _mergeTextCandidates =
      {};
  final Map<String, int> _mergeFieldIndices = {};

  /// Each merged site's stored country and code, by site id, so choosing a
  /// site's country brings that site's code with it.
  final Map<String, KnownCountryCode> _mergeCountryCodes = {};
  List<_MergeFieldCandidate<SiteDifficulty?>> _difficultyCandidates = [];
  List<_MergeFieldCandidate<WaterType?>> _waterTypeCandidates = [];
  List<_MergeFieldCandidate<List<EntryMethod>>> _entryMethodCandidates = [];
  List<_MergeFieldCandidate<List<EntryMethod>>> _exitMethodCandidates = [];
  List<_MergeFieldCandidate<double>> _ratingCandidates = [];
  List<_MergeFieldCandidate<_CoordinateCandidate>> _coordinateCandidates = [];

  Future<_MergeLoadData> _loadMergeData() async {
    final siteRepository = ref.read(siteRepositoryProvider);
    final speciesRepository = ref.read(speciesRepositoryProvider);
    final requestedIds = widget.siteIds;
    final sites = await siteRepository.getSitesByIds(requestedIds);
    final sitesById = {for (final site in sites) site.id: site};
    final orderedSites = requestedIds
        .map((id) => sitesById[id])
        .whereType<DiveSite>()
        .toList(growable: false);

    final allSpecies = await speciesRepository.getAllSpecies();
    final speciesById = {for (final species in allSpecies) species.id: species};
    final mergedSpecies = <Species>[];
    final seenSpeciesIds = <String>{};
    for (final site in orderedSites) {
      final entries = await speciesRepository.getExpectedSpeciesForSite(
        site.id,
      );
      for (final entry in entries) {
        if (!seenSpeciesIds.add(entry.speciesId)) continue;
        final species = speciesById[entry.speciesId];
        if (species != null) mergedSpecies.add(species);
      }
    }
    return _MergeLoadData(sites: orderedSites, expectedSpecies: mergedSpecies);
  }

  void _initializeFromMerge(_MergeLoadData data, UnitFormatter units) {
    if (_isInitialized) return;
    _isInitialized = true;
    _survivor = data.sites.first;
    _mergedIds = [for (final site in data.sites) site.id];
    _expectedSpecies = data.expectedSpecies;
    _isApplyingInitialValues = true;

    void text(
      String key,
      TextEditingController controller,
      String Function(DiveSite site) getValue,
    ) => _initializeMergeTextField(
      key: key,
      controller: controller,
      sites: data.sites,
      getValue: getValue,
    );

    text('name', _nameController, (site) => site.name);
    text('description', _descriptionController, (site) => site.description);
    text('country', _countryController, (site) => site.country ?? '');
    _mergeCountryCodes
      ..clear()
      ..addAll({
        for (final site in data.sites)
          site.id: (country: site.country, code: site.countryCode),
      });
    _adoptMergeCountryCode(_mergeFieldIndices['country'] ?? 0);
    text('region', _regionController, (site) => site.region ?? '');
    text('city', _cityController, (site) => site.city ?? '');
    text('island', _islandController, (site) => site.island ?? '');
    text('bodyOfWater', _bodyOfWaterController, (s) => s.bodyOfWater ?? '');
    text(
      'minDepth',
      _minDepthController,
      (site) => site.minDepth != null
          ? _depthForInput(units.convertDepth(site.minDepth!))
          : '',
    );
    text(
      'maxDepth',
      _maxDepthController,
      (site) => site.maxDepth != null
          ? _depthForInput(units.convertDepth(site.maxDepth!))
          : '',
    );
    text('notes', _notesController, (site) => site.notes);
    text('hazards', _hazardsController, (site) => site.hazards ?? '');
    text('accessNotes', _accessNotesController, (s) => s.accessNotes ?? '');
    text(
      'mooringNumber',
      _mooringNumberController,
      (site) => site.mooringNumber ?? '',
    );
    text('parkingInfo', _parkingInfoController, (s) => s.parkingInfo ?? '');
    text(
      'altitude',
      _altitudeController,
      (site) => site.altitude != null
          ? _altitudeForInput(units.convertAltitude(site.altitude!))
          : '',
    );

    _difficultyCandidates = _buildDistinctCandidates<SiteDifficulty?>(
      data.sites,
      (site) => site.difficulty,
      equals: (a, b) => a == b,
    );
    _difficulty = _pick('difficulty', _difficultyCandidates, (v) => v != null);

    _waterTypeCandidates = _buildDistinctCandidates<WaterType?>(
      data.sites,
      (site) => site.waterType,
      equals: (a, b) => a == b,
    );
    _waterType = _pick('waterType', _waterTypeCandidates, (v) => v != null);

    // Each site's whole list is one candidate (issue #2054); lists are
    // compared by content, not identity.
    _entryMethodCandidates = _buildDistinctCandidates<List<EntryMethod>>(
      data.sites,
      (site) => site.entryMethods,
      equals: listEquals,
    );
    _entryMethods = _pick(
      'entryMethod',
      _entryMethodCandidates,
      (v) => v.isNotEmpty,
    );

    _exitMethodCandidates = _buildDistinctCandidates<List<EntryMethod>>(
      data.sites,
      (site) => site.exitMethods,
      equals: listEquals,
    );
    _exitMethods = _pick(
      'exitMethod',
      _exitMethodCandidates,
      (v) => v.isNotEmpty,
    );

    _ratingCandidates = _buildDistinctCandidates<double>(
      data.sites,
      (site) => site.rating ?? 0,
      equals: (a, b) => a == b,
    );
    _rating = _pick('rating', _ratingCandidates, (v) => v > 0);

    _coordinateCandidates = _buildDistinctCandidates<_CoordinateCandidate>(
      data.sites,
      (site) => _CoordinateCandidate(
        latitudeText: site.location?.latitude.toString() ?? '',
        longitudeText: site.location?.longitude.toString() ?? '',
      ),
      equals: (a, b) =>
          a.latitudeText == b.latitudeText &&
          a.longitudeText == b.longitudeText,
    );
    _applyCoordinateCandidate(
      _pick(
        'coordinates',
        _coordinateCandidates,
        (v) =>
            v.latitudeText.trim().isNotEmpty &&
            v.longitudeText.trim().isNotEmpty,
      ),
    );
    _isApplyingInitialValues = false;
  }

  /// Chooses [candidates]' first meaningful value for [key], and returns it.
  T _pick<T>(
    String key,
    List<_MergeFieldCandidate<T>> candidates,
    bool Function(T value) isMeaningful,
  ) {
    final index = _firstMeaningfulIndex(candidates, isMeaningful);
    _mergeFieldIndices[key] = index;
    return candidates[index].value;
  }

  void _initializeMergeTextField({
    required String key,
    required TextEditingController controller,
    required List<DiveSite> sites,
    required String Function(DiveSite site) getValue,
  }) {
    final candidates = _buildDistinctCandidates<String>(
      sites,
      getValue,
      equals: (a, b) => a == b,
    );
    _mergeTextCandidates[key] = candidates;
    controller.text = _pick(key, candidates, (v) => v.trim().isNotEmpty);
  }

  List<_MergeFieldCandidate<T>> _buildDistinctCandidates<T>(
    List<DiveSite> sites,
    T Function(DiveSite site) getValue, {
    required bool Function(T a, T b) equals,
  }) {
    final candidates = <_MergeFieldCandidate<T>>[];
    for (final site in sites) {
      final value = getValue(site);
      if (candidates.any((candidate) => equals(candidate.value, value))) {
        continue;
      }
      candidates.add(
        _MergeFieldCandidate(
          siteId: site.id,
          siteName: site.name,
          value: value,
        ),
      );
    }
    return candidates;
  }

  int _firstMeaningfulIndex<T>(
    List<_MergeFieldCandidate<T>> candidates,
    bool Function(T value) isMeaningful,
  ) {
    final index = candidates.indexWhere(
      (candidate) => isMeaningful(candidate.value),
    );
    return index >= 0 ? index : 0;
  }

  /// Takes the stored code of the site whose country candidate [index]
  /// shows, so save keeps it while the text is left as chosen.
  void _adoptMergeCountryCode(int index) {
    final candidates = _mergeTextCandidates['country'];
    if (candidates == null || index < 0 || index >= candidates.length) return;
    final known = _mergeCountryCodes[candidates[index].siteId];
    if (known == null) return;
    // A candidate stands for every merged site with its text, so a code
    // stored on any of them comes along, not only the first site's.
    _knownCountryCode = known.code != null
        ? known
        : _mergeCountryCodes.values.firstWhere(
            (other) => other.code != null && other.country == known.country,
            orElse: () => known,
          );
  }

  /// The text field each text candidate key fills. Difficulty, water type,
  /// the entry and exit methods, rating and coordinates cycle through their
  /// own candidate lists instead.
  TextEditingController? _textControllerFor(String key) => switch (key) {
    'name' => _nameController,
    'description' => _descriptionController,
    'country' => _countryController,
    'region' => _regionController,
    'city' => _cityController,
    'island' => _islandController,
    'bodyOfWater' => _bodyOfWaterController,
    'minDepth' => _minDepthController,
    'maxDepth' => _maxDepthController,
    'notes' => _notesController,
    'hazards' => _hazardsController,
    'accessNotes' => _accessNotesController,
    'mooringNumber' => _mooringNumberController,
    'parkingInfo' => _parkingInfoController,
    'altitude' => _altitudeController,
    _ => null,
  };

  void _cycleTextField(String key) {
    final candidates = _mergeTextCandidates[key];
    final controller = _textControllerFor(key);
    if (candidates == null || candidates.length < 2 || controller == null) {
      return;
    }
    final index = ((_mergeFieldIndices[key] ?? 0) + 1) % candidates.length;
    if (key == 'country') _adoptMergeCountryCode(index);
    setState(() {
      _mergeFieldIndices[key] = index;
      controller.text = candidates[index].value;
      _hasChanges = true;
    });
  }

  /// Moves [key] to its next candidate in [candidates] and hands the value
  /// to [apply].
  void _cycle<T>(
    String key,
    List<_MergeFieldCandidate<T>> candidates,
    void Function(T value) apply,
  ) {
    if (candidates.length < 2) return;
    setState(() {
      final index = ((_mergeFieldIndices[key] ?? 0) + 1) % candidates.length;
      _mergeFieldIndices[key] = index;
      apply(candidates[index].value);
      _hasChanges = true;
    });
  }

  void _applyCoordinateCandidate(_CoordinateCandidate candidate) {
    _latitudeController.text = candidate.latitudeText;
    _longitudeController.text = candidate.longitudeText;
  }

  /// The source label and cycle button for a field with more than one
  /// distinct value; null for a field the sites agree on.
  MergeFieldExtras? _extras<T>(
    String key,
    List<_MergeFieldCandidate<T>>? candidates,
    VoidCallback onCycle,
  ) {
    if (candidates == null || candidates.length < 2) return null;
    final index = _mergeFieldIndices[key] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        candidates[index].siteName,
        index + 1,
        candidates.length,
      ),
      onCycle: onCycle,
    );
  }

  MergeFieldExtras? _mergeExtras(String key) =>
      _extras(key, _mergeTextCandidates[key], () => _cycleTextField(key));

  MergeFieldExtras? _coordinateExtras() => _extras(
    'coordinates',
    _coordinateCandidates,
    () =>
        _cycle('coordinates', _coordinateCandidates, _applyCoordinateCandidate),
  );

  MergeFieldExtras? _difficultyExtras() => _extras(
    'difficulty',
    _difficultyCandidates,
    () => _cycle('difficulty', _difficultyCandidates, (v) => _difficulty = v),
  );

  MergeFieldExtras? _waterTypeExtras() => _extras(
    'waterType',
    _waterTypeCandidates,
    () => _cycle('waterType', _waterTypeCandidates, (v) => _waterType = v),
  );

  MergeFieldExtras? _entryMethodExtras() => _extras(
    'entryMethod',
    _entryMethodCandidates,
    () => _cycle('entryMethod', _entryMethodCandidates, (v) {
      _entryMethods = v;
    }),
  );

  MergeFieldExtras? _exitMethodExtras() => _extras(
    'exitMethod',
    _exitMethodCandidates,
    () => _cycle('exitMethod', _exitMethodCandidates, (v) => _exitMethods = v),
  );

  MergeFieldExtras? _ratingExtras() => _extras(
    'rating',
    _ratingCandidates,
    () => _cycle('rating', _ratingCandidates, (v) => _rating = v),
  );
}
