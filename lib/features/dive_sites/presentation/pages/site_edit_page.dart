import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/utils/suggestion_child_fields.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/hidden_built_ins_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entry_method_list.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_merge.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/location_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_delete_usage.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/type_tags_section.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picker_dialog.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/shared/widgets/forms/responsive_form_columns.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_row.dart';
import 'package:submersion/core/services/logger_service.dart';

const _log = LoggerService('siteEditPage');

/// Seeds a depth field at the single decimal place it has always shown, and an
/// altitude field at the whole units it has always shown, both in the active
/// locale's decimal separator so the save path can read them back (#1091).
String _depthForInput(double value) => formatRoundedForInput(value, 1);

String _altitudeForInput(double value) => formatRoundedForInput(value, 0);

class SiteEditPage extends ConsumerStatefulWidget {
  final String? siteId;
  final List<String>? mergeSiteIds;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  /// Called in embedded mode once the site is deleted, so the host can leave
  /// the pane. The delete action is offered in embedded mode only when this
  /// is set; a standalone page returns to the site list itself.
  final VoidCallback? onDeleted;
  final GeoPoint? initialLocation;

  /// Starts a new site's name field with this text, such as what the diver
  /// searched the site picker for (#1501).
  final String? initialName;

  /// Starts a new site from every field, type, tag and expected species of
  /// this one, named as its copy; Save also copies its map features. Nothing
  /// is written until then (issue #3575).
  final String? duplicateOfId;

  /// A reader's view of a shared site library site (issue #2567): Save becomes
  /// Send and writes a suggestion instead of the site.
  final bool suggest;

  const SiteEditPage({
    super.key,
    this.siteId,
    this.mergeSiteIds,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.onDeleted,
    this.initialLocation,
    this.initialName,
    this.duplicateOfId,
    this.suggest = false,
  }) : assert(
         siteId == null || mergeSiteIds == null,
         'siteId and mergeSiteIds are mutually exclusive',
       ),
       assert(
         initialLocation == null || (siteId == null && mergeSiteIds == null),
         'initialLocation is only valid when creating a new site',
       ),
       assert(
         initialName == null || (siteId == null && mergeSiteIds == null),
         'initialName is only valid when creating a new site',
       ),
       assert(
         duplicateOfId == null || (siteId == null && mergeSiteIds == null),
         'duplicateOfId is only valid when creating a new site',
       ),
       assert(
         duplicateOfId == null ||
             (initialLocation == null && initialName == null),
         'a duplicate takes its name and location from the original',
       );

  /// The new-site form for the `/sites/new` route, seeded from its `extra`
  /// as [NewSiteSeed.fromRouteExtra] reads it, or duplicating the site its
  /// `duplicateOf` query names.
  factory SiteEditPage.fromNewSiteExtra(
    Object? extra, {
    String? duplicateOfId,
  }) {
    final seed = NewSiteSeed.fromRouteExtra(extra);
    return SiteEditPage(
      initialLocation: seed.location,
      initialName: seed.name,
      duplicateOfId: duplicateOfId,
    );
  }

  bool get isEditing => siteId != null;
  bool get isDuplicating => !isEditing && duplicateOfId != null;
  bool get isMerging => mergeSiteIds != null && mergeSiteIds!.length > 1;

  @override
  ConsumerState<SiteEditPage> createState() => _SiteEditPageState();
}

class _SiteEditPageState extends ConsumerState<SiteEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _cityController = TextEditingController();
  final _islandController = TextEditingController();
  final _bodyOfWaterController = TextEditingController();
  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _notesController = TextEditingController();
  final _hazardsController = TextEditingController();
  final _accessNotesController = TextEditingController();
  final _mooringNumberController = TextEditingController();
  final _parkingInfoController = TextEditingController();
  final _altitudeController = TextEditingController();

  double _rating = 0;
  SiteDifficulty? _difficulty;
  WaterType? _waterType;
  List<EntryMethod> _entryMethods = const [];
  List<EntryMethod> _exitMethods = const [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;
  // Who the site is shared with (issue #2151): the pending choice, and what
  // is stored, so a save writes only a change.
  ItemSharing _sharing = ItemSharing.none;
  ItemSharing _originalSharing = ItemSharing.none;

  /// The stored sharing could not be read: the field stays locked, so a
  /// save never overwrites sharing the page never saw.
  bool _sharingUnread = false;

  /// An existing site's share rows have been read; until then the field
  /// stays locked, so a pick is never confirmed against a stale original.
  bool _sharingLoaded = false;

  /// Share rows stored beside the everyone flag (a sync race): an owner's
  /// save clears them, or a later unshare would bring them back.
  bool _staleShareRows = false;
  final _suggestionNote = TextEditingController();
  bool _isApplyingInitialValues = false;
  Timer? _altitudeLookupDebounce;
  DiveSite? _originalSite;

  /// The duplicate's type, tag and species loads. A new site always writes
  /// its picks, so Save waits for these rather than saving empty ones.
  Future<void>? _duplicateLoads;
  List<Species> _expectedSpecies = [];
  Set<String> _originalExpectedSpeciesIds = {};
  // Site types and tags (issue #1765). A Set keeps insertion order, so types
  // save in the order the diver picked them.
  Set<String> _selectedTypeIds = {};
  List<Tag> _selectedTags = [];
  Set<String> _originalTypeIds = {};
  Set<String> _originalTagIds = {};
  // Set once the diver edits the section, so a classification load that
  // finishes afterwards cannot overwrite the pick.
  bool _typesTouched = false;
  bool _tagsTouched = false;
  late final Future<_MergeLoadData>? _mergeLoadFuture;
  final Map<String, List<_MergeFieldCandidate<String>>> _mergeTextCandidates =
      {};
  final Map<String, int> _mergeFieldIndices = {};
  List<_MergeFieldCandidate<SiteDifficulty?>> _difficultyCandidates = [];
  List<_MergeFieldCandidate<WaterType?>> _waterTypeCandidates = [];
  List<_MergeFieldCandidate<List<EntryMethod>>> _entryMethodCandidates = [];
  List<_MergeFieldCandidate<List<EntryMethod>>> _exitMethodCandidates = [];
  List<_MergeFieldCandidate<double>> _ratingCandidates = [];
  List<_MergeFieldCandidate<_CoordinateCandidate>> _coordinateCandidates = [];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _countryController.addListener(_onFieldChanged);
    _regionController.addListener(_onFieldChanged);
    _cityController.addListener(_onFieldChanged);
    _islandController.addListener(_onFieldChanged);
    _bodyOfWaterController.addListener(_onFieldChanged);
    _minDepthController.addListener(_onFieldChanged);
    _maxDepthController.addListener(_onFieldChanged);
    _latitudeController.addListener(_onFieldChanged);
    _longitudeController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
    _hazardsController.addListener(_onFieldChanged);
    _accessNotesController.addListener(_onFieldChanged);
    _mooringNumberController.addListener(_onFieldChanged);
    _parkingInfoController.addListener(_onFieldChanged);
    _altitudeController.addListener(_onFieldChanged);
    _latitudeController.addListener(_scheduleAltitudeLookup);
    _longitudeController.addListener(_scheduleAltitudeLookup);
    _mergeLoadFuture = widget.isMerging ? _loadMergeData() : null;
    // A duplicate decides its own sharing instead (issue #3575).
    if (!widget.isEditing && !widget.isMerging && !widget.isDuplicating) {
      _applyShareByDefault();
    }
  }

  void _applyShareByDefault() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shareByDefault = await ref.read(shareByDefaultProvider.future);
      if (!mounted) return;
      setState(
        () => _sharing = shareByDefault ? ItemSharing.all : ItemSharing.none,
      );
    });
  }

  void _onFieldChanged() {
    if (_isApplyingInitialValues) return;
    if (!_hasChanges && _isInitialized) {
      setState(() => _hasChanges = true);
    }
  }

  /// Debounce typed coordinate edits; the locate action and map picker set both
  /// controller texts at once and land here through the same listeners.
  void _scheduleAltitudeLookup() {
    _altitudeLookupDebounce?.cancel();
    _altitudeLookupDebounce = Timer(const Duration(seconds: 1), () {
      if (mounted) _maybeFetchAltitude();
    });
  }

  /// Fill an empty altitude field from the site's coordinates so altitude
  /// diving is flagged without manual entry. Never overwrites a value.
  Future<void> _maybeFetchAltitude() async {
    if (_altitudeController.text.isNotEmpty) return;
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lng == null) return;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;

    final meters = await ref
        .read(elevationServiceProvider)
        .fetchElevation(latitude: lat, longitude: lng);
    if (!mounted || meters == null) return;
    if (_altitudeController.text.isNotEmpty) return;

    final units = UnitFormatter(ref.read(settingsProvider));
    setState(() {
      // A programmatic fill must not dirty the form on its own: opening a site
      // that predates this feature would otherwise prompt to discard changes.
      final wasApplying = _isApplyingInitialValues;
      _isApplyingInitialValues = true;
      _altitudeController.text = _altitudeForInput(
        units.convertAltitude(meters),
      );
      _isApplyingInitialValues = wasApplying;
    });
  }

  /// Seed a brand-new site form's name from [SiteEditPage.initialName], as a
  /// non-dirtying initial value: cancelling an untouched form needs no
  /// discard prompt.
  void _seedInitialName() {
    final name = widget.initialName;
    if (name == null || name.isEmpty) return;

    _isApplyingInitialValues = true;
    _nameController.text = name;
    _isApplyingInitialValues = false;
  }

  /// Seed a brand-new site form from [SiteEditPage.initialLocation]: fill the
  /// coordinate fields immediately (as non-dirtying initial values), then
  /// best-effort reverse-geocode country/region into the empty fields.
  void _seedInitialLocation() {
    final loc = widget.initialLocation;
    if (loc == null) return;

    _isApplyingInitialValues = true;
    _latitudeController.text = loc.latitude.toStringAsFixed(6);
    _longitudeController.text = loc.longitude.toStringAsFixed(6);
    _isApplyingInitialValues = false;

    WidgetsBinding.instance.addPostFrameCallback((_) => _geocodeSeed(loc));
  }

  Future<void> _geocodeSeed(GeoPoint loc) async {
    if (!mounted) return;
    final result = await ref
        .read(locationServiceProvider)
        .reverseGeocode(
          loc.latitude,
          loc.longitude,
          languageCode: ref.read(placeNameLanguageProvider),
        );
    if (!mounted) return;
    setState(() {
      _isApplyingInitialValues = true;
      _applyPlaceLookup(result, overwrite: false);
      _isApplyingInitialValues = false;
    });
  }

  /// Writes [lookup] into the country, region, city and body of water
  /// fields. With [overwrite] false only empty fields change; with it true a
  /// found value replaces a differing one. The rule lives in
  /// [mergeLocationDetails]. Returns whether any field changed. Callers
  /// decide whether that dirties the form.
  bool _applyPlaceLookup(PlaceLookup lookup, {required bool overwrite}) {
    final merged = mergeLocationDetails(
      current: SiteLocationDetails(
        country: _countryController.text,
        region: _regionController.text,
        city: _cityController.text,
        bodyOfWater: _bodyOfWaterController.text,
      ),
      found: lookup,
      overwrite: overwrite,
    );
    if (merged == null) return false;

    var changed = false;
    void set(TextEditingController controller, String? value) {
      if (value == null || controller.text == value) return;
      controller.text = value;
      changed = true;
    }

    set(_countryController, merged.country);
    set(_regionController, merged.region);
    set(_cityController, merged.city);
    set(_bodyOfWaterController, merged.bodyOfWater);
    return changed;
  }

  @override
  void dispose() {
    _suggestionNote.dispose();
    _altitudeLookupDebounce?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _islandController.dispose();
    _bodyOfWaterController.dispose();
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _notesController.dispose();
    _hazardsController.dispose();
    _accessNotesController.dispose();
    _mooringNumberController.dispose();
    _parkingInfoController.dispose();
    _altitudeController.dispose();
    super.dispose();
  }

  void _initializeFromSite(DiveSite site, UnitFormatter units) {
    if (_isInitialized) return;
    _isInitialized = true;
    _originalSite = site;
    _fillForm(site, units);

    // Load expected species
    _loadSharing(site);
    _loadExpectedSpecies(site.id);
    _loadClassification(site.id);
  }

  /// Fills the form from [source] as a new site named as its copy (issue
  /// #3575), with its types, tags and expected species picked. There is no
  /// [_originalSite]: the save creates a site of the active diver's, and a
  /// shared library site's copy is a personal one, shared as a new site is.
  /// The copy keeps the sharing of a site that is the diver's own, everyone
  /// and named profiles alike (issue #2151); another profile's site is its
  /// owner's audience, so that copy is shared as a new site is too.
  void _initializeFromDuplicate(DiveSite source, UnitFormatter units) {
    if (_isInitialized) return;
    _isInitialized = true;
    _fillForm(
      source.copyWith(
        name: context.l10n.diveSites_edit_duplicateName(source.name),
      ),
      units,
    );
    // Nothing is stored for the copy yet, so Save writes its sharing. A
    // library site's copy is shared as a new site is.
    _originalSharing = ItemSharing.none;
    if (source.isLibrarySite) {
      _sharing = ItemSharing.none;
      _applyShareByDefault();
    }
    // Handled here, not only at Save: the diver may never press it. A load
    // that fails leaves its picks as they are for the diver to adjust.
    _duplicateLoads =
        Future.wait([
          _loadExpectedSpecies(source.id),
          _loadClassification(source.id, ownOnly: true),
          if (!source.isLibrarySite) _loadDuplicateSharing(source),
        ]).then<void>(
          (_) {},
          onError: (Object e, StackTrace stackTrace) => _log.error(
            'Could not load what site ${source.id} carries to its copy',
            error: e,
            stackTrace: stackTrace,
          ),
        );
  }

  /// Settles the copy's sharing once the active profile is known: the
  /// diver's own site adds the profiles it is shared with by name, and
  /// another profile's site is shared as a new site is. A choice the diver
  /// made meanwhile is kept.
  Future<void> _loadDuplicateSharing(DiveSite source) async {
    final provisional = ItemSharing(everyone: source.isShared);
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final ItemSharing settled;
    if (isOwnOrUnowned(ownerId: source.diverId, activeDiverId: diverId)) {
      final stored = await ref
          .read(itemSharesRepositoryProvider)
          .storedProfileIds(SharedItemKind.site, source.id);
      settled = ItemSharing(everyone: source.isShared, profileIds: stored);
    } else {
      settled = await ref.read(shareByDefaultProvider.future)
          ? ItemSharing.all
          : ItemSharing.none;
    }
    if (!mounted || _sharing != provisional) return;
    setState(() => _sharing = settled);
  }

  /// Fills every form field from [site], as initial values that leave the
  /// form clean.
  void _fillForm(DiveSite site, UnitFormatter units) {
    _isApplyingInitialValues = true;

    _nameController.text = site.name;
    _descriptionController.text = site.description;
    _countryController.text = site.country ?? '';
    _regionController.text = site.region ?? '';
    _cityController.text = site.city ?? '';
    _islandController.text = site.island ?? '';
    _bodyOfWaterController.text = site.bodyOfWater ?? '';
    _minDepthController.text = site.minDepth != null
        ? _depthForInput(units.convertDepth(site.minDepth!))
        : '';
    _maxDepthController.text = site.maxDepth != null
        ? _depthForInput(units.convertDepth(site.maxDepth!))
        : '';
    _latitudeController.text = site.location?.latitude.toString() ?? '';
    _longitudeController.text = site.location?.longitude.toString() ?? '';
    _notesController.text = site.notes;
    _hazardsController.text = site.hazards ?? '';
    _accessNotesController.text = site.accessNotes ?? '';
    _mooringNumberController.text = site.mooringNumber ?? '';
    _parkingInfoController.text = site.parkingInfo ?? '';
    _rating = site.rating ?? 0;
    _difficulty = site.difficulty;
    _waterType = site.waterType;
    _entryMethods = site.entryMethods;
    _exitMethods = site.exitMethods;
    _sharing = _originalSharing = ItemSharing(everyone: site.isShared);
    _altitudeController.text = site.altitude != null
        ? _altitudeForInput(units.convertAltitude(site.altitude!))
        : '';
    _isApplyingInitialValues = false;
  }

  /// Reads the profiles the site is shared with by name (issue #2151); the
  /// everyone flag came with the site. A failed read locks the field.
  Future<void> _loadSharing(DiveSite site) async {
    try {
      final stored = await ref
          .read(itemSharesRepositoryProvider)
          .storedProfileIds(SharedItemKind.site, site.id);
      if (!mounted) return;
      setState(() {
        final loaded = ItemSharing(everyone: site.isShared, profileIds: stored);
        _staleShareRows = site.isShared && stored.isNotEmpty;
        _sharing = loaded;
        _originalSharing = loaded;
        _sharingLoaded = true;
      });
    } catch (e, stackTrace) {
      _log.warning(
        'Could not read who site ${site.id} is shared with',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _sharingUnread = true);
    }
  }

  /// Loads the site's types and tags into the Type & Tags section.
  ///
  /// The stored values always become the baseline a save compares against,
  /// but they fill the section only if the diver has not already edited it:
  /// a pick made before the load finished is what the diver saw and chose.
  ///
  /// With [ownOnly] (a duplicate) only built-ins and the active diver's own
  /// types and tags are kept: another profile's shared site must not bring
  /// its owner's vocabulary onto the copy, as an equipment clone (#2046).
  Future<void> _loadClassification(
    String siteId, {
    bool ownOnly = false,
  }) async {
    var types = await ref.read(siteTypesForSiteProvider(siteId).future);
    var tags = await ref.read(tagsForSiteProvider(siteId).future);
    if (ownOnly) {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      bool mine(String? owner) =>
          isOwnOrUnowned(ownerId: owner, activeDiverId: diverId);
      types = [
        for (final t in types)
          if (mine(t.diverId)) t,
      ];
      tags = [
        for (final t in tags)
          if (mine(t.diverId)) t,
      ];
    }
    if (!mounted) return;
    setState(() {
      _originalTypeIds = {for (final t in types) t.id};
      _originalTagIds = {for (final t in tags) t.id};
      if (!_typesTouched) _selectedTypeIds = {..._originalTypeIds};
      if (!_tagsTouched) _selectedTags = tags;
    });
  }

  void _initializeFromMerge(_MergeLoadData data, UnitFormatter units) {
    if (_isInitialized) return;
    _isInitialized = true;
    _originalSite = data.sites.first;
    _sharing = _originalSharing = ItemSharing(
      everyone: data.sites.first.isShared,
    );
    _expectedSpecies = data.expectedSpecies;
    _originalExpectedSpeciesIds = _expectedSpecies.map((s) => s.id).toSet();
    _isApplyingInitialValues = true;

    _initializeMergeTextField(
      key: 'name',
      controller: _nameController,
      sites: data.sites,
      getValue: (site) => site.name,
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'description',
      controller: _descriptionController,
      sites: data.sites,
      getValue: (site) => site.description,
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'country',
      controller: _countryController,
      sites: data.sites,
      getValue: (site) => site.country ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'region',
      controller: _regionController,
      sites: data.sites,
      getValue: (site) => site.region ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'city',
      controller: _cityController,
      sites: data.sites,
      getValue: (site) => site.city ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'island',
      controller: _islandController,
      sites: data.sites,
      getValue: (site) => site.island ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'bodyOfWater',
      controller: _bodyOfWaterController,
      sites: data.sites,
      getValue: (site) => site.bodyOfWater ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'minDepth',
      controller: _minDepthController,
      sites: data.sites,
      getValue: (site) => site.minDepth != null
          ? _depthForInput(units.convertDepth(site.minDepth!))
          : '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'maxDepth',
      controller: _maxDepthController,
      sites: data.sites,
      getValue: (site) => site.maxDepth != null
          ? _depthForInput(units.convertDepth(site.maxDepth!))
          : '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'notes',
      controller: _notesController,
      sites: data.sites,
      getValue: (site) => site.notes,
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'hazards',
      controller: _hazardsController,
      sites: data.sites,
      getValue: (site) => site.hazards ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'accessNotes',
      controller: _accessNotesController,
      sites: data.sites,
      getValue: (site) => site.accessNotes ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'mooringNumber',
      controller: _mooringNumberController,
      sites: data.sites,
      getValue: (site) => site.mooringNumber ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'parkingInfo',
      controller: _parkingInfoController,
      sites: data.sites,
      getValue: (site) => site.parkingInfo ?? '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'altitude',
      controller: _altitudeController,
      sites: data.sites,
      getValue: (site) => site.altitude != null
          ? _altitudeForInput(units.convertAltitude(site.altitude!))
          : '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );

    _difficultyCandidates = _buildDistinctCandidates<SiteDifficulty?>(
      data.sites,
      (site) => site.difficulty,
      equals: (a, b) => a == b,
    );
    _mergeFieldIndices['difficulty'] = _firstMeaningfulIndex(
      _difficultyCandidates,
      (value) => value != null,
    );
    _difficulty =
        _difficultyCandidates[_mergeFieldIndices['difficulty'] ?? 0].value;

    _waterTypeCandidates = _buildDistinctCandidates<WaterType?>(
      data.sites,
      (site) => site.waterType,
      equals: (a, b) => a == b,
    );
    _mergeFieldIndices['waterType'] = _firstMeaningfulIndex(
      _waterTypeCandidates,
      (value) => value != null,
    );
    _waterType =
        _waterTypeCandidates[_mergeFieldIndices['waterType'] ?? 0].value;

    // Each site's whole list is one candidate (issue #2054); lists are
    // compared by content, not identity.
    _entryMethodCandidates = _buildDistinctCandidates<List<EntryMethod>>(
      data.sites,
      (site) => site.entryMethods,
      equals: listEquals,
    );
    _mergeFieldIndices['entryMethod'] = _firstMeaningfulIndex(
      _entryMethodCandidates,
      (value) => value.isNotEmpty,
    );
    _entryMethods =
        _entryMethodCandidates[_mergeFieldIndices['entryMethod'] ?? 0].value;

    _exitMethodCandidates = _buildDistinctCandidates<List<EntryMethod>>(
      data.sites,
      (site) => site.exitMethods,
      equals: listEquals,
    );
    _mergeFieldIndices['exitMethod'] = _firstMeaningfulIndex(
      _exitMethodCandidates,
      (value) => value.isNotEmpty,
    );
    _exitMethods =
        _exitMethodCandidates[_mergeFieldIndices['exitMethod'] ?? 0].value;

    _ratingCandidates = _buildDistinctCandidates<double>(
      data.sites,
      (site) => site.rating ?? 0,
      equals: (a, b) => a == b,
    );
    _mergeFieldIndices['rating'] = _firstMeaningfulIndex(
      _ratingCandidates,
      (value) => value > 0,
    );
    _rating = _ratingCandidates[_mergeFieldIndices['rating'] ?? 0].value;

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
    _mergeFieldIndices['coordinates'] = _firstMeaningfulIndex(
      _coordinateCandidates,
      (value) =>
          value.latitudeText.trim().isNotEmpty &&
          value.longitudeText.trim().isNotEmpty,
    );
    _applyCoordinateCandidate(
      _coordinateCandidates[_mergeFieldIndices['coordinates'] ?? 0].value,
    );
    _isApplyingInitialValues = false;
  }

  Future<void> _loadExpectedSpecies(String siteId) async {
    final repository = ref.read(speciesRepositoryProvider);
    final entries = await repository.getExpectedSpeciesForSite(siteId);

    // Convert entries to full Species objects for display
    final allSpecies = await repository.getAllSpecies();
    final speciesById = {for (final s in allSpecies) s.id: s};

    final species = entries
        .map((e) => speciesById[e.speciesId])
        .where((s) => s != null)
        .cast<Species>()
        .toList();

    if (mounted) {
      setState(() {
        _expectedSpecies = species;
        _originalExpectedSpeciesIds = species.map((s) => s.id).toSet();
      });
    }
  }

  void _handleCancel() {
    if (widget.embedded) {
      widget.onCancel?.call();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    if (widget.isMerging) {
      return FutureBuilder<_MergeLoadData>(
        future: _mergeLoadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            if (widget.embedded) {
              return const Center(child: CircularProgressIndicator());
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.diveSites_edit_appBar_mergeSites),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            if (widget.embedded) {
              return Center(
                child: Text(
                  context.l10n.diveSites_edit_merge_loadingErrorBody(
                    '${snapshot.error}',
                  ),
                ),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  context.l10n.diveSites_edit_merge_loadingErrorTitle,
                ),
              ),
              body: Center(
                child: Text(
                  context.l10n.diveSites_edit_merge_loadingErrorBody(
                    '${snapshot.error}',
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null || data.sites.length < 2) {
            if (widget.embedded) {
              return Center(
                child: Text(context.l10n.diveSites_edit_merge_notEnoughBody),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.diveSites_edit_merge_notEnoughTitle),
              ),
              body: Center(
                child: Text(context.l10n.diveSites_edit_merge_notEnoughBody),
              ),
            );
          }

          _initializeFromMerge(data, units);
          return _buildForm(context, units);
        },
      );
    }

    if (widget.isEditing || widget.isDuplicating) {
      final siteAsync = ref.watch(
        siteProvider(widget.siteId ?? widget.duplicateOfId!),
      );
      return siteAsync.when(
        data: (site) {
          if (site == null) {
            if (widget.embedded) {
              return Center(
                child: Text(context.l10n.diveSites_detail_siteNotFound_body),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.diveSites_detail_siteNotFound_title),
              ),
              body: Center(
                child: Text(context.l10n.diveSites_detail_siteNotFound_body),
              ),
            );
          }
          if (widget.isEditing) {
            _initializeFromSite(site, units);
          } else {
            _initializeFromDuplicate(site, units);
          }
          return _buildForm(context, units);
        },
        loading: () {
          if (widget.embedded) {
            return const Center(child: CircularProgressIndicator());
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.diveSites_detail_loading_title),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        },
        error: (error, _) {
          if (widget.embedded) {
            return Center(
              child: Text(context.l10n.diveSites_detail_error_body('$error')),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.diveSites_detail_error_title),
            ),
            body: Center(
              child: Text(context.l10n.diveSites_detail_error_body('$error')),
            ),
          );
        },
      );
    }

    // For new sites, mark as initialized immediately
    if (!_isInitialized) {
      _isInitialized = true;
      _seedInitialName();
      _seedInitialLocation();
    }

    return _buildForm(context, units);
  }

  /// Smart-collapse expansion state. Merge mode forces everything open.
  final Map<String, bool> _expandedSections = {};

  bool _siteSectionExpanded(String key) {
    if (widget.isMerging) return true;
    final defaults = <String, bool>{
      'location': false,
      'diveInfo': !widget.isEditing,
      'access': false,
      'life': false,
    };
    return _expandedSections[key] ?? defaults[key]!;
  }

  void _toggleSiteSection(String key) {
    setState(() => _expandedSections[key] = !_siteSectionExpanded(key));
  }

  String? _nameValidatorFn(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.diveSites_edit_field_siteName_validation;
    }
    return null;
  }

  String? _latValidatorFn(String? value) {
    if (value != null && value.isNotEmpty) {
      final lat = double.tryParse(value);
      if (lat == null || lat < -90 || lat > 90) {
        return context.l10n.diveSites_edit_gps_latitude_validation;
      }
    }
    return null;
  }

  String? _lonValidatorFn(String? value) {
    if (value != null && value.isNotEmpty) {
      final lng = double.tryParse(value);
      if (lng == null || lng < -180 || lng > 180) {
        return context.l10n.diveSites_edit_gps_longitude_validation;
      }
    }
    return null;
  }

  String? _altitudeValidatorFn(String? value) => numberValidator(
    context,
    check: (altitude) =>
        altitude < 0 ? context.l10n.diveSites_edit_altitude_validation : null,
  )(value);

  MergeFieldExtras? _mergeExtras(String key) {
    final candidates = _mergeTextCandidates[key];
    if (!widget.isMerging || candidates == null || candidates.length < 2) {
      return null;
    }
    final index = _mergeFieldIndices[key] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        candidates[index].siteName,
        index + 1,
        candidates.length,
      ),
      onCycle: () => _cycleTextField(key),
    );
  }

  MergeFieldExtras? _coordinateExtras() {
    if (!widget.isMerging || _coordinateCandidates.length < 2) return null;
    final index = _mergeFieldIndices['coordinates'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _coordinateCandidates[index].siteName,
        index + 1,
        _coordinateCandidates.length,
      ),
      onCycle: _cycleCoordinates,
    );
  }

  MergeFieldExtras? _difficultyExtras() {
    if (!widget.isMerging || _difficultyCandidates.length < 2) return null;
    final index = _mergeFieldIndices['difficulty'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _difficultyCandidates[index].siteName,
        index + 1,
        _difficultyCandidates.length,
      ),
      onCycle: _cycleDifficulty,
    );
  }

  MergeFieldExtras? _waterTypeExtras() {
    if (!widget.isMerging || _waterTypeCandidates.length < 2) return null;
    final index = _mergeFieldIndices['waterType'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _waterTypeCandidates[index].siteName,
        index + 1,
        _waterTypeCandidates.length,
      ),
      onCycle: _cycleWaterType,
    );
  }

  /// The one-tap fill offered when this site has no entry or exit method yet
  /// but the diver has already logged dives here.
  ///
  /// Gated on both fields being empty. Once a site carries a value, dives that
  /// inherited it would otherwise become evidence "confirming" the value the
  /// site itself produced.
  Widget? _entrySuggestionChip() {
    if (!widget.isEditing || widget.siteId == null) return null;
    if (widget.isMerging) return null;
    if (_entryMethods.isNotEmpty || _exitMethods.isNotEmpty) return null;

    return Consumer(
      builder: (context, ref, _) {
        final l10n = context.l10n;
        final async = ref.watch(
          siteEntryExitSuggestionProvider(widget.siteId!),
        );
        return async.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (suggestion) {
            if (suggestion == null) return const SizedBox.shrink();
            final entryLabel = suggestion.entry.localizedName(l10n);
            final label = suggestion.exit == null
                ? l10n.diveSites_edit_access_entrySuggestionEntryOnly(
                    suggestion.count,
                    entryLabel,
                  )
                : l10n.diveSites_edit_access_entrySuggestionPair(
                    suggestion.count,
                    entryLabel,
                    suggestion.exit!.localizedName(l10n),
                  );
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text(label),
                  onPressed: () => setState(() {
                    _entryMethods = [suggestion.entry];
                    _exitMethods = [?suggestion.exit];
                    _hasChanges = true;
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }

  MergeFieldExtras? _entryMethodExtras() {
    if (!widget.isMerging || _entryMethodCandidates.length < 2) return null;
    final index = _mergeFieldIndices['entryMethod'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _entryMethodCandidates[index].siteName,
        index + 1,
        _entryMethodCandidates.length,
      ),
      onCycle: _cycleEntryMethod,
    );
  }

  MergeFieldExtras? _exitMethodExtras() {
    if (!widget.isMerging || _exitMethodCandidates.length < 2) return null;
    final index = _mergeFieldIndices['exitMethod'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _exitMethodCandidates[index].siteName,
        index + 1,
        _exitMethodCandidates.length,
      ),
      onCycle: _cycleExitMethod,
    );
  }

  MergeFieldExtras? _ratingExtras() {
    if (!widget.isMerging || _ratingCandidates.length < 2) return null;
    final index = _mergeFieldIndices['rating'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _ratingCandidates[index].siteName,
        index + 1,
        _ratingCandidates.length,
      ),
      onCycle: _cycleRating,
    );
  }

  int _identityErrorCount() =>
      _nameValidatorFn(_nameController.text) == null ? 0 : 1;

  int _locationErrorCount() {
    var count = 0;
    if (_latValidatorFn(_latitudeController.text) != null) count++;
    if (_lonValidatorFn(_longitudeController.text) != null) count++;
    return count;
  }

  String _locationSummary(UnitFormatter units) => [
    if (_latitudeController.text.isNotEmpty &&
        _longitudeController.text.isNotEmpty)
      '${_latitudeController.text}, ${_longitudeController.text}',
    if (_altitudeController.text.isNotEmpty)
      '${_altitudeController.text} ${units.altitudeSymbol}',
  ].join(' · ');

  bool _locationIsEmpty() =>
      _latitudeController.text.isEmpty &&
      _longitudeController.text.isEmpty &&
      _altitudeController.text.isEmpty;

  String _diveInfoSummary() => [
    if (_minDepthController.text.isNotEmpty ||
        _maxDepthController.text.isNotEmpty)
      '${_minDepthController.text.isEmpty ? '?' : _minDepthController.text}'
          '-${_maxDepthController.text.isEmpty ? '?' : _maxDepthController.text}',
    if (_difficulty != null) _difficulty!.localizedName(context.l10n),
    if (_waterType != null) _waterType!.localizedName(context.l10n),
    if (_rating > 0) '★' * _rating.round(),
  ].join(' · ');

  String _methodNames(List<EntryMethod> methods) =>
      joinEntryMethodNames(methods, (m) => m.localizedName(context.l10n));

  String _accessSummary() => [
    if (_accessNotesController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_access_accessNotes_label,
    if (_entryMethods.isNotEmpty) _methodNames(_entryMethods),
    // Only when it differs, so the common mirrored case does not read
    // "Boat · Boat".
    if (exitDiffersFromEntry(_entryMethods, _exitMethods))
      _methodNames(_exitMethods),
    if (_mooringNumberController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_access_mooringNumber_label,
    if (_parkingInfoController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_access_parkingInfo_label,
    if (_hazardsController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_section_hazards,
  ].join(' · ');

  String _lifeNotesSummary() => [
    if (_expectedSpecies.isNotEmpty)
      context.l10n.diveLog_edit_summary_species(_expectedSpecies.length),
    if (_notesController.text.trim().isNotEmpty)
      context.l10n.diveLog_edit_summary_notes,
    if (_sharing.isShared) context.l10n.diveSites_edit_summary_shared,
  ].join(' · ');

  Widget _buildForm(BuildContext context, UnitFormatter units) {
    final allSites = ref.watch(sitesProvider).value ?? const <DiveSite>[];
    final body = Form(
      key: _formKey,
      // Split after Location so Identity (+ Type & Tags) + Location lead the
      // left column and Dive info / Access / Life fill the right on wide
      // windows. A merge has no Type & Tags section: mergeSites unions them.
      child: ResponsiveFormColumns(
        splitIndex: widget.isMerging ? 2 : 3,
        children: [
          IdentitySection(
            allSites: allSites,
            excludeId: _originalSite?.id,
            nameController: _nameController,
            descriptionController: _descriptionController,
            countryController: _countryController,
            regionController: _regionController,
            cityController: _cityController,
            islandController: _islandController,
            bodyOfWaterController: _bodyOfWaterController,
            nameValidator: _nameValidatorFn,
            mergeExtras: widget.isMerging ? _mergeExtras : null,
            errorCount: _identityErrorCount(),
          ),
          if (!widget.isMerging)
            TypeTagsSection(
              allTypes: ref.watch(siteTypesProvider).value ?? const [],
              hiddenTypeIds: ref.watch(
                hiddenBuiltInIdsProvider(BuiltInCatalog.siteTypes),
              ),
              keepTypeIds: _originalTypeIds,
              selectedTypeIds: _selectedTypeIds,
              onTypesChanged: (ids) => setState(() {
                _selectedTypeIds = ids;
                _typesTouched = true;
                _hasChanges = true;
              }),
              selectedTags: _selectedTags,
              onTagsChanged: (tags) => setState(() {
                _selectedTags = tags;
                _tagsTouched = true;
                _hasChanges = true;
              }),
              onManageTypes: () => context.push('/site-types'),
            ),
          LocationSection(
            expanded: _siteSectionExpanded('location'),
            onToggle: widget.isMerging
                ? null
                : () => _toggleSiteSection('location'),
            summary: _locationSummary(units),
            isEmpty: _locationIsEmpty(),
            errorCount: _locationErrorCount(),
            latitudeController: _latitudeController,
            longitudeController: _longitudeController,
            coordinateFormat: ref.watch(coordinateFormatProvider),
            altitudeController: _altitudeController,
            latValidator: _latValidatorFn,
            lonValidator: _lonValidatorFn,
            altitudeValidator: _altitudeValidatorFn,
            isGettingLocation: _isGettingLocation,
            onUseMyLocation: _useMyLocation,
            onPickFromMap: _pickFromMap,
            onLookupFromCoordinates: _parsedCoordinates() == null
                ? null
                : _lookupFromCoordinates,
            units: units,
            coordinatesExtras: _coordinateExtras(),
            altitudeExtras: _mergeExtras('altitude'),
          ),
          DiveInfoSection(
            expanded: _siteSectionExpanded('diveInfo'),
            onToggle: widget.isMerging
                ? null
                : () => _toggleSiteSection('diveInfo'),
            summary: _diveInfoSummary(),
            isEmpty: _diveInfoSummary().isEmpty,
            minDepthController: _minDepthController,
            maxDepthController: _maxDepthController,
            depthSymbol: units.depthSymbol,
            difficulty: _difficulty,
            onDifficultyChanged: (value) => setState(() {
              _difficulty = value;
              _hasChanges = true;
            }),
            rating: _rating.round(),
            onRatingChanged: (value) => setState(() {
              _rating = value.toDouble();
              _hasChanges = true;
            }),
            onRatingCleared: () => setState(() {
              _rating = 0;
              _hasChanges = true;
            }),
            waterType: _waterType,
            onWaterTypeChanged: (value) => setState(() {
              _waterType = value;
              _hasChanges = true;
            }),
            mergeExtras: widget.isMerging ? _mergeExtras : null,
            difficultyExtras: _difficultyExtras(),
            ratingExtras: _ratingExtras(),
            waterTypeExtras: _waterTypeExtras(),
          ),
          AccessSafetySection(
            expanded: _siteSectionExpanded('access'),
            onToggle: widget.isMerging
                ? null
                : () => _toggleSiteSection('access'),
            summary: _accessSummary(),
            isEmpty: _accessSummary().isEmpty,
            accessNotesController: _accessNotesController,
            mooringNumberController: _mooringNumberController,
            parkingInfoController: _parkingInfoController,
            hazardsController: _hazardsController,
            mergeExtras: widget.isMerging ? _mergeExtras : null,
            entryMethods: _entryMethods,
            exitMethods: _exitMethods,
            onEntryMethodChanged: (value) => setState(() {
              _entryMethods = value;
              _hasChanges = true;
            }),
            onExitMethodChanged: (value) => setState(() {
              _exitMethods = value;
              _hasChanges = true;
            }),
            entryMethodExtras: _entryMethodExtras(),
            exitMethodExtras: _exitMethodExtras(),
            entrySuggestion: _entrySuggestionChip(),
          ),
          LifeNotesSection(
            expanded: _siteSectionExpanded('life'),
            onToggle: widget.isMerging
                ? null
                : () => _toggleSiteSection('life'),
            summary: _lifeNotesSummary(),
            isEmpty: _lifeNotesSummary().isEmpty,
            species: _expectedSpecies,
            onAddSpecies: _showSpeciesPicker,
            onRemoveSpecies: (s) => setState(() {
              _expectedSpecies = _expectedSpecies
                  .where((existing) => existing.id != s.id)
                  .toList();
              _hasChanges = true;
            }),
            notesController: _notesController,
            mergeExtras: widget.isMerging ? _mergeExtras : null,
            // A merge keeps each site's sharing (issue #2151), and a
            // shared site library site follows its library.
            shareField:
                !widget.isMerging &&
                    !(_originalSite?.isLibrarySite ?? false) &&
                    (ref.watch(allDiversProvider).value?.length ?? 0) >= 2
                ? ItemSharingField(
                    kind: SharedItemKind.site,
                    value: _sharing,
                    original: _originalSharing,
                    mayShare:
                        _sharingUnread || (widget.isEditing && !_sharingLoaded)
                        ? null
                        : _mayShare(),
                    ownerId:
                        _originalSite?.diverId ??
                        ref.watch(validatedCurrentDiverIdProvider).value,
                    itemName: _nameController.text.trim().isNotEmpty
                        ? _nameController.text.trim()
                        : (_originalSite?.name ?? ''),
                    onChanged: (v) => setState(() {
                      _sharing = v;
                      _hasChanges = true;
                    }),
                  )
                : null,
          ),
          if (_suggestModeShown()) ...[
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('suggestion-note'),
              controller: _suggestionNote,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.sharedLibrary_suggest_note_label,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );

    return EditFormScaffold(
      title: _suggestModeShown()
          ? context.l10n.sharedLibrary_suggest_title
          : widget.isEditing
          ? context.l10n.diveSites_edit_appBar_editSite
          : widget.isMerging
          ? context.l10n.diveSites_edit_appBar_mergeSites
          : widget.isDuplicating
          ? context.l10n.diveSites_edit_appBar_duplicateSite
          : context.l10n.diveSites_edit_appBar_newSite,
      saveLabel: _suggestModeShown()
          ? context.l10n.sharedLibrary_suggest_send
          : null,
      embedded: widget.embedded,
      isSaving: _isLoading,
      hasUnsavedChanges: _hasChanges,
      onSave: _saveSite,
      onCancel: widget.embedded ? _handleCancel : null,
      headerIcon: _suggestModeShown()
          ? Icons.rate_review_outlined
          : widget.isEditing
          ? Icons.edit
          : widget.isMerging
          ? Icons.merge_type
          : Icons.add_location,
      actions: [
        if (widget.isEditing && (!widget.embedded || widget.onDeleted != null))
          // Delete for the owner; another profile only removes the shared
          // site from itself (issue #2594), or unhides it once it has
          // (issue #2679); none of these while the profile is unknown
          // (issue #2682).
          if (_mayShare() == true)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: context.l10n.diveSites_edit_appBar_deleteSiteTooltip,
              onPressed: _confirmDelete,
            )
          else if (watchHiddenHere(
            ref,
            SharedItemKind.site,
            widget.siteId!,
            canDestroy: _mayShare() != false,
          ))
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: context.l10n.sharedItems_unhideAction,
              // A failed unhide says so (issue #2677).
              onPressed: () => runHideChange(
                ScaffoldMessenger.of(context),
                context.l10n,
                () => ref.read(siteListNotifierProvider.notifier).unhideSites([
                  widget.siteId!,
                ]),
              ),
            )
          // Remove only while the site reaches this profile (issue #2151).
          else if (_mayShare() == false &&
              watchReachesHere(
                ref,
                SharedItemKind.site,
                widget.siteId!,
                libraryId: _originalSite?.sharedLibraryId,
              ))
            IconButton(
              icon: const Icon(Icons.visibility_off_outlined),
              tooltip: context.l10n.sharedItems_removeAction,
              onPressed: _confirmRemove,
            ),
      ],
      child: body,
    );
  }

  /// [_mayShare] for a callback, which reads rather than watches.
  bool _mayShareNow() =>
      canDestroySharedItemOnceKnown(
        ref.read(validatedCurrentDiverIdProvider),
        ownerId: _originalSite?.diverId,
        isLibrarySite: _originalSite?.isLibrarySite ?? false,
      ) ==
      true;

  /// Whether the active profile may change this site's sharing (and so
  /// delete it): always for a new site, and only the owner for an existing
  /// one (issue #2594); null while the profile is unknown (issue #2682).
  /// Read during build, so it watches the active profile.
  bool? _mayShare() {
    // A new site is the active profile's; until that profile is known the
    // picker could offer it to itself, so sharing waits (issue #2151).
    if (!widget.isEditing && !widget.isMerging) {
      return ref.watch(validatedCurrentDiverIdProvider).hasValue ? true : null;
    }
    return canDestroySharedItemOnceKnown(
      ref.watch(validatedCurrentDiverIdProvider),
      ownerId: _originalSite?.diverId,
      // A shared site library site is deleted through its role-gated action on
      // the detail page, never through the personal delete (issue #2567).
      isLibrarySite: _originalSite?.isLibrarySite ?? false,
    );
  }

  Future<_MergeLoadData> _loadMergeData() async {
    final siteRepository = ref.read(siteRepositoryProvider);
    final speciesRepository = ref.read(speciesRepositoryProvider);
    final requestedIds = widget.mergeSiteIds ?? const <String>[];
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
        if (seenSpeciesIds.add(entry.speciesId)) {
          final species = speciesById[entry.speciesId];
          if (species != null) {
            mergedSpecies.add(species);
          }
        }
      }
    }

    return _MergeLoadData(sites: orderedSites, expectedSpecies: mergedSpecies);
  }

  void _initializeMergeTextField({
    required String key,
    required TextEditingController controller,
    required List<DiveSite> sites,
    required String Function(DiveSite site) getValue,
    required bool Function(String value) isMeaningful,
  }) {
    final candidates = _buildDistinctCandidates<String>(
      sites,
      getValue,
      equals: (a, b) => a == b,
    );
    _mergeTextCandidates[key] = candidates;
    _mergeFieldIndices[key] = _firstMeaningfulIndex(candidates, isMeaningful);
    controller.text = candidates[_mergeFieldIndices[key] ?? 0].value;
  }

  List<_MergeFieldCandidate<T>> _buildDistinctCandidates<T>(
    List<DiveSite> sites,
    T Function(DiveSite site) getValue, {
    required bool Function(T a, T b) equals,
  }) {
    final candidates = <_MergeFieldCandidate<T>>[];
    for (final site in sites) {
      final value = getValue(site);
      final alreadyIncluded = candidates.any(
        (candidate) => equals(candidate.value, value),
      );
      if (!alreadyIncluded) {
        candidates.add(
          _MergeFieldCandidate(
            siteId: site.id,
            siteName: site.name,
            value: value,
          ),
        );
      }
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

  void _selectTextFieldCandidate(String key, int index) {
    final candidates = _mergeTextCandidates[key];
    if (candidates == null || index < 0 || index >= candidates.length) return;

    // Text rows only. Enum-valued merge fields (difficulty, waterType,
    // entryMethod, exitMethod) and rating are cycled by their own _cycleX
    // methods against their own candidate lists, so their absence from this
    // switch is deliberate rather than a missing case.
    final controller = switch (key) {
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

    if (controller == null) return;

    setState(() {
      _mergeFieldIndices[key] = index;
      controller.text = candidates[index].value;
      _hasChanges = true;
    });
  }

  void _cycleTextField(String key) {
    final candidates = _mergeTextCandidates[key];
    if (candidates == null || candidates.length < 2) return;

    final nextIndex = ((_mergeFieldIndices[key] ?? 0) + 1) % candidates.length;
    _selectTextFieldCandidate(key, nextIndex);
  }

  void _cycleDifficulty() {
    if (_difficultyCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['difficulty'] ?? 0) + 1) %
          _difficultyCandidates.length;
      _mergeFieldIndices['difficulty'] = nextIndex;
      _difficulty = _difficultyCandidates[nextIndex].value;
      _hasChanges = true;
    });
  }

  void _cycleWaterType() {
    if (_waterTypeCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['waterType'] ?? 0) + 1) %
          _waterTypeCandidates.length;
      _mergeFieldIndices['waterType'] = nextIndex;
      _waterType = _waterTypeCandidates[nextIndex].value;
      _hasChanges = true;
    });
  }

  void _cycleEntryMethod() {
    if (_entryMethodCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['entryMethod'] ?? 0) + 1) %
          _entryMethodCandidates.length;
      _mergeFieldIndices['entryMethod'] = nextIndex;
      _entryMethods = _entryMethodCandidates[nextIndex].value;
      _hasChanges = true;
    });
  }

  void _cycleExitMethod() {
    if (_exitMethodCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['exitMethod'] ?? 0) + 1) %
          _exitMethodCandidates.length;
      _mergeFieldIndices['exitMethod'] = nextIndex;
      _exitMethods = _exitMethodCandidates[nextIndex].value;
      _hasChanges = true;
    });
  }

  void _cycleRating() {
    if (_ratingCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['rating'] ?? 0) + 1) % _ratingCandidates.length;
      _mergeFieldIndices['rating'] = nextIndex;
      _rating = _ratingCandidates[nextIndex].value;
      _hasChanges = true;
    });
  }

  void _cycleCoordinates() {
    if (_coordinateCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['coordinates'] ?? 0) + 1) %
          _coordinateCandidates.length;
      _mergeFieldIndices['coordinates'] = nextIndex;
      _applyCoordinateCandidate(_coordinateCandidates[nextIndex].value);
      _hasChanges = true;
    });
  }

  void _applyCoordinateCandidate(_CoordinateCandidate candidate) {
    _latitudeController.text = candidate.latitudeText;
    _longitudeController.text = candidate.longitudeText;
  }

  Future<bool> _confirmMerge() async {
    final count = widget.mergeSiteIds?.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveSites_edit_merge_confirmTitle),
        content: Text(context.l10n.diveSites_edit_merge_confirmBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.diveSites_edit_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.diveSites_edit_appBar_merge),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  bool _isGettingLocation = false;

  Future<void> _useMyLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final locationService = ref.read(locationServiceProvider);
      final result = await locationService.getCurrentLocation(
        includeGeocoding: true,
        languageCode: ref.read(placeNameLanguageProvider),
      );

      if (result == null) {
        if (mounted) {
          final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMobile
                    ? context
                          .l10n
                          .diveSites_edit_snackbar_locationUnavailableMobile
                    : context
                          .l10n
                          .diveSites_edit_snackbar_locationUnavailableDesktop,
              ),
              action: isMobile
                  ? SnackBarAction(
                      label:
                          context.l10n.diveSites_edit_snackbar_locationSettings,
                      onPressed: () => locationService.openAppSettings(),
                    )
                  : null,
            ),
          );
        }
        return;
      }

      setState(() {
        _latitudeController.text = result.latitude.toStringAsFixed(6);
        _longitudeController.text = result.longitude.toStringAsFixed(6);
        _hasChanges = true;
        _applyPlaceLookup(result.place, overwrite: false);
      });

      if (mounted) {
        // The position landed in the form either way; say so, but when the
        // geocoder was unreachable explain why the place fields stayed empty.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.place.networkFailed
                  ? context.l10n.diveSites_edit_snackbar_lookupFailed
                  : result.accuracy != null
                  ? context.l10n
                        .diveSites_edit_snackbar_locationCapturedWithAccuracy(
                          result.accuracy!.toStringAsFixed(0),
                        )
                  : context.l10n.diveSites_edit_snackbar_locationCaptured,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _pickFromMap() async {
    LatLng? initialLocation;
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat != null && lng != null) {
      initialLocation = LatLng(lat, lng);
    }

    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (context) =>
            LocationPickerMap(initialLocation: initialLocation),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitudeController.text = result.latitude.toStringAsFixed(6);
        _longitudeController.text = result.longitude.toStringAsFixed(6);
        _hasChanges = true;
        _applyPlaceLookup(result.place, overwrite: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.place.networkFailed
                ? context.l10n.diveSites_edit_snackbar_lookupFailed
                : context.l10n.diveSites_edit_snackbar_locationSelectedFromMap,
          ),
        ),
      );
    }
  }

  /// The typed coordinates, or null while either field does not parse.
  GeoPoint? _parsedCoordinates() {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return GeoPoint(lat, lng);
  }

  /// Explicit lookup for the typed coordinates (issue #1187). Fills empty
  /// fields; when nothing was empty and the lookup differs, offers to
  /// replace. Never runs on save.
  Future<void> _lookupFromCoordinates() async {
    final point = _parsedCoordinates();
    if (point == null) return;
    setState(() => _isGettingLocation = true);
    try {
      final lookup = await ref
          .read(locationServiceProvider)
          .reverseGeocode(
            point.latitude,
            point.longitude,
            languageCode: ref.read(placeNameLanguageProvider),
          );
      if (!mounted) return;
      // The busy indicator must stop before any dialog waits for input.
      setState(() => _isGettingLocation = false);

      if (lookup.networkFailed) {
        _showLookupSnackBar(context.l10n.diveSites_edit_snackbar_lookupFailed);
        return;
      }
      if (lookup.isEmpty) {
        _showLookupSnackBar(
          context.l10n.diveSites_edit_snackbar_lookupNothingFound,
        );
        return;
      }

      var changed = false;
      setState(() {
        changed = _applyPlaceLookup(lookup, overwrite: false);
        if (changed) _hasChanges = true;
      });
      if (changed) return;

      final differing = _differingLookupValues(lookup);
      if (differing.isEmpty) return;
      final replace = await _confirmReplaceLocationDetails(differing);
      if (!mounted || !replace) return;
      setState(() {
        if (_applyPlaceLookup(lookup, overwrite: true)) _hasChanges = true;
      });
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _showLookupSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Field label to found value, for the fields whose found value is
  /// non-blank and differs from what the form shows.
  Map<String, String> _differingLookupValues(PlaceLookup lookup) {
    final l10n = context.l10n;
    final out = <String, String>{};
    void compare(String label, String current, String? found) {
      if (found == null || found.trim().isEmpty) return;
      if (current.trim() == found.trim()) return;
      out[label] = found.trim();
    }

    compare(
      l10n.diveSites_edit_field_country_label,
      _countryController.text,
      lookup.country,
    );
    compare(
      l10n.diveSites_edit_field_region_label,
      _regionController.text,
      lookup.region,
    );
    compare(
      l10n.diveSites_edit_field_city_label,
      _cityController.text,
      lookup.locality,
    );
    compare(
      l10n.diveSites_edit_field_bodyOfWater_label,
      _bodyOfWaterController.text,
      lookup.bodyOfWater,
    );
    return out;
  }

  Future<bool> _confirmReplaceLocationDetails(
    Map<String, String> differing,
  ) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.diveSites_edit_lookupReplace_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.diveSites_edit_lookupReplace_body),
            const SizedBox(height: 12),
            for (final entry in differing.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${entry.key}: ${entry.value}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.diveSites_edit_lookupReplace_keep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.diveSites_edit_lookupReplace_replace),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showSpeciesPicker() async {
    final selectedIds = _expectedSpecies.map((s) => s.id).toSet();

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => SpeciesPickerDialog(initialSelection: selectedIds),
    );

    if (result != null) {
      // Fetch full species data for the selected IDs
      final repository = ref.read(speciesRepositoryProvider);
      final allSpecies = await repository.getAllSpecies();
      final selectedSpecies = allSpecies
          .where((s) => result.contains(s.id))
          .toList();

      setState(() {
        _expectedSpecies = selectedSpecies;
        _hasChanges = true;
      });
    }
  }

  static double? _validatedNumber(TextEditingController controller) =>
      switch (readNumber(controller.text)) {
        NumberValue(:final value) => value,
        NumberBlank() => null,
        NumberInvalid() => null, // unreachable: validate() ran first
      };

  /// Suggestion mode: asked for, or forced on a shared site library site this
  /// profile may not edit, so a deep link to the plain edit route cannot
  /// write the site (issue #2567). Plain editing while the role loads; the
  /// save decides again with the settled role.
  bool _suggestModeShown() {
    if (widget.suggest) return true;
    final id = _originalSite?.sharedLibraryId;
    if (id == null) return false;
    final role = ref.watch(libraryRoleProvider(id)).valueOrNull;
    final connected = ref.watch(libraryConnectedHereProvider(id)).valueOrNull;
    if (role == null || connected == null) return false;
    return !(connected && canEditLibrarySite(role));
  }

  Future<bool> _suggestModeAtSave() async {
    if (widget.suggest) return true;
    final id = _originalSite?.sharedLibraryId;
    if (id == null) return false;
    final role = await _libraryRoleNow(id);
    return role == null || !canEditLibrarySite(role);
  }

  /// The profile's effective role in [libraryId] from the store, or null
  /// when the library is not connected here. Read from the store, not the
  /// providers: in requested suggestion mode nothing watches them, and a
  /// one-shot read of a paused stream provider never returns.
  Future<SharedLibraryRole?> _libraryRoleNow(String libraryId) async {
    final store = ref.read(sharedLibraryStoreProvider);
    final library = await store.getLibrary(libraryId);
    if (library == null) return null;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final membership = diverId == null
        ? null
        : await store.membership(diverId: diverId, libraryId: libraryId);
    if (membership == null) return SharedLibraryRole.reader;
    return effectiveRole(
      listed: library.roles.roleOf(membership.memberId),
      readOnlyDetected: library.writesHeld,
    );
  }

  /// Notes and rating on a library site are the member's own (issue #2567):
  /// saved on the row, never proposed. True when either changed.
  Future<bool> _savePrivateFields(DiveSite site, String diverId) async {
    final stored = await SiteRepository().getSiteById(site.id);
    if (stored == null ||
        (stored.notes == site.notes && stored.rating == site.rating)) {
      return false;
    }
    await SiteRepository().updateSite(
      stored.copyWith(
        notes: site.notes,
        rating: site.rating,
        clearRating: site.rating == null,
      ),
      actingDiverId: diverId,
    );
    ref.invalidate(siteProvider(site.id));
    return true;
  }

  /// A reader's save on a shared site library site (issue #2567): the changed
  /// fields and the note become a suggestion; the site is untouched.
  Future<void> _sendSuggestion(
    DiveSite site,
    bool classificationChanged,
  ) async {
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    final savedPrivate = await _savePrivateFields(site, diverId);
    if (!mounted) return;
    var childFields = const <String, Object?>{};
    if (classificationChanged) {
      final types = await SiteTypeRepository().getAllSiteTypes(
        diverId: diverId,
      );
      childFields = suggestionChildFields(
        originalTypeIds: _originalTypeIds,
        selectedTypeIds: _selectedTypeIds,
        typeNames: {for (final t in types) t.id: t.name},
        originalTagIds: _originalTagIds,
        selectedTags: [for (final t in _selectedTags) (id: t.id, name: t.name)],
      );
    }
    final suggestion = await ref
        .read(suggestionServiceProvider)
        .propose(
          proposed: site,
          diverId: diverId,
          note: _suggestionNote.text,
          childFields: childFields,
        );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasChanges = false;
    });
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          suggestion != null
              ? l10n.sharedLibrary_suggest_sent
              : savedPrivate
              ? l10n.sharedLibrary_suggest_savedPrivate
              : l10n.sharedLibrary_suggest_nothingChanged,
        ),
      ),
    );
    if (suggestion == null && !savedPrivate) return;
    if (widget.onSaved != null) {
      widget.onSaved!(site.id);
    } else {
      // A plain pop, as a save leaves: maybePop would ask the unsaved
      // changes guard, which still holds the frame before the send.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    }
  }

  Future<void> _saveSite() async {
    // Collapsed sections un-mount their fields, hiding them from
    // Form.validate(); expand everything first so no error can hide.
    final anyCollapsed = [
      'location',
      'diveInfo',
      'access',
      'life',
    ].any((key) => !_siteSectionExpanded(key));
    if (anyCollapsed) {
      setState(() {
        for (final key in const ['location', 'diveInfo', 'access', 'life']) {
          _expandedSections[key] = true;
        }
      });
      // A zero-length delay resolves before the frame that builds the
      // expanded sections, so their fields would miss validate() (#1900).
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    // A site created by hand gets its logbook rules (#3513); edits and
    // merges never run them. Read now: the diver can leave while the save
    // runs, and the new site gets them either way.
    final rulesAfterCreate = widget.isEditing || widget.isMerging
        ? null
        : captureRulesAfterCreate(context, ref);
    await _duplicateLoads;
    if (!mounted) return;

    try {
      final settings = ref.read(settingsProvider);
      final units = UnitFormatter(settings);

      GeoPoint? location;
      final latText = _latitudeController.text.trim();
      final lngText = _longitudeController.text.trim();

      if (latText.isNotEmpty && lngText.isNotEmpty) {
        final lat = double.tryParse(latText);
        final lng = double.tryParse(lngText);
        if (lat != null && lng != null) {
          location = GeoPoint(lat, lng);
        }
      }

      // Blank is "not recorded"; validate() above stopped unreadable text.
      final minDepthInput = _validatedNumber(_minDepthController);
      final maxDepthInput = _validatedNumber(_maxDepthController);
      final altitudeInput = _validatedNumber(_altitudeController);
      final minDepthMeters = minDepthInput != null
          ? units.depthToMeters(minDepthInput)
          : null;
      final maxDepthMeters = maxDepthInput != null
          ? units.depthToMeters(maxDepthInput)
          : null;
      final altitudeMeters = altitudeInput != null
          ? units.altitudeToMeters(altitudeInput)
          : null;

      // Location fields persist exactly as shown. We deliberately do NOT
      // reverse-geocode empty country/region on save: an empty field is
      // indistinguishable from one the user intentionally cleared, so silently
      // refilling it makes a cleared field un-clearable and overrides the
      // user's edits. Auto-fill happens only on explicit request, via the
      // "Use my location" / "Pick from map" actions (which fill empty fields).
      final String? country = _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim();
      final String? region = _regionController.text.trim().isEmpty
          ? null
          : _regionController.text.trim();
      final String? city = _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim();
      final String? island = _islandController.text.trim().isEmpty
          ? null
          : _islandController.text.trim();
      final String? bodyOfWater = _bodyOfWaterController.text.trim().isEmpty
          ? null
          : _bodyOfWaterController.text.trim();

      final diverId =
          _originalSite?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      final site = DiveSite(
        id: widget.siteId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        country: country,
        region: region,
        city: city,
        island: island,
        bodyOfWater: bodyOfWater,
        minDepth: minDepthMeters,
        maxDepth: maxDepthMeters,
        difficulty: _difficulty,
        location: location,
        rating: _rating > 0 ? _rating : null,
        notes: _notesController.text.trim(),
        hazards: _hazardsController.text.trim().isEmpty
            ? null
            : _hazardsController.text.trim(),
        accessNotes: _accessNotesController.text.trim().isEmpty
            ? null
            : _accessNotesController.text.trim(),
        mooringNumber: _mooringNumberController.text.trim().isEmpty
            ? null
            : _mooringNumberController.text.trim(),
        parkingInfo: _parkingInfoController.text.trim().isEmpty
            ? null
            : _parkingInfoController.text.trim(),
        altitude: altitudeMeters,
        waterType: _waterType,
        entryMethods: _entryMethods,
        exitMethods: _exitMethods,
        isShared: _sharing.everyone,
      );

      final notifier = ref.read(siteListNotifierProvider.notifier);
      String savedId;
      // Set when a duplicate saved but its map features did not copy.
      var featuresNotCopied = false;

      // Types and tags (issue #1765) are written with the row, in one
      // transaction, only when the diver changed them on this page.
      final classificationChanged =
          !widget.isEditing ||
          !setEquals(_selectedTypeIds, _originalTypeIds) ||
          !setEquals({for (final t in _selectedTags) t.id}, _originalTagIds);
      final classification = classificationChanged
          ? SiteClassification(
              typeIds: _selectedTypeIds.toList(),
              tagIds: [for (final t in _selectedTags) t.id],
            )
          : null;

      // A shared site library not connected on this device: neither an edit nor a
      // suggestion could ever reach it from here (issue #2567).
      final libraryId = _originalSite?.sharedLibraryId;
      if (libraryId != null && await _libraryRoleNow(libraryId) == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.sharedLibrary_list_notConnected),
            ),
          );
        }
        return;
      }

      if (await _suggestModeAtSave()) {
        await _sendSuggestion(site, classificationChanged);
        return;
      }

      MergeSnapshot? mergeSnapshot;

      if (widget.isMerging) {
        final confirmed = await _confirmMerge();
        if (!confirmed) {
          return;
        }

        mergeSnapshot = await notifier.mergeSites(site, widget.mergeSiteIds!);
        if (mergeSnapshot == null) {
          // Refused (a duplicate belongs to another profile, issue #2594):
          // nothing merged, so stay, say so and write nothing more.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.sharedItems_notOwner_site)),
            );
          }
          return;
        }
        savedId = widget.mergeSiteIds!.first;
      } else if (widget.isEditing) {
        await notifier.updateSite(site, classification: classification);
        savedId = widget.siteId!;
      } else {
        final newSite = await notifier.addSite(
          site,
          classification: classification,
        );
        savedId = newSite.id;
        if (widget.isDuplicating) {
          // The site is saved by now, so a failure here must not read as a
          // failed save: saving again would make a second copy.
          try {
            await ref
                .read(siteFeatureRepositoryProvider)
                .copyFeatures(
                  fromSiteId: widget.duplicateOfId!,
                  toSiteId: savedId,
                  actingDiverId: diverId,
                );
          } catch (e, stackTrace) {
            _log.error(
              'Could not copy the map features of site '
              '${widget.duplicateOfId} to its duplicate $savedId',
              error: e,
              stackTrace: stackTrace,
            );
            featuresNotCopied = true;
          }
        }
      }
      // The chosen profiles (issue #2151), only when the owner changed
      // them; the save above already wrote the everyone flag. Checked in
      // this order so an unchanged save never reads the active profile. A
      // merge carries each site's sharing itself.
      if (!widget.isMerging &&
          !_sharingUnread &&
          (_sharing != _originalSharing ||
              (_staleShareRows && _sharing.everyone)) &&
          (!widget.isEditing || _mayShareNow())) {
        await ref
            .read(itemSharesRepositoryProvider)
            .setSharing(
              SharedItemKind.site,
              savedId,
              _sharing,
              // The profile acting now, which the repository checks; never
              // the owner on its behalf.
              actingDiverId: ref.read(validatedCurrentDiverIdProvider).value,
            );
      }
      ref.invalidate(siteTypesForSiteProvider(savedId));
      ref.invalidate(tagsForSiteProvider(savedId));

      // Save expected species
      final currentIds = _expectedSpecies.map((s) => s.id).toSet();
      if (currentIds != _originalExpectedSpeciesIds ||
          !widget.isEditing ||
          widget.isMerging) {
        final speciesNotifier = ref.read(
          siteExpectedSpeciesNotifierProvider(savedId).notifier,
        );
        await speciesNotifier.setSpecies(currentIds.toList());
        ref.invalidate(siteExpectedSpeciesProvider(savedId));
        ref.invalidate(siteSpottedSpeciesProvider(savedId));
      }

      // The new site's rules, once its types, tags and species are saved.
      await rulesAfterCreate?.call(subject: RuleSubject.sites, ids: [savedId]);

      ref.invalidate(sitesWithCountsProvider);
      ref.invalidate(sitesProvider);
      if (widget.isEditing) {
        ref.invalidate(siteProvider(widget.siteId!));
      }
      if (widget.isMerging) {
        for (final siteId in widget.mergeSiteIds!) {
          ref.invalidate(siteProvider(siteId));
        }
      }

      if (mounted) {
        _hasChanges = false;
        if (widget.embedded) {
          widget.onSaved?.call(savedId);
        } else if (widget.isMerging) {
          context.pop(
            SiteMergeResult(survivorId: savedId, snapshot: mergeSnapshot),
          );
        } else {
          // A duplicate's opener takes the id and shows the copy where it
          // shows sites (openDuplicateSite).
          context.pop(savedId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEditing
                    ? context.l10n.diveSites_edit_snackbar_siteUpdated
                    : featuresNotCopied
                    ? context.l10n.diveSites_edit_snackbar_featuresNotCopied
                    : context.l10n.diveSites_edit_snackbar_siteAdded,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveSites_edit_snackbar_errorSaving('$e'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final usage = await readSiteDeleteUsage(ref, [widget.siteId!]);
    // A shared site's delete warns that it goes for every profile, and how
    // many of their dives lose it, as the detail page does (issue #2594).
    final divers = await ref.read(allDiversProvider.future);
    if (!mounted) return;
    // Shared with everyone or with chosen profiles (issue #2151), read
    // afresh: this page's own read may not have finished.
    final shared = divers.length < 2
        ? false
        : await readSharedWithAnyone(
            ref,
            context,
            SharedItemKind.site,
            widget.siteId!,
          );
    if (shared == null) return;
    final isSharedDelete = shared;
    final others = isSharedDelete
        ? (await readDiveLinkCounts(
            ref,
            SharedItemKind.site,
            widget.siteId!,
          )).others
        : 0;
    if (!mounted) return;
    final name = _originalSite?.name ?? _nameController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isSharedDelete
              ? context.l10n.sites_deleteShared_title
              : context.l10n.diveSites_detail_deleteDialog_title,
        ),
        content: Text(
          withSiteDeleteUsage(
            context.l10n,
            isSharedDelete
                ? [
                    context.l10n.sites_deleteShared_body(name),
                    ?otherProfilesDivesLine(
                      context.l10n,
                      SharedItemKind.site,
                      others,
                    ),
                  ].join('\n\n')
                : context.l10n.diveSites_detail_deleteDialog_content,
            usage,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.diveSites_detail_deleteDialog_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.diveSites_detail_deleteDialog_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSite();
    }
  }

  /// Hides another profile's shared site from the active profile only
  /// (issue #2594), then leaves the page as a delete does, with Undo.
  Future<void> _confirmRemove() {
    final notifier = ref.read(siteListNotifierProvider.notifier);
    final siteId = widget.siteId!;
    return removeSharedItemFromProfile(
      context,
      ref,
      kind: SharedItemKind.site,
      id: siteId,
      name: _originalSite?.name ?? _nameController.text.trim(),
      ownerId: _originalSite?.diverId,
      hide: () async => await notifier.hideSites([siteId]) == 1,
      unhide: () => notifier.unhideSites([siteId]),
      onRemoved: () {
        _hasChanges = false;
        if (widget.embedded) {
          widget.onDeleted?.call();
        } else {
          context.go('/sites');
        }
      },
    );
  }

  Future<void> _deleteSite() async {
    setState(() => _isLoading = true);

    try {
      final deleted = await ref
          .read(siteListNotifierProvider.notifier)
          .deleteSite(widget.siteId!);
      if (!deleted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.sharedItems_notOwner_site)),
          );
          setState(() => _isLoading = false);
        }
        return;
      }
      ref.invalidate(sitesWithCountsProvider);
      ref.invalidate(sitesProvider);

      if (mounted) {
        _hasChanges = false;
        if (widget.embedded) {
          widget.onDeleted?.call();
        } else {
          context.go('/sites');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.diveSites_detail_deleteSnackbar)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveSites_edit_snackbar_errorDeleting('$e'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}

class _MergeLoadData {
  final List<DiveSite> sites;
  final List<Species> expectedSpecies;

  const _MergeLoadData({required this.sites, required this.expectedSpecies});
}

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

class _CoordinateCandidate {
  final String latitudeText;
  final String longitudeText;

  const _CoordinateCandidate({
    required this.latitudeText,
    required this.longitudeText,
  });
}
