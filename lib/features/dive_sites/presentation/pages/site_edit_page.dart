import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picker_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class SiteEditPage extends ConsumerStatefulWidget {
  final String? siteId;
  final List<String>? mergeSiteIds;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  const SiteEditPage({
    super.key,
    this.siteId,
    this.mergeSiteIds,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  }) : assert(
         siteId == null || mergeSiteIds == null,
         'siteId and mergeSiteIds are mutually exclusive',
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
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;
  bool _isApplyingInitialValues = false;
  DiveSite? _originalSite;
  List<Species> _expectedSpecies = [];
  Set<String> _originalExpectedSpeciesIds = {};
  late final Future<_MergeLoadData>? _mergeLoadFuture;
  final Map<String, List<_MergeFieldCandidate<String>>> _mergeTextCandidates =
      {};
  final Map<String, int> _mergeFieldIndices = {};
  List<_MergeFieldCandidate<SiteDifficulty?>> _difficultyCandidates = [];
  List<_MergeFieldCandidate<double>> _ratingCandidates = [];
  List<_MergeFieldCandidate<_CoordinateCandidate>> _coordinateCandidates = [];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _countryController.addListener(_onFieldChanged);
    _regionController.addListener(_onFieldChanged);
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
    _mergeLoadFuture = widget.isMerging ? _loadMergeData() : null;
  }

  void _onFieldChanged() {
    if (_isApplyingInitialValues) return;
    if (!_hasChanges && _isInitialized) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    _regionController.dispose();
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
    _minDepthController.text = site.minDepth != null
        ? units.convertDepth(site.minDepth!).toStringAsFixed(1)
        : '';
    _maxDepthController.text = site.maxDepth != null
        ? units.convertDepth(site.maxDepth!).toStringAsFixed(1)
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
    _altitudeController.text = site.altitude != null
        ? units.convertAltitude(site.altitude!).toStringAsFixed(0)
        : '';
    _isApplyingInitialValues = false;

    // Load expected species
    _loadExpectedSpecies(site.id);
  }

  void _initializeFromMerge(_MergeLoadData data, UnitFormatter units) {
    if (_isInitialized) return;
    _isInitialized = true;
    _originalSite = data.sites.first;
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
      key: 'minDepth',
      controller: _minDepthController,
      sites: data.sites,
      getValue: (site) => site.minDepth != null
          ? units.convertDepth(site.minDepth!).toStringAsFixed(1)
          : '',
      isMeaningful: (value) => value.trim().isNotEmpty,
    );
    _initializeMergeTextField(
      key: 'maxDepth',
      controller: _maxDepthController,
      sites: data.sites,
      getValue: (site) => site.maxDepth != null
          ? units.convertDepth(site.maxDepth!).toStringAsFixed(1)
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
          ? units.convertAltitude(site.altitude!).toStringAsFixed(0)
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
    }

    return _buildForm(context, units);
  }

  Widget _buildForm(BuildContext context, UnitFormatter units) {
    final body = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name
          TextFormField(
            controller: _nameController,
            decoration: _withMergeTextDecoration(
              key: 'name',
              decoration: InputDecoration(
                labelText: context.l10n.diveSites_edit_field_siteName_label,
                prefixIcon: const Icon(Icons.location_on),
                hintText: context.l10n.diveSites_edit_field_siteName_hint,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.diveSites_edit_field_siteName_validation;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: _withMergeTextDecoration(
              key: 'description',
              decoration: InputDecoration(
                labelText: context.l10n.diveSites_edit_field_description_label,
                prefixIcon: const Icon(Icons.description),
                hintText: context.l10n.diveSites_edit_field_description_hint,
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Country & Region
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _countryController,
                  decoration: _withMergeTextDecoration(
                    key: 'country',
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.diveSites_edit_field_country_label,
                      prefixIcon: const Icon(Icons.flag),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _regionController,
                  decoration: _withMergeTextDecoration(
                    key: 'region',
                    decoration: InputDecoration(
                      labelText: context.l10n.diveSites_edit_field_region_label,
                      prefixIcon: const Icon(Icons.map),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Depth Section
          _buildDepthSection(context, units),
          const SizedBox(height: 16),

          // Difficulty
          _buildDifficultySection(context),
          const SizedBox(height: 16),

          // Rating
          _buildRatingSection(context),
          const SizedBox(height: 16),

          // GPS Coordinates
          _buildGpsSection(context),
          const SizedBox(height: 16),

          // Altitude (for altitude diving)
          _buildAltitudeSection(context, units),
          const SizedBox(height: 16),

          // Access & Logistics Section
          _buildAccessSection(context),
          const SizedBox(height: 16),

          // Safety Section
          _buildSafetySection(context),
          const SizedBox(height: 16),

          // Expected Marine Life Section
          _buildExpectedMarineLifeSection(context),
          const SizedBox(height: 16),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: _withMergeTextDecoration(
              key: 'notes',
              decoration: InputDecoration(
                labelText: context.l10n.diveSites_edit_field_notes_label,
                prefixIcon: const Icon(Icons.notes),
                hintText: context.l10n.diveSites_edit_field_notes_hint,
              ),
            ),
            maxLines: 4,
          ),

          if (!widget.embedded) ...[
            const SizedBox(height: 32),
            // Save Button
            FilledButton(
              onPressed: _isLoading ? null : _saveSite,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.isMerging
                          ? context.l10n.diveSites_edit_button_mergeSites
                          : widget.isEditing
                          ? context.l10n.diveSites_edit_button_saveChanges
                          : context.l10n.diveSites_edit_button_addSite,
                    ),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return PopScope(
        canPop: !_hasChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && _hasChanges) {
            final shouldPop = await _showDiscardDialog();
            if (shouldPop == true && mounted) {
              _handleCancel();
            }
          }
        },
        child: Column(
          children: [
            _buildEmbeddedHeader(context),
            Expanded(child: body),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop == true && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? context.l10n.diveSites_edit_appBar_editSite
                : widget.isMerging
                ? context.l10n.diveSites_edit_appBar_mergeSites
                : context.l10n.diveSites_edit_appBar_newSite,
          ),
          actions: [
            if (widget.isEditing)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: context.l10n.diveSites_edit_appBar_deleteSiteTooltip,
                onPressed: _confirmDelete,
              ),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _saveSite,
                child: Text(
                  widget.isMerging
                      ? context.l10n.diveSites_edit_appBar_merge
                      : context.l10n.diveSites_edit_appBar_save,
                ),
              ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              widget.isEditing
                  ? Icons.edit
                  : widget.isMerging
                  ? Icons.merge_type
                  : Icons.add_location,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isEditing
                  ? context.l10n.diveSites_edit_appBar_editSite
                  : widget.isMerging
                  ? context.l10n.diveSites_edit_appBar_mergeSites
                  : context.l10n.diveSites_edit_appBar_newSite,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_hasChanges) {
                final discard = await _showDiscardDialog();
                if (discard == true && mounted) {
                  _handleCancel();
                }
              } else {
                _handleCancel();
              }
            },
            child: Text(context.l10n.diveSites_edit_cancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isLoading ? null : _saveSite,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.isMerging
                        ? context.l10n.diveSites_edit_appBar_merge
                        : context.l10n.diveSites_edit_appBar_save,
                  ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveSites_edit_discardDialog_title),
        content: Text(context.l10n.diveSites_edit_discardDialog_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.diveSites_edit_discardDialog_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.diveSites_edit_discardDialog_discard),
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

  Widget _buildMergeCycleButton(VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: context.l10n.diveSites_edit_merge_fieldSourceCycleTooltip,
      icon: const Icon(Icons.sync_alt, size: 18),
      iconSize: 18,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  InputDecoration _withMergeTextDecoration({
    required String key,
    required InputDecoration decoration,
  }) {
    final candidates = _mergeTextCandidates[key];
    if (!widget.isMerging || candidates == null || candidates.length < 2) {
      return decoration;
    }

    final currentIndex = _mergeFieldIndices[key] ?? 0;
    final current = candidates[currentIndex];

    return decoration.copyWith(
      helperText: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        current.siteName,
        currentIndex + 1,
        candidates.length,
      ),
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _buildMergeCycleButton(() => _cycleTextField(key)),
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 36),
    );
  }

  void _selectTextFieldCandidate(String key, int index) {
    final candidates = _mergeTextCandidates[key];
    if (candidates == null || index < 0 || index >= candidates.length) return;

    final controller = switch (key) {
      'name' => _nameController,
      'description' => _descriptionController,
      'country' => _countryController,
      'region' => _regionController,
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

  String? _mergeSectionSourceLabel(String key, int length, String siteName) {
    if (!widget.isMerging || length < 2) return null;
    final index = _mergeFieldIndices[key] ?? 0;
    return context.l10n.diveSites_edit_merge_fieldSourceLabel(
      siteName,
      index + 1,
      length,
    );
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

  Widget _buildRatingSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.diveSites_edit_section_rating,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.isMerging && _ratingCandidates.length > 1) ...[
                  const Spacer(),
                  _buildMergeCycleButton(_cycleRating),
                ],
              ],
            ),
            if (widget.isMerging && _ratingCandidates.length > 1)
              Text(
                _mergeSectionSourceLabel(
                      'rating',
                      _ratingCandidates.length,
                      _ratingCandidates[_mergeFieldIndices['rating'] ?? 0]
                          .siteName,
                    ) ??
                    '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  tooltip: context.l10n.diveSites_edit_rating_starTooltip(
                    index + 1,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                      _hasChanges = true;
                    });
                  },
                );
              }),
            ),
            if (_rating > 0)
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _rating = 0;
                    _hasChanges = true;
                  }),
                  child: Text(context.l10n.diveSites_edit_rating_clear),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepthSection(BuildContext context, UnitFormatter units) {
    final depthSymbol = units.depthSymbol;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.arrow_downward),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_edit_section_depthRange,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveSites_edit_depth_helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minDepthController,
                    decoration: _withMergeTextDecoration(
                      key: 'minDepth',
                      decoration: InputDecoration(
                        labelText: context.l10n.diveSites_edit_depth_minLabel(
                          depthSymbol,
                        ),
                        hintText: context.l10n.diveSites_edit_depth_minHint,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(context.l10n.diveSites_edit_depth_separator),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _maxDepthController,
                    decoration: _withMergeTextDecoration(
                      key: 'maxDepth',
                      decoration: InputDecoration(
                        labelText: context.l10n.diveSites_edit_depth_maxLabel(
                          depthSymbol,
                        ),
                        hintText: context.l10n.diveSites_edit_depth_maxHint,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_edit_section_difficultyLevel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.isMerging && _difficultyCandidates.length > 1) ...[
                  const Spacer(),
                  _buildMergeCycleButton(_cycleDifficulty),
                ],
              ],
            ),
            if (widget.isMerging && _difficultyCandidates.length > 1)
              Text(
                _mergeSectionSourceLabel(
                      'difficulty',
                      _difficultyCandidates.length,
                      _difficultyCandidates[_mergeFieldIndices['difficulty'] ??
                              0]
                          .siteName,
                    ) ??
                    '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SiteDifficulty.values.map((difficulty) {
                final isSelected = _difficulty == difficulty;
                return ChoiceChip(
                  label: Text(difficulty.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _difficulty = selected ? difficulty : null;
                      _hasChanges = true;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  bool _isGettingLocation = false;

  Future<void> _useMyLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final locationService = LocationService.instance;
      final result = await locationService.getCurrentLocation(
        includeGeocoding: true,
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

        if (_countryController.text.isEmpty && result.country != null) {
          _countryController.text = result.country!;
        }
        if (_regionController.text.isEmpty && result.region != null) {
          _regionController.text = result.region!;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.accuracy != null
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

        if (_countryController.text.isEmpty && result.country != null) {
          _countryController.text = result.country!;
        }
        if (_regionController.text.isEmpty && result.region != null) {
          _regionController.text = result.region!;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveSites_edit_snackbar_locationSelectedFromMap,
          ),
        ),
      );
    }
  }

  Widget _buildGpsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_edit_section_gpsCoordinates,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.isMerging && _coordinateCandidates.length > 1) ...[
                  const Spacer(),
                  _buildMergeCycleButton(_cycleCoordinates),
                ],
              ],
            ),
            if (widget.isMerging && _coordinateCandidates.length > 1)
              Text(
                _mergeSectionSourceLabel(
                      'coordinates',
                      _coordinateCandidates.length,
                      _coordinateCandidates[_mergeFieldIndices['coordinates'] ??
                              0]
                          .siteName,
                    ) ??
                    '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveSites_edit_gps_helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isGettingLocation ? null : _useMyLocation,
                  icon: _isGettingLocation
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(
                    _isGettingLocation
                        ? context.l10n.diveSites_edit_gps_gettingLocation
                        : context.l10n.diveSites_edit_gps_useMyLocation,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFromMap,
                  icon: const Icon(Icons.map, size: 18),
                  label: Text(context.l10n.diveSites_edit_gps_pickFromMap),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveSites_edit_gps_latitude_label,
                      hintText: context.l10n.diveSites_edit_gps_latitude_hint,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return context
                              .l10n
                              .diveSites_edit_gps_latitude_validation;
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.diveSites_edit_gps_longitude_label,
                      hintText: context.l10n.diveSites_edit_gps_longitude_hint,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final lng = double.tryParse(value);
                        if (lng == null || lng < -180 || lng > 180) {
                          return context
                              .l10n
                              .diveSites_edit_gps_longitude_validation;
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAltitudeSection(BuildContext context, UnitFormatter units) {
    final colorScheme = Theme.of(context).colorScheme;
    final altitudeSymbol = units.altitudeSymbol;

    // Parse current altitude to show group indicator
    final altitudeInput = double.tryParse(_altitudeController.text);
    final altitudeMeters = altitudeInput != null
        ? units.altitudeToMeters(altitudeInput)
        : null;
    final altitudeGroup = AltitudeGroup.fromAltitude(altitudeMeters);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terrain),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_edit_section_altitude,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveSites_edit_altitude_helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _altitudeController,
              decoration: _withMergeTextDecoration(
                key: 'altitude',
                decoration: InputDecoration(
                  labelText: context.l10n.diveSites_edit_altitude_label(
                    altitudeSymbol,
                  ),
                  hintText: context.l10n.diveSites_edit_altitude_hint,
                  prefixIcon: const Icon(Icons.terrain),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final altitude = double.tryParse(value);
                  if (altitude == null || altitude < 0) {
                    return context.l10n.diveSites_edit_altitude_validation;
                  }
                }
                return null;
              },
            ),
            if (altitudeGroup != AltitudeGroup.seaLevel &&
                altitudeMeters != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildAltitudeGroupIndicator(context, altitudeGroup),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAltitudeGroupIndicator(
    BuildContext context,
    AltitudeGroup group,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color foregroundColor;
    IconData icon;

    switch (group.warningLevel) {
      case AltitudeWarningLevel.none:
        backgroundColor = colorScheme.surfaceContainerHighest;
        foregroundColor = colorScheme.onSurface;
        icon = Icons.check_circle_outline;
      case AltitudeWarningLevel.info:
        backgroundColor = colorScheme.primaryContainer;
        foregroundColor = colorScheme.onPrimaryContainer;
        icon = Icons.info_outline;
      case AltitudeWarningLevel.caution:
        backgroundColor = colorScheme.tertiaryContainer;
        foregroundColor = colorScheme.onTertiaryContainer;
        icon = Icons.warning_amber;
      case AltitudeWarningLevel.warning:
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;
        icon = Icons.warning;
      case AltitudeWarningLevel.severe:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        icon = Icons.dangerous;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.displayName,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  group.rangeDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_edit_section_access,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accessNotesController,
              decoration: _withMergeTextDecoration(
                key: 'accessNotes',
                decoration: InputDecoration(
                  labelText:
                      context.l10n.diveSites_edit_access_accessNotes_label,
                  hintText: context.l10n.diveSites_edit_access_accessNotes_hint,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mooringNumberController,
                    decoration: _withMergeTextDecoration(
                      key: 'mooringNumber',
                      decoration: InputDecoration(
                        labelText: context
                            .l10n
                            .diveSites_edit_access_mooringNumber_label,
                        hintText: context
                            .l10n
                            .diveSites_edit_access_mooringNumber_hint,
                        prefixIcon: const Icon(Icons.anchor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _parkingInfoController,
              decoration: _withMergeTextDecoration(
                key: 'parkingInfo',
                decoration: InputDecoration(
                  labelText:
                      context.l10n.diveSites_edit_access_parkingInfo_label,
                  hintText: context.l10n.diveSites_edit_access_parkingInfo_hint,
                  prefixIcon: const Icon(Icons.local_parking),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveSites_edit_section_hazards,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveSites_edit_hazards_helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hazardsController,
              decoration: _withMergeTextDecoration(
                key: 'hazards',
                decoration: InputDecoration(
                  labelText: context.l10n.diveSites_edit_hazards_label,
                  hintText: context.l10n.diveSites_edit_hazards_hint,
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpectedMarineLifeSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.diveSites_edit_section_expectedMarineLife,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showSpeciesPicker,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.diveSites_edit_marineLife_addButton),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.isMerging
                  ? context.l10n.diveSites_edit_merge_marineLifeHelperText
                  : context.l10n.diveSites_edit_marineLife_helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_expectedSpecies.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _expectedSpecies.map((species) {
                  return Chip(
                    avatar: Icon(
                      Icons.pets,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    label: Text(species.commonName),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _expectedSpecies = _expectedSpecies
                            .where((s) => s.id != species.id)
                            .toList();
                        _hasChanges = true;
                      });
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  context.l10n.diveSites_edit_marineLife_empty,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

      final minDepthInput = double.tryParse(_minDepthController.text);
      final maxDepthInput = double.tryParse(_maxDepthController.text);
      final altitudeInput = double.tryParse(_altitudeController.text);
      final minDepthMeters = minDepthInput != null
          ? units.depthToMeters(minDepthInput)
          : null;
      final maxDepthMeters = maxDepthInput != null
          ? units.depthToMeters(maxDepthInput)
          : null;
      final altitudeMeters = altitudeInput != null
          ? units.altitudeToMeters(altitudeInput)
          : null;

      String? country = _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim();
      String? region = _regionController.text.trim().isEmpty
          ? null
          : _regionController.text.trim();

      if (location != null && (country == null || region == null)) {
        try {
          final geocodeResult = await LocationService.instance.reverseGeocode(
            location.latitude,
            location.longitude,
          );
          if (country == null && geocodeResult.country != null) {
            country = geocodeResult.country;
          }
          if (region == null && geocodeResult.region != null) {
            region = geocodeResult.region;
          }
        } catch (e) {
          // Geocoding is best-effort
        }
      }

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
