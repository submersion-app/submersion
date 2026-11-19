import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_country_code.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_merge.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_role_now.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_rules.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/location_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/place_lookup_row.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/place_name_replace_dialog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_picker_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/forms/responsive_form_columns.dart';

part 'site_merge_page_fields.dart';
part 'site_merge_page_candidates.dart';
part 'site_merge_page_location.dart';
part 'site_merge_page_save.dart';

const _mergeLog = LoggerService('SiteMergePage');

/// Merges two or more sites into the first (issue #4527, phase 2, plan 7):
/// each field shows the first site's meaningful value, and cycles through
/// the others'. Types and tags are the sites' union, which the merge
/// writes itself; each site keeps its own sharing. Pops a
/// [SiteMergeResult] once merged, and null on Cancel.
class SiteMergePage extends ConsumerStatefulWidget {
  /// The sites to merge, the survivor first.
  final List<String> siteIds;

  const SiteMergePage({super.key, required this.siteIds});

  @override
  ConsumerState<SiteMergePage> createState() => _SiteMergePageState();
}

class _SiteMergePageState extends ConsumerState<SiteMergePage>
    with
        _SiteMergeFields,
        _SiteMergeCandidates,
        _SiteMergeLocation,
        _SiteMergeSave {
  late final Future<_MergeLoadData> _mergeLoad = _loadMergeData();

  @override
  void initState() {
    super.initState();
    _listenToFields(onCoordinatesChanged: _scheduleAltitudeLookup);
  }

  @override
  void dispose() {
    _altitudeLookupDebounce?.cancel();
    _disposeFields();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);
    final l10n = context.l10n;
    return FutureBuilder<_MergeLoadData>(
      future: _mergeLoad,
      builder: (context, snapshot) {
        Widget page(String title, Widget body) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: body,
        );
        if (snapshot.connectionState != ConnectionState.done) {
          return page(
            l10n.diveSites_edit_appBar_mergeSites,
            const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return page(
            l10n.diveSites_edit_merge_loadingErrorTitle,
            Center(
              child: Text(
                l10n.diveSites_edit_merge_loadingErrorBody('${snapshot.error}'),
              ),
            ),
          );
        }
        final data = snapshot.data;
        // Fewer than two of the sites are still stored: nothing to merge.
        if (data == null || data.sites.length < 2) {
          return page(
            l10n.diveSites_edit_merge_notEnoughTitle,
            Center(child: Text(l10n.diveSites_edit_merge_notEnoughBody)),
          );
        }
        _initializeFromMerge(data, units);
        return _buildForm(context, units);
      },
    );
  }

  Widget _buildForm(BuildContext context, UnitFormatter units) {
    final l10n = context.l10n;
    final allSites = ref.watch(sitesProvider).value ?? const <DiveSite>[];
    // The sites being merged are the duplicates this page resolves: the
    // name's suggestions and its similar-name hint leave them all out.
    final otherSites = [
      for (final site in allSites)
        if (!widget.siteIds.contains(site.id)) site,
    ];
    final body = Form(
      key: _formKey,
      // Identity and Location lead the left column, Dive info, Access and
      // Life the right, on wide windows. Every section is open: a merge
      // shows each field's choice.
      child: ResponsiveFormColumns(
        splitIndex: 2,
        children: [
          IdentitySection(
            allSites: otherSites,
            nameController: _nameController,
            descriptionController: _descriptionController,
            countryController: _countryController,
            regionController: _regionController,
            cityController: _cityController,
            islandController: _islandController,
            bodyOfWaterController: _bodyOfWaterController,
            nameValidator: _nameValidatorFn,
            // Only the first edit rebuilds this page, so the row follows the
            // coordinate fields itself.
            placeLookup: ListenableBuilder(
              listenable: _coordinateChanges,
              builder: (context, _) => PlaceLookupRow(
                isBusy: _isGettingLocation,
                onLookup: _parsedCoordinates() == null
                    ? null
                    : _lookupFromCoordinates,
              ),
            ),
            mergeExtras: _mergeExtras,
          ),
          LocationSection(
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
            units: units,
            coordinatesExtras: _coordinateExtras(),
            altitudeExtras: _mergeExtras('altitude'),
          ),
          DiveInfoSection(
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
            mergeExtras: _mergeExtras,
            difficultyExtras: _difficultyExtras(),
            ratingExtras: _ratingExtras(),
            waterTypeExtras: _waterTypeExtras(),
          ),
          AccessSafetySection(
            accessNotesController: _accessNotesController,
            mooringNumberController: _mooringNumberController,
            parkingInfoController: _parkingInfoController,
            hazardsController: _hazardsController,
            mergeExtras: _mergeExtras,
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
          ),
          LifeNotesSection(
            species: _expectedSpecies,
            onAddSpecies: _showSpeciesPicker,
            onRemoveSpecies: (s) => setState(() {
              _expectedSpecies = _expectedSpecies
                  .where((existing) => existing.id != s.id)
                  .toList();
              _hasChanges = true;
            }),
            notesController: _notesController,
            mergeExtras: _mergeExtras,
          ),
        ],
      ),
    );

    return EditFormScaffold(
      title: l10n.diveSites_edit_appBar_mergeSites,
      embedded: false,
      isSaving: _isLoading,
      hasUnsavedChanges: _hasChanges,
      onSave: _saveMerge,
      headerIcon: Icons.merge_type,
      child: body,
    );
  }

  Future<void> _showSpeciesPicker() async {
    final selectedIds = _expectedSpecies.map((s) => s.id).toSet();
    final repository = ref.read(speciesRepositoryProvider);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => SpeciesPickerDialog(initialSelection: selectedIds),
    );
    if (result == null) return;
    final allSpecies = await repository.getAllSpecies();
    if (!mounted) return;
    setState(() {
      _expectedSpecies = allSpecies
          .where((s) => result.contains(s.id))
          .toList();
      _hasChanges = true;
    });
  }
}
