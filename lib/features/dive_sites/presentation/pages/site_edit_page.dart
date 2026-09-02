import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_merge.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/location_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picker_dialog.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/shared/widgets/forms/responsive_form_columns.dart';

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
  final GeoPoint? initialLocation;

  const SiteEditPage({
    super.key,
    this.siteId,
    this.mergeSiteIds,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.initialLocation,
  }) : assert(
         siteId == null || mergeSiteIds == null,
         'siteId and mergeSiteIds are mutually exclusive',
       ),
       assert(
         initialLocation == null || (siteId == null && mergeSiteIds == null),
         'initialLocation is only valid when creating a new site',
       );

  bool get isEditing => siteId != null;
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
  EntryMethod? _entryMethod;
  EntryMethod? _exitMethod;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;
  bool _isShared = false;
  bool _isApplyingInitialValues = false;
  Timer? _altitudeLookupDebounce;
  DiveSite? _originalSite;
  List<Species> _expectedSpecies = [];
  Set<String> _originalExpectedSpeciesIds = {};
  late final Future<_MergeLoadData>? _mergeLoadFuture;
  final Map<String, List<_MergeFieldCandidate<String>>> _mergeTextCandidates =
      {};
  final Map<String, int> _mergeFieldIndices = {};
  List<_MergeFieldCandidate<SiteDifficulty?>> _difficultyCandidates = [];
  List<_MergeFieldCandidate<WaterType?>> _waterTypeCandidates = [];
  List<_MergeFieldCandidate<EntryMethod?>> _entryMethodCandidates = [];
  List<_MergeFieldCandidate<EntryMethod?>> _exitMethodCandidates = [];
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
    if (!widget.isEditing && !widget.isMerging) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final shareByDefault = await ref.read(shareByDefaultProvider.future);
        if (!mounted) return;
        setState(() => _isShared = shareByDefault);
      });
    }
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
  /// fields. With [overwrite] false only empty fields change (the rule lives
  /// in [mergeMissingLocationDetails]); with it true every found value
  /// replaces the current one. Returns whether any field changed. Callers
  /// decide whether that dirties the form.
  bool _applyPlaceLookup(PlaceLookup lookup, {required bool overwrite}) {
    final current = overwrite
        ? const SiteLocationDetails()
        : SiteLocationDetails(
            country: _countryController.text,
            region: _regionController.text,
            city: _cityController.text,
            bodyOfWater: _bodyOfWaterController.text,
          );
    final merged = mergeMissingLocationDetails(current: current, found: lookup);
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
    _entryMethod = site.entryMethod;
    _exitMethod = site.exitMethod;
    _isShared = site.isShared;
    _altitudeController.text = site.altitude != null
        ? _altitudeForInput(units.convertAltitude(site.altitude!))
        : '';
    _isApplyingInitialValues = false;

    // Load expected species
    _loadExpectedSpecies(site.id);
  }

  void _initializeFromMerge(_MergeLoadData data, UnitFormatter units) {
    if (_isInitialized) return;
    _isInitialized = true;
    _originalSite = data.sites.first;
    _isShared = data.sites.first.isShared;
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

    _entryMethodCandidates = _buildDistinctCandidates<EntryMethod?>(
      data.sites,
      (site) => site.entryMethod,
      equals: (a, b) => a == b,
    );
    _mergeFieldIndices['entryMethod'] = _firstMeaningfulIndex(
      _entryMethodCandidates,
      (value) => value != null,
    );
    _entryMethod =
        _entryMethodCandidates[_mergeFieldIndices['entryMethod'] ?? 0].value;

    _exitMethodCandidates = _buildDistinctCandidates<EntryMethod?>(
      data.sites,
      (site) => site.exitMethod,
      equals: (a, b) => a == b,
    );
    _mergeFieldIndices['exitMethod'] = _firstMeaningfulIndex(
      _exitMethodCandidates,
      (value) => value != null,
    );
    _exitMethod =
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

    if (widget.isEditing) {
      final siteAsync = ref.watch(siteProvider(widget.siteId!));
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
          _initializeFromSite(site, units);
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

  String? _altitudeValidatorFn(String? value) {
    if (value != null && value.isNotEmpty) {
      final altitude = parseUserDecimal(value);
      if (altitude == null || altitude < 0) {
        return context.l10n.diveSites_edit_altitude_validation;
      }
    }
    return null;
  }

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
    if (_entryMethod != null || _exitMethod != null) return null;

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
                    _entryMethod = suggestion.entry;
                    _exitMethod = suggestion.exit;
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
    if (_difficulty != null) _difficulty!.displayName,
    if (_waterType != null) _waterType!.displayName,
    if (_rating > 0) '★' * _rating.round(),
  ].join(' · ');

  String _accessSummary() => [
    if (_accessNotesController.text.trim().isNotEmpty)
      context.l10n.diveSites_edit_access_accessNotes_label,
    if (_entryMethod != null) _entryMethod!.localizedName(context.l10n),
    // Only when it differs, so the common mirrored case does not read
    // "Boat Entry · Boat Entry".
    if (_exitMethod != null && _exitMethod != _entryMethod)
      _exitMethod!.localizedName(context.l10n),
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
    if (_isShared) context.l10n.diveSites_edit_summary_shared,
  ].join(' · ');

  Future<void> _onShareToggled(bool v) async {
    if (!v && widget.isEditing && (_originalSite?.isShared ?? false)) {
      final confirmed = await _showUnshareConfirmDialog(context);
      if (!mounted) return;
      if (confirmed != true) return;
    }
    setState(() {
      _isShared = v;
      _hasChanges = true;
    });
  }

  Widget _buildForm(BuildContext context, UnitFormatter units) {
    final allSites = ref.watch(sitesProvider).value ?? const <DiveSite>[];
    final body = Form(
      key: _formKey,
      // Split after Location so Identity + Location lead the left column and
      // Dive info / Access / Life fill the right on wide windows.
      child: ResponsiveFormColumns(
        splitIndex: 2,
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
            entryMethod: _entryMethod,
            exitMethod: _exitMethod,
            onEntryMethodChanged: (value) => setState(() {
              _entryMethod = value;
              _hasChanges = true;
            }),
            onExitMethodChanged: (value) => setState(() {
              _exitMethod = value;
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
            showShareToggle: ref
                .watch(allDiversProvider)
                .maybeWhen(data: (d) => d.length >= 2, orElse: () => false),
            isShared: _isShared,
            onShareChanged: _onShareToggled,
          ),
        ],
      ),
    );

    return EditFormScaffold(
      title: widget.isEditing
          ? context.l10n.diveSites_edit_appBar_editSite
          : widget.isMerging
          ? context.l10n.diveSites_edit_appBar_mergeSites
          : context.l10n.diveSites_edit_appBar_newSite,
      embedded: widget.embedded,
      isSaving: _isLoading,
      hasUnsavedChanges: _hasChanges,
      onSave: _saveSite,
      onCancel: widget.embedded ? _handleCancel : null,
      headerIcon: widget.isEditing
          ? Icons.edit
          : widget.isMerging
          ? Icons.merge_type
          : Icons.add_location,
      actions: [
        if (widget.isEditing && !widget.embedded)
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: context.l10n.diveSites_edit_appBar_deleteSiteTooltip,
            onPressed: _confirmDelete,
          ),
      ],
      child: body,
    );
  }

  /// Asks the user to confirm un-sharing an existing shared site.
  /// Returns [true] if confirmed, [false] or [null] to cancel.
  Future<bool?> _showUnshareConfirmDialog(BuildContext ctx) {
    final siteName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_originalSite?.name ?? '');
    return showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(dialogCtx.l10n.sites_unshareConfirm_title),
        content: Text(dialogCtx.l10n.sites_unshareConfirm_body(siteName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(MaterialLocalizations.of(dialogCtx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.l10n.common_action_unshare),
          ),
        ],
      ),
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
      _entryMethod = _entryMethodCandidates[nextIndex].value;
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
      _exitMethod = _exitMethodCandidates[nextIndex].value;
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
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

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

      final minDepthInput = parseUserDecimal(_minDepthController.text);
      final maxDepthInput = parseUserDecimal(_maxDepthController.text);
      final altitudeInput = parseUserDecimal(_altitudeController.text);
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
        entryMethod: _entryMethod,
        exitMethod: _exitMethod,
        isShared: _isShared,
      );

      final notifier = ref.read(siteListNotifierProvider.notifier);
      String savedId;

      MergeSnapshot? mergeSnapshot;

      if (widget.isMerging) {
        final confirmed = await _confirmMerge();
        if (!confirmed) {
          return;
        }

        mergeSnapshot = await notifier.mergeSites(site, widget.mergeSiteIds!);
        savedId = widget.mergeSiteIds!.first;
      } else if (widget.isEditing) {
        await notifier.updateSite(site);
        savedId = widget.siteId!;
      } else {
        final newSite = await notifier.addSite(site);
        savedId = newSite.id;
      }

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
          context.pop(savedId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEditing
                    ? context.l10n.diveSites_edit_snackbar_siteUpdated
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveSites_detail_deleteDialog_title),
        content: Text(context.l10n.diveSites_detail_deleteDialog_content),
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

  Future<void> _deleteSite() async {
    setState(() => _isLoading = true);

    try {
      await ref
          .read(siteListNotifierProvider.notifier)
          .deleteSite(widget.siteId!);
      ref.invalidate(sitesWithCountsProvider);
      ref.invalidate(sitesProvider);

      if (mounted) {
        context.go('/sites');
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
