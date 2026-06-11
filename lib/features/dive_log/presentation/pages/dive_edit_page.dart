import 'package:flutter/material.dart' hide Visibility;
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_picker.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/outlier_suggestion_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/custom_field_input_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/tank_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/computer_source_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ccr_settings_panel.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_selector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/scr_settings_panel.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_picker.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/photo_gps_suggestion_banner.dart';
import 'package:submersion/features/media/presentation/widgets/quick_site_from_gps_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

const _createNewSiteSentinel = '__create_new__';
const _createNewDiveCenterSentinel = '__create_new_dive_center__';
const _createNewTripSentinel = '__create_new_trip__';

class DiveEditPage extends ConsumerStatefulWidget {
  final String? diveId;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Callback when save completes (used in embedded mode).
  final void Function(String savedId)? onSaved;

  /// Callback when user cancels editing (used in embedded mode).
  final VoidCallback? onCancel;

  const DiveEditPage({
    super.key,
    this.diveId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  });

  bool get isEditing => diveId != null;

  @override
  ConsumerState<DiveEditPage> createState() => _DiveEditPageState();
}

class _DiveEditPageState extends ConsumerState<DiveEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // Form controllers - Entry/Exit times
  late DateTime _entryDate;
  late TimeOfDay _entryTime;
  DateTime? _exitDate;
  TimeOfDay? _exitTime;
  final _diveNumberController = TextEditingController();
  final _durationController = TextEditingController();
  final _runtimeController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _avgDepthController = TextEditingController();
  final _waterTempController = TextEditingController();
  final _airTempController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedDiveTypeId = 'recreational';
  Visibility _selectedVisibility = Visibility.unknown;
  int _rating = 0;
  DiveSite? _selectedSite;
  Trip? _selectedTrip;
  DiveCenter? _selectedDiveCenter;
  Course? _selectedCourse;
  List<Sighting> _sightings = [];
  Set<String> _originalSightingIds =
      {}; // Track original IDs to detect deletions
  List<EquipmentItem> _selectedEquipment = [];
  List<BuddyWithRole> _selectedBuddies = [];
  Set<String> _originalBuddyIds = {};

  // Conditions fields
  CurrentDirection? _currentDirection;
  CurrentStrength? _currentStrength;
  EntryMethod? _entryMethod;
  EntryMethod? _exitMethod;
  WaterType? _waterType;
  final _swellHeightController = TextEditingController();
  final _altitudeController = TextEditingController();
  final _surfacePressureController = TextEditingController();

  // Weather fields
  CurrentDirection? _windDirection;
  CloudCover? _cloudCover;
  Precipitation? _precipitation;
  WeatherSource? _weatherSource;
  DateTime? _weatherFetchedAt;
  final _windSpeedController = TextEditingController();
  final _humidityController = TextEditingController();
  final _weatherDescriptionController = TextEditingController();
  bool _isFetchingWeather = false;

  // Weight fields - multiple weight entries per dive
  List<DiveWeight> _weights = [];

  // Tank data - list of tanks with multi-tank support
  List<DiveTank> _tanks = [];
  final _uuid = const Uuid();
  TankPresetEntity? _defaultPreset;
  bool _tanksDirty = false;

  // Tags
  List<Tag> _selectedTags = [];

  // Custom fields
  List<DiveCustomField> _customFields = [];

  // Dive mode and rebreather settings
  DiveMode _diveMode = DiveMode.oc;
  // CCR settings
  double? _setpointLow;
  double? _setpointHigh;
  double? _setpointDeco;
  GasMix? _diluentGas;
  String? _scrubberType;
  int? _scrubberDurationMinutes;
  int? _scrubberRemainingMinutes;
  double? _loopVolume;
  // SCR settings
  ScrType? _scrType;
  double? _scrInjectionRate;
  double? _scrAdditionRatio;
  String? _scrOrificeSize;
  GasMix? _scrSupplyGas;
  double? _assumedVo2;
  double? _loopO2Min;
  double? _loopO2Max;
  double? _loopO2Avg;

  // Existing dive for editing
  Dive? _existingDive;

  // Current device location (for new dives - to suggest nearby sites)
  LocationResult? _currentLocation;
  bool _isCapturingLocation = false;

  // GPS suggestion from photos
  bool _gpsSuggestionDismissed = false;

  /// Smart-collapse expansion state, keyed by group. Defaults are computed
  /// at the call sites (new dive vs editing); user toggles override them
  /// for the lifetime of the page.
  final Map<String, bool> _expanded = {};

  bool _isExpanded(String key, {required bool defaultValue}) =>
      _expanded[key] ?? defaultValue;

  void _toggleSection(String key, {required bool defaultValue}) {
    setState(
      () => _expanded[key] = !_isExpanded(key, defaultValue: defaultValue),
    );
  }

  @override
  void initState() {
    super.initState();
    _entryDate = DateTime.now();
    _entryTime = TimeOfDay.now();

    // Eagerly resolve built-in presets (sync), async for custom
    _loadDefaultPreset();

    final settings = ref.read(settingsProvider);
    _tanks = [
      DiveTank(
        id: _uuid.v4(),
        volume: _defaultPreset?.volumeLiters ?? settings.defaultTankVolume,
        workingPressure: _defaultPreset?.workingPressureBar,
        startPressure: settings.defaultStartPressure.toDouble(),
        endPressure: 50.0,
        gasMix: const GasMix(),
        role: TankRole.backGas,
        material: _defaultPreset?.material,
        order: 0,
        presetName: _defaultPreset?.name,
      ),
    ];

    if (widget.isEditing) {
      _loadExistingDive();
    } else {
      // For new dives, capture GPS in the background to suggest nearby sites
      _captureLocationForNearby();
      _suggestNextDiveNumber();
    }
  }

  Future<void> _loadDefaultPreset() async {
    final settings = ref.read(settingsProvider);
    final presetName = settings.defaultTankPreset;

    // Try synchronous built-in resolution first
    final builtIn = presetName != null ? TankPresets.byName(presetName) : null;
    if (builtIn != null) {
      _defaultPreset = TankPresetEntity.fromBuiltIn(builtIn);
      return;
    }

    // Async fallback for custom presets
    if (presetName != null) {
      final repository = ref.read(tankPresetRepositoryProvider);
      final resolver = DefaultTankPresetResolver(repository: repository);
      final preset = await resolver.resolve(presetName);
      if (mounted) {
        setState(() {
          _defaultPreset = preset;
          // Apply preset to initial tank if the user hasn't edited tanks yet
          // and this is a new dive (not editing an existing one)
          if (!_tanksDirty &&
              !widget.isEditing &&
              preset != null &&
              _tanks.length == 1) {
            final existing = _tanks[0];
            _tanks = [
              DiveTank(
                id: existing.id,
                volume: preset.volumeLiters,
                workingPressure: preset.workingPressureBar,
                startPressure: existing.startPressure,
                endPressure: existing.endPressure,
                gasMix: existing.gasMix,
                role: existing.role,
                material: preset.material,
                order: existing.order,
                presetName: preset.name,
              ),
            ];
          }
        });
      }
    }
  }

  Future<void> _suggestNextDiveNumber() async {
    try {
      final repository = ref.read(diveRepositoryProvider);
      final nextNumber = await repository.getNextDiveNumber();
      if (mounted && _diveNumberController.text.isEmpty) {
        setState(() {
          _diveNumberController.text = nextNumber.toString();
        });
      }
    } catch (_) {
      // Non-critical — field remains blank, auto-assigned on save
    }
  }

  Future<void> _loadExistingDive() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(diveRepositoryProvider);
      final dive = await repository.getDiveById(widget.diveId!);
      if (dive != null && mounted) {
        // Get unit formatter to convert from stored metric to user's preferred units
        final settings = ref.read(settingsProvider);
        final units = UnitFormatter(settings);

        // Load training course if linked (must be done before setState)
        Course? loadedCourse;
        if (dive.courseId != null) {
          loadedCourse = await ref.read(
            courseByIdProvider(dive.courseId!).future,
          );
        }

        setState(() {
          _existingDive = dive;
          _diveNumberController.text = dive.diveNumber?.toString() ?? '';
          // Use entryTime if available, otherwise fall back to dateTime
          final entryDateTime = dive.entryTime ?? dive.dateTime;
          _entryDate = entryDateTime;
          _entryTime = TimeOfDay.fromDateTime(entryDateTime);
          // Set exit time if available
          if (dive.exitTime != null) {
            _exitDate = dive.exitTime;
            _exitTime = TimeOfDay.fromDateTime(dive.exitTime!);
          } else if (dive.bottomTime != null) {
            // Calculate exit time from entry + bottomTime
            final exitDateTime = entryDateTime.add(dive.bottomTime!);
            _exitDate = exitDateTime;
            _exitTime = TimeOfDay.fromDateTime(exitDateTime);
          }
          // Bottom time (stored bottomTime, or auto-calculated from profile)
          if (dive.bottomTime != null) {
            _durationController.text = dive.bottomTime!.inMinutes.toString();
          } else if (dive.profile.isNotEmpty) {
            // Auto-calculate from profile if no stored duration
            final calculatedBottomTime = dive.calculateBottomTimeFromProfile();
            if (calculatedBottomTime != null) {
              _durationController.text = calculatedBottomTime.inMinutes
                  .toString();
            }
          }
          // Runtime: use stored value, or calculate from entry/exit times
          if (dive.runtime != null) {
            _runtimeController.text = dive.runtime!.inMinutes.toString();
          } else if (dive.entryTime != null && dive.exitTime != null) {
            final calculatedRuntime = dive.exitTime!.difference(
              dive.entryTime!,
            );
            _runtimeController.text = calculatedRuntime.inMinutes.toString();
          }
          // Convert stored metric values to user's preferred units
          _maxDepthController.text = dive.maxDepth != null
              ? units.convertDepth(dive.maxDepth!).toStringAsFixed(1)
              : '';
          _avgDepthController.text = dive.avgDepth != null
              ? units.convertDepth(dive.avgDepth!).toStringAsFixed(1)
              : '';
          _waterTempController.text = dive.waterTemp != null
              ? units.convertTemperature(dive.waterTemp!).toStringAsFixed(0)
              : '';
          _airTempController.text = dive.airTemp != null
              ? units.convertTemperature(dive.airTemp!).toStringAsFixed(0)
              : '';
          _notesController.text = dive.notes;
          _selectedDiveTypeId = dive.diveTypeId;
          _selectedVisibility = dive.visibility ?? Visibility.unknown;
          _rating = dive.rating ?? 0;
          _selectedSite = dive.site;
          _selectedTrip = dive.trip;
          _selectedDiveCenter = dive.diveCenter;
          _selectedCourse = loadedCourse;

          // Load all tanks from the dive
          if (dive.tanks.isNotEmpty) {
            _tanks = List.from(dive.tanks);
            _tanksDirty = true;
          }

          // Load equipment
          _selectedEquipment = List.from(dive.equipment);

          // Load conditions fields
          _currentDirection = dive.currentDirection;
          _currentStrength = dive.currentStrength;
          _entryMethod = dive.entryMethod;
          _exitMethod = dive.exitMethod;
          _waterType = dive.waterType;
          _swellHeightController.text = dive.swellHeight != null
              ? units.convertDepth(dive.swellHeight!).toStringAsFixed(1)
              : '';
          _altitudeController.text = dive.altitude != null
              ? units.convertAltitude(dive.altitude!).toStringAsFixed(0)
              : '';
          _surfacePressureController.text = dive.surfacePressure != null
              ? (dive.surfacePressure! * 1000).toStringAsFixed(
                  0,
                ) // Convert bar to mbar
              : '';

          // Load weather fields
          _windDirection = dive.windDirection;
          _cloudCover = dive.cloudCover;
          _precipitation = dive.precipitation;
          _weatherSource = dive.weatherSource;
          _weatherFetchedAt = dive.weatherFetchedAt;
          _windSpeedController.text = dive.windSpeed != null
              ? units.convertWindSpeed(dive.windSpeed!).toStringAsFixed(1)
              : '';
          _humidityController.text = dive.humidity != null
              ? dive.humidity!.toStringAsFixed(0)
              : '';
          _weatherDescriptionController.text = dive.weatherDescription ?? '';

          // Load weight entries (weights already stored in kg, conversion happens in display)
          _weights = List.from(dive.weights);
          // Migrate legacy single weight to weights list if needed
          if (_weights.isEmpty &&
              dive.weightAmount != null &&
              dive.weightAmount! > 0) {
            _weights.add(
              DiveWeight(
                id: _uuid.v4(),
                diveId: dive.id,
                weightType: dive.weightType ?? WeightType.belt,
                amountKg: dive.weightAmount!,
              ),
            );
          }

          // Load tags
          _selectedTags = List.from(dive.tags);

          // Load custom fields
          _customFields = List.from(dive.customFields);

          // Load CCR/SCR rebreather settings
          _diveMode = dive.diveMode;
          _setpointLow = dive.setpointLow;
          _setpointHigh = dive.setpointHigh;
          _setpointDeco = dive.setpointDeco;
          _diluentGas = dive.diluentGas;
          _scrubberType = dive.scrubber?.type;
          _scrubberDurationMinutes = dive.scrubber?.ratedMinutes;
          _scrubberRemainingMinutes = dive.scrubber?.remainingMinutes;
          _loopVolume = dive.loopVolume;
          _scrType = dive.scrType;
          _scrInjectionRate = dive.scrInjectionRate;
          _scrAdditionRatio = dive.scrAdditionRatio;
          _scrOrificeSize = dive.scrOrificeSize;
          _scrSupplyGas =
              dive.diluentGas; // SCR uses diluent field for supply gas
          _assumedVo2 = dive.assumedVo2;
          _loopO2Min = dive.loopO2Min;
          _loopO2Max = dive.loopO2Max;
          _loopO2Avg = dive.loopO2Avg;
        });
        // Load existing sightings and buddies
        _loadSightings();
        _loadBuddies();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Capture device GPS in background for suggesting nearby sites
  Future<void> _captureLocationForNearby() async {
    setState(() => _isCapturingLocation = true);
    try {
      final location = await LocationService.instance.getCurrentLocation(
        includeGeocoding:
            false, // We just need coordinates for distance calculation
        timeout: const Duration(seconds: 10),
      );
      if (mounted && location != null) {
        setState(() => _currentLocation = location);
      }
    } catch (e) {
      // Silently fail - GPS is optional for nearby suggestions
    } finally {
      if (mounted) {
        setState(() => _isCapturingLocation = false);
      }
    }
  }

  Future<void> _loadSightings() async {
    if (widget.diveId == null) return;
    final repository = ref.read(speciesRepositoryProvider);
    final sightings = await repository.getSightingsForDive(widget.diveId!);
    if (mounted) {
      setState(() {
        _sightings = sightings;
        _originalSightingIds = sightings.map((s) => s.id).toSet();
      });
    }
  }

  Future<void> _loadBuddies() async {
    if (widget.diveId == null) return;
    final repository = ref.read(buddyRepositoryProvider);
    final buddies = await repository.getBuddiesForDive(widget.diveId!);
    if (mounted) {
      setState(() {
        _selectedBuddies = buddies;
        _originalBuddyIds = buddies.map((b) => b.buddy.id).toSet();
      });
    }
  }

  @override
  void dispose() {
    _diveNumberController.dispose();
    _durationController.dispose();
    _runtimeController.dispose();
    _maxDepthController.dispose();
    _avgDepthController.dispose();
    _waterTempController.dispose();
    _airTempController.dispose();
    _notesController.dispose();
    _swellHeightController.dispose();
    _altitudeController.dispose();
    _surfacePressureController.dispose();
    _windSpeedController.dispose();
    _humidityController.dispose();
    _weatherDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    if (_isLoading) {
      if (widget.embedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? context.l10n.diveLog_edit_appBarEdit
                : context.l10n.diveLog_edit_appBarNew,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final formBody = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTheDiveSection(units),
          const SizedBox(height: FormStyle.sectionGap),
          _buildGasGearSection(units),
          const SizedBox(height: FormStyle.sectionGap),
          _buildTripSection(),
          const SizedBox(height: 16),
          _buildDiveCenterSection(),
          const SizedBox(height: 16),
          _buildEnvironmentSection(units),
          const SizedBox(height: 16),
          _buildBuddySection(),
          const SizedBox(height: 16),
          _buildRatingSection(),
          const SizedBox(height: 16),
          _buildSightingsSection(),
          const SizedBox(height: 16),
          _buildNotesSection(),
          const SizedBox(height: 16),
          _buildCourseSection(),
          const SizedBox(height: 16),
          _buildTagsSection(),
          const SizedBox(height: 16),
          _buildCustomFieldsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );

    // Embedded mode: Return content with a compact header bar (no Scaffold)
    if (widget.embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, units),
          Expanded(child: formBody),
        ],
      );
    }

    // Standalone mode: Full Scaffold with AppBar
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? context.l10n.diveLog_edit_appBarEdit
              : context.l10n.diveLog_edit_appBarNew,
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: () => _saveDive(units),
                  child: Text(context.l10n.diveLog_edit_save),
                ),
        ],
      ),
      body: formBody,
    );
  }

  /// Compact header bar for embedded mode in master-detail layout.
  Widget _buildEmbeddedHeader(BuildContext context, UnitFormatter units) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.isEditing
        ? context.l10n.diveLog_edit_appBarEdit
        : context.l10n.diveLog_edit_headerNew;

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
          // Icon
          Icon(
            widget.isEditing ? Icons.edit : Icons.add_circle_outline,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          // Cancel button
          TextButton(
            onPressed: widget.onCancel,
            child: Text(context.l10n.diveLog_edit_cancel),
          ),
          const SizedBox(width: 8),
          // Save button
          _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton(
                  onPressed: () => _saveDive(units),
                  child: Text(context.l10n.diveLog_edit_save),
                ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_section_tags,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TagInputWidget(
              selectedTags: _selectedTags,
              onTagsChanged: (tags) {
                setState(() => _selectedTags = tags);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldsSection() {
    final currentDiverId = ref.watch(currentDiverIdProvider);
    final suggestions = currentDiverId != null
        ? ref
                  .watch(customFieldKeySuggestionsProvider(currentDiverId))
                  .valueOrNull ??
              []
        : <String>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_section_customFields,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_customFields.isNotEmpty) const Divider(),
            if (_customFields.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _customFields.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _customFields.removeAt(oldIndex);
                    _customFields.insert(newIndex, item);
                    for (var i = 0; i < _customFields.length; i++) {
                      _customFields[i] = _customFields[i].copyWith(
                        sortOrder: i,
                      );
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final field = _customFields[index];
                  return CustomFieldInputRow(
                    key: ValueKey(field.id),
                    index: index,
                    field: field,
                    keySuggestions: suggestions,
                    onChanged: (updated) {
                      setState(() {
                        _customFields[index] = updated;
                      });
                    },
                    onDelete: () {
                      setState(() {
                        _customFields.removeAt(index);
                      });
                    },
                  );
                },
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _customFields.add(
                    DiveCustomField(
                      id: _uuid.v4(),
                      key: '',
                      value: '',
                      sortOrder: _customFields.length,
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.diveLog_edit_addCustomField),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTheDiveSection(UnitFormatter units) {
    final hasProfile = _existingDive?.profile.isNotEmpty == true;
    return TheDiveSection(
      depthSymbol: units.depthSymbol,
      maxDepthController: _maxDepthController,
      avgDepthController: _avgDepthController,
      bottomTimeController: _durationController,
      runtimeController: _runtimeController,
      diveNumberController: _diveNumberController,
      entryText: _formatEntryText(units),
      onEditEntry: _editEntry,
      exitText: _formatExitText(units),
      onEditExit: _editExit,
      siteName: _selectedSite?.name,
      onPickSite: _showSitePicker,
      onClearSite: () => setState(() => _selectedSite = null),
      maxDepthSuggestion: hasProfile
          ? _depthSuggestion(
              units,
              _existingDive!.calculateMaxDepthFromProfile(),
              () => _calculateMaxDepthFromProfile(units),
            )
          : null,
      avgDepthSuggestion: hasProfile
          ? _depthSuggestion(
              units,
              _existingDive!.calculateAvgDepthFromProfile(),
              () => _calculateAvgDepthFromProfile(units),
            )
          : null,
      bottomTimeSuggestion: hasProfile
          ? _minutesSuggestion(
              _existingDive!.calculateBottomTimeFromProfile(),
              _calculateBottomTimeFromProfile,
            )
          : null,
      runtimeSuggestion: hasProfile
          ? _minutesSuggestion(
              _existingDive!.calculateRuntimeFromProfile(),
              _calculateRuntimeFromProfile,
            )
          : null,
      surfaceIntervalRow: _surfaceIntervalRow(),
      siteExtras: _siteExtras(),
      profileChild: _profileChild(),
    );
  }

  ProfileSuggestion? _depthSuggestion(
    UnitFormatter units,
    double? meters,
    VoidCallback onUse,
  ) {
    if (meters == null) return null;
    return ProfileSuggestion(
      value: units.convertDepth(meters).toStringAsFixed(1),
      onUse: onUse,
    );
  }

  ProfileSuggestion? _minutesSuggestion(
    Duration? duration,
    VoidCallback onUse,
  ) {
    if (duration == null) return null;
    return ProfileSuggestion(
      value: duration.inMinutes.toString(),
      onUse: onUse,
    );
  }

  String _formatEntryText(UnitFormatter units) =>
      '${units.formatDate(_entryDate)}, ${_entryTime.format(context)}';

  String? _formatExitText(UnitFormatter units) {
    if (_exitDate == null || _exitTime == null) return null;
    return '${units.formatDate(_exitDate!)}, ${_exitTime!.format(context)}';
  }

  Future<void> _editEntry() async {
    await _selectEntryDate();
    if (!mounted) return;
    await _selectEntryTime();
  }

  Future<void> _editExit() async {
    await _selectExitDate();
    if (!mounted) return;
    await _selectExitTime();
  }

  Widget? _surfaceIntervalRow() {
    if (!widget.isEditing || widget.diveId == null) return null;
    final interval = ref
        .watch(surfaceIntervalProvider(widget.diveId!))
        .valueOrNull;
    if (interval == null) return null;
    final hours = interval.inHours;
    final minutes = interval.inMinutes % 60;
    final text = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
    return FormRow.display(
      label: context.l10n.diveLog_edit_row_surfaceInterval,
      value: text,
    );
  }

  Widget? _siteExtras() {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    if (_isCapturingLocation) {
      children.add(
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.diveLog_edit_gettingLocation,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      );
    } else if (_currentLocation != null && !widget.isEditing) {
      children.add(
        Row(
          children: [
            Icon(Icons.my_location, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              context.l10n.diveLog_edit_nearbySitesFirst,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      );
    }
    if (_selectedSite != null && _selectedSite!.locationString.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _selectedSite!.locationString,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    if (widget.diveId != null && !_gpsSuggestionDismissed) {
      children.add(
        PhotoGpsSuggestionBanner(
          diveId: widget.diveId!,
          currentSite: _selectedSite,
          onCreateSite: () => _createSiteFromPhotoGps(),
          onUpdateSite: (gps) => _updateSiteWithPhotoGps(gps),
          onDismiss: () => setState(() => _gpsSuggestionDismissed = true),
        ),
      );
    }
    if (children.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Future<void> _createSiteFromPhotoGps() async {
    final gps = await ref.read(divePhotoGpsProvider(widget.diveId!).future);
    if (gps == null || !mounted) return;

    final newSite = await QuickSiteFromGpsDialog.show(
      context,
      latitude: gps.latitude,
      longitude: gps.longitude,
    );

    if (newSite != null && mounted) {
      // Create the site via the notifier
      final siteNotifier = ref.read(siteListNotifierProvider.notifier);
      final createdSite = await siteNotifier.addSite(newSite);

      setState(() {
        _selectedSite = createdSite;
        _gpsSuggestionDismissed = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_edit_createdSite(createdSite.name),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateSiteWithPhotoGps(GeoPoint gps) async {
    if (_selectedSite == null) return;

    final updatedSite = _selectedSite!.copyWith(location: gps);

    // Update the site via the notifier
    final siteNotifier = ref.read(siteListNotifierProvider.notifier);
    await siteNotifier.updateSite(updatedSite);

    setState(() {
      _selectedSite = updatedSite;
      _gpsSuggestionDismissed = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_addedGps(updatedSite.name)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSitePicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) => SitePickerSheet(
          scrollController: scrollController,
          selectedSiteId: _selectedSite?.id,
          currentLocation: _currentLocation,
          onSiteSelected: (site) {
            setState(() => _selectedSite = site);
            Navigator.of(sheetContext).pop();
          },
          onCreateNewSite: () {
            Navigator.of(sheetContext).pop(_createNewSiteSentinel);
          },
        ),
      ),
    );

    if (result == _createNewSiteSentinel && mounted) {
      final siteId = await context.push<String>('/sites/new');
      if (siteId != null && mounted) {
        final repo = ref.read(siteRepositoryProvider);
        final site = await repo.getSiteById(siteId);
        if (site != null && mounted) {
          setState(() => _selectedSite = site);
        }
      }
    }
  }

  Widget _buildTripSection() {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final diveDateTime = DateTime(
      _entryDate.year,
      _entryDate.month,
      _entryDate.day,
      _entryTime.hour,
      _entryTime.minute,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_section_trip,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showTripPicker,
                    icon: const Icon(Icons.flight_takeoff),
                    label: Text(
                      _selectedTrip?.name ??
                          context.l10n.diveLog_edit_selectTrip,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                if (_selectedTrip != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedTrip = null),
                    tooltip: context.l10n.diveLog_edit_tooltip_clearTrip,
                  ),
                ],
              ],
            ),
            if (_selectedTrip != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  units.formatDateRange(
                    _selectedTrip!.startDate,
                    _selectedTrip!.endDate,
                    l10n: context.l10n,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // Show suggested trip if no trip selected and dive date matches a trip
            if (_selectedTrip == null) _buildTripSuggestion(diveDateTime),
          ],
        ),
      ),
    );
  }

  Widget _buildTripSuggestion(DateTime diveDateTime) {
    final suggestedTripAsync = ref.watch(tripForDateProvider(diveDateTime));

    return suggestedTripAsync.when(
      data: (suggestedTrip) {
        if (suggestedTrip == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            button: true,
            label: 'Use suggested trip ${suggestedTrip.name}',
            child: InkWell(
              onTap: () => setState(() => _selectedTrip = suggestedTrip),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.diveLog_edit_tripSuggested(
                        suggestedTrip.name,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedTrip = suggestedTrip),
                    child: Text(context.l10n.diveLog_edit_tripUse),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _showTripPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
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
            setState(() => _selectedTrip = trip);
          },
          onCreateNewTrip: () {
            Navigator.of(sheetContext).pop(_createNewTripSentinel);
          },
        ),
      ),
    );

    if (result == _createNewTripSentinel && mounted) {
      final tripId = await context.push<String>('/trips/new');
      if (tripId != null && mounted) {
        final trip = await ref.read(tripRepositoryProvider).getTripById(tripId);
        if (trip != null && mounted) {
          setState(() => _selectedTrip = trip);
        }
      }
    }
  }

  Widget _buildDiveCenterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_section_diveCenter,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showDiveCenterPicker,
                    icon: const Icon(Icons.store),
                    label: Text(
                      _selectedDiveCenter?.name ??
                          context.l10n.diveLog_edit_selectDiveCenter,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                if (_selectedDiveCenter != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedDiveCenter = null),
                    tooltip: context.l10n.diveLog_edit_tooltip_clearDiveCenter,
                  ),
                ],
              ],
            ),
            if (_selectedDiveCenter?.displayLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _selectedDiveCenter!.displayLocation!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDiveCenterPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => DiveCenterPickerSheet(
          scrollController: scrollController,
          selectedCenter: _selectedDiveCenter,
          onCenterSelected: (center) {
            Navigator.of(sheetContext).pop();
            setState(() => _selectedDiveCenter = center);
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
          setState(() => _selectedDiveCenter = center);
        }
      }
    }
  }

  Widget _buildCourseSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_section_trainingCourse,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveLog_edit_trainingCourseHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            CoursePicker(
              selectedCourse: _selectedCourse,
              onCourseSelected: (course) {
                setState(() => _selectedCourse = course);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the profile editor, optionally prompting the user to choose which
  /// computer's profile to start from when the dive has multiple computers.
  Future<void> _openProfileEditor(String diveId, {String? initialMode}) async {
    final readings = await ref.read(diveDataSourcesProvider(diveId).future);

    // Filter to non-edited (original) sources only
    final originalReadings = readings
        .where((r) => r.computerId != null)
        .toList();

    if (originalReadings.length > 1 && mounted) {
      // Multi-computer dive: ask which profile to start from
      final selected = await showModalBottomSheet<DiveDataSource>(
        context: context,
        builder: (context) =>
            ComputerSourceSelectionSheet(readings: originalReadings),
      );

      if (selected == null || !mounted) return;

      // Load the selected computer's profile points and push a pre-seeded
      // editor.  We do this by passing the computerId as a query parameter
      // so the router / page can load the correct source.
      context.pushNamed(
        'editProfile',
        pathParameters: {'diveId': diveId},
        queryParameters: {
          'mode': ?initialMode,
          'sourceComputerId': ?selected.computerId,
        },
      );
    } else {
      // Single-computer (or no readings): open editor directly
      if (!mounted) return;
      context.pushNamed(
        'editProfile',
        pathParameters: {'diveId': diveId},
        queryParameters: {'mode': ?initialMode},
      );
    }
  }

  Widget _profileChild() {
    final hasProfile = _existingDive?.profile.isNotEmpty == true;
    final profileLength = _existingDive?.profile.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dive Profile',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (hasProfile)
                Text(
                  '$profileLength points',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasProfile) ...[
            // Outlier suggestion
            Consumer(
              builder: (context, ref, _) {
                final outliersAsync = ref.watch(
                  outlierSuggestionProvider(_existingDive!.id),
                );
                return outliersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (outliers) {
                    if (outliers.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ActionChip(
                        avatar: const Icon(Icons.warning_amber, size: 18),
                        label: Text(
                          '${outliers.length} potential '
                          'outlier${outliers.length == 1 ? '' : 's'} detected',
                        ),
                        onPressed: () => _openProfileEditor(
                          _existingDive!.id,
                          initialMode: 'outlier',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              onPressed: () => _openProfileEditor(_existingDive!.id),
            ),
          ] else ...[
            Text(
              'No profile data recorded. You can draw a profile manually.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.isEditing)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.draw),
                label: const Text('Draw Profile'),
                onPressed: () => context.pushNamed(
                  'editProfile',
                  pathParameters: {'diveId': widget.diveId!},
                  queryParameters: {'mode': 'draw'},
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildGasGearSection(UnitFormatter units) {
    final defaultExpanded = !widget.isEditing;
    return GasGearSection(
      expanded: _isExpanded('gasGear', defaultValue: defaultExpanded),
      onToggle: () => _toggleSection('gasGear', defaultValue: defaultExpanded),
      summary: _gasGearSummary(),
      modeSelector: DiveModeSelector(
        selectedMode: _diveMode,
        onChanged: (mode) {
          setState(() => _diveMode = mode);
        },
      ),
      rebreatherPanel: _rebreatherPanel(),
      tankCards: [
        for (var i = 0; i < _tanks.length; i++)
          TankCard(
            key: ValueKey(_tanks[i].id),
            tank: _tanks[i],
            tankNumber: i + 1,
            units: units,
            onChanged: (updatedTank) {
              setState(() {
                _tanksDirty = true;
                _tanks[i] = updatedTank;
              });
            },
            onRemove: _tanks.length > 1 ? () => _removeTank(i) : null,
            canRemove: _tanks.length > 1,
          ),
      ],
      onAddTank: _addTank,
      addTankLabel: context.l10n.diveLog_edit_addTank,
      equipmentChild: _equipmentChild(),
      weightChild: _weightChild(units),
    );
  }

  String _gasGearSummary() {
    final l10n = context.l10n;
    final mix = _tanks.isNotEmpty ? _tanks.first.gasMix.name : null;
    return [
      l10n.diveLog_edit_summary_tanks(_tanks.length),
      ?mix,
      if (_selectedEquipment.isNotEmpty)
        l10n.diveLog_edit_summary_items(_selectedEquipment.length),
    ].join(' · ');
  }

  Widget? _rebreatherPanel() {
    if (_diveMode == DiveMode.ccr) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: CcrSettingsPanel(
          setpointLow: _setpointLow,
          setpointHigh: _setpointHigh,
          setpointDeco: _setpointDeco,
          diluentGas: _diluentGas,
          scrubberType: _scrubberType,
          scrubberDurationMinutes: _scrubberDurationMinutes,
          scrubberRemainingMinutes: _scrubberRemainingMinutes,
          loopVolume: _loopVolume,
          onChanged:
              ({
                double? setpointLow,
                double? setpointHigh,
                double? setpointDeco,
                GasMix? diluentGas,
                String? scrubberType,
                int? scrubberDurationMinutes,
                int? scrubberRemainingMinutes,
                double? loopVolume,
              }) {
                setState(() {
                  _setpointLow = setpointLow;
                  _setpointHigh = setpointHigh;
                  _setpointDeco = setpointDeco;
                  _diluentGas = diluentGas;
                  _scrubberType = scrubberType;
                  _scrubberDurationMinutes = scrubberDurationMinutes;
                  _scrubberRemainingMinutes = scrubberRemainingMinutes;
                  _loopVolume = loopVolume;
                });
              },
        ),
      );
    }
    if (_diveMode == DiveMode.scr) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: ScrSettingsPanel(
          scrType: _scrType,
          injectionRate: _scrInjectionRate,
          additionRatio: _scrAdditionRatio,
          orificeSize: _scrOrificeSize,
          supplyGas: _scrSupplyGas,
          assumedVo2: _assumedVo2,
          loopO2Min: _loopO2Min,
          loopO2Max: _loopO2Max,
          loopO2Avg: _loopO2Avg,
          scrubberType: _scrubberType,
          scrubberDurationMinutes: _scrubberDurationMinutes,
          scrubberRemainingMinutes: _scrubberRemainingMinutes,
          onChanged:
              ({
                ScrType? scrType,
                double? injectionRate,
                double? additionRatio,
                String? orificeSize,
                GasMix? supplyGas,
                double? assumedVo2,
                double? loopO2Min,
                double? loopO2Max,
                double? loopO2Avg,
                String? scrubberType,
                int? scrubberDurationMinutes,
                int? scrubberRemainingMinutes,
              }) {
                setState(() {
                  _scrType = scrType;
                  _scrInjectionRate = injectionRate;
                  _scrAdditionRatio = additionRatio;
                  _scrOrificeSize = orificeSize;
                  _scrSupplyGas = supplyGas;
                  _assumedVo2 = assumedVo2;
                  _loopO2Min = loopO2Min;
                  _loopO2Max = loopO2Max;
                  _loopO2Avg = loopO2Avg;
                  _scrubberType = scrubberType;
                  _scrubberDurationMinutes = scrubberDurationMinutes;
                  _scrubberRemainingMinutes = scrubberRemainingMinutes;
                });
              },
        ),
      );
    }
    return null;
  }

  /// Calculate bottom time from dive profile data and update the field
  void _calculateBottomTimeFromProfile() {
    if (_existingDive == null || _existingDive!.profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_noProfileData),
        ),
      );
      return;
    }

    final calculatedBottomTime = _existingDive!
        .calculateBottomTimeFromProfile();

    if (calculatedBottomTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_unableToCalculate),
        ),
      );
      return;
    }

    setState(() {
      _durationController.text = calculatedBottomTime.inMinutes.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveLog_edit_snackbar_bottomTimeCalculated(
            calculatedBottomTime.inMinutes,
          ),
        ),
      ),
    );
  }

  /// Calculate max depth from dive profile data and update the field
  void _calculateMaxDepthFromProfile(UnitFormatter units) {
    if (_existingDive == null || _existingDive!.profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_noProfileData),
        ),
      );
      return;
    }

    final calculatedDepth = _existingDive!.calculateMaxDepthFromProfile();

    if (calculatedDepth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveLog_edit_snackbar_unableToCalculateMaxDepth,
          ),
        ),
      );
      return;
    }

    final displayDepth = units.convertDepth(calculatedDepth);

    setState(() {
      _maxDepthController.text = displayDepth.toStringAsFixed(1);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveLog_edit_snackbar_maxDepthCalculated(
            '${displayDepth.toStringAsFixed(1)} ${units.depthSymbol}',
          ),
        ),
      ),
    );
  }

  /// Calculate average depth from dive profile data and update the field
  void _calculateAvgDepthFromProfile(UnitFormatter units) {
    if (_existingDive == null || _existingDive!.profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_noProfileData),
        ),
      );
      return;
    }

    final calculatedDepth = _existingDive!.calculateAvgDepthFromProfile();

    if (calculatedDepth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveLog_edit_snackbar_unableToCalculateAvgDepth,
          ),
        ),
      );
      return;
    }

    final displayDepth = units.convertDepth(calculatedDepth);

    setState(() {
      _avgDepthController.text = displayDepth.toStringAsFixed(1);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveLog_edit_snackbar_avgDepthCalculated(
            '${displayDepth.toStringAsFixed(1)} ${units.depthSymbol}',
          ),
        ),
      ),
    );
  }

  /// Calculate runtime from dive profile data and update the field
  void _calculateRuntimeFromProfile() {
    if (_existingDive == null || _existingDive!.profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveLog_edit_snackbar_noProfileData),
        ),
      );
      return;
    }

    final calculatedRuntime = _existingDive!.calculateRuntimeFromProfile();

    if (calculatedRuntime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveLog_edit_snackbar_unableToCalculateRuntime,
          ),
        ),
      );
      return;
    }

    setState(() {
      _runtimeController.text = calculatedRuntime.inMinutes.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.diveLog_edit_snackbar_runtimeCalculated(
            calculatedRuntime.inMinutes,
          ),
        ),
      ),
    );
  }

  void _addTank() {
    final settings = ref.read(settingsProvider);
    setState(() {
      _tanksDirty = true;
      _tanks.add(
        DiveTank(
          id: _uuid.v4(),
          volume: _defaultPreset?.volumeLiters ?? settings.defaultTankVolume,
          workingPressure: _defaultPreset?.workingPressureBar,
          startPressure: settings.defaultStartPressure.toDouble(),
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
    setState(() {
      _tanksDirty = true;
      _tanks.removeAt(index);
      // Update order for remaining tanks
      for (var i = 0; i < _tanks.length; i++) {
        _tanks[i] = _tanks[i].copyWith(order: i);
      }
    });
  }

  Widget _equipmentChild() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_edit_section_equipment,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _showEquipmentSetPicker,
                    icon: const Icon(Icons.folder_special, size: 18),
                    label: Text(context.l10n.diveLog_edit_useSet),
                  ),
                  TextButton.icon(
                    onPressed: _showEquipmentPicker,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.diveLog_edit_add),
                  ),
                ],
              ),
            ],
          ),
          if (_selectedEquipment.isEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.diveLog_edit_noEquipmentSelected,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.diveLog_edit_equipmentHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Divider(),
            ...List.generate(_selectedEquipment.length, (index) {
              final item = _selectedEquipment[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    _getEquipmentIcon(item.type),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(item.name),
                subtitle: Text(item.type.displayName),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: context.l10n.diveLog_edit_tooltip_removeEquipment,
                  onPressed: () {
                    setState(() {
                      _selectedEquipment.removeAt(index);
                    });
                  },
                ),
              );
            }),
            if (_selectedEquipment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _saveEquipmentAsSet,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: Text(context.l10n.diveLog_edit_saveAsSet),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedEquipment.clear();
                      });
                    },
                    child: Text(context.l10n.diveLog_edit_clearAllEquipment),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  IconData _getEquipmentIcon(EquipmentType type) {
    switch (type) {
      case EquipmentType.regulator:
        return Icons.air;
      case EquipmentType.bcd:
        return Icons.checkroom;
      case EquipmentType.wetsuit:
        return Icons.dry_cleaning;
      case EquipmentType.drysuit:
        return Icons.dry_cleaning;
      case EquipmentType.mask:
        return Icons.visibility;
      case EquipmentType.fins:
        return Icons.water;
      case EquipmentType.boots:
        return Icons.hiking;
      case EquipmentType.gloves:
        return Icons.pan_tool;
      case EquipmentType.hood:
        return Icons.face;
      case EquipmentType.tank:
        return MdiIcons.divingScubaTank;
      case EquipmentType.weights:
        return Icons.fitness_center;
      case EquipmentType.computer:
        return Icons.watch;
      case EquipmentType.light:
        return Icons.flashlight_on;
      case EquipmentType.camera:
        return Icons.camera_alt;
      case EquipmentType.knife:
        return Icons.content_cut;
      case EquipmentType.smb:
        return Icons.flag;
      case EquipmentType.reel:
        return Icons.all_inclusive;
      case EquipmentType.other:
        return Icons.build;
    }
  }

  void _showEquipmentPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentPickerSheet(
          scrollController: scrollController,
          selectedEquipmentIds: _selectedEquipment.map((e) => e.id).toSet(),
          onEquipmentSelected: (equipment) {
            setState(() {
              // Add if not already selected
              if (!_selectedEquipment.any((e) => e.id == equipment.id)) {
                _selectedEquipment.add(equipment);
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showEquipmentSetPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentSetPickerSheet(
          scrollController: scrollController,
          onSetSelected: (set, items) {
            setState(() {
              // Add all items from set that aren't already selected
              for (final item in items) {
                if (!_selectedEquipment.any((e) => e.id == item.id)) {
                  _selectedEquipment.add(item);
                }
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _saveEquipmentAsSet() {
    if (_selectedEquipment.isEmpty) return;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveLog_edit_saveAsSetDialog_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_saveAsSetDialog_content(
                _selectedEquipment.length,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: context.l10n.diveLog_edit_saveAsSetDialog_setName,
                hintText: context.l10n.diveLog_edit_saveAsSetDialog_setNameHint,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText:
                    context.l10n.diveLog_edit_saveAsSetDialog_description,
                hintText:
                    context.l10n.diveLog_edit_saveAsSetDialog_descriptionHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.diveLog_edit_cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.diveLog_edit_saveAsSetDialog_validation,
                    ),
                  ),
                );
                return;
              }

              try {
                final set = EquipmentSet(
                  id: '',
                  name: name,
                  description: descriptionController.text.trim(),
                  equipmentIds: _selectedEquipment.map((e) => e.id).toList(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final repository = ref.read(equipmentSetRepositoryProvider);
                await repository.createSet(set);

                // Invalidate the sets provider to refresh the list
                ref.invalidate(equipmentSetsProvider);

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.diveLog_edit_saveAsSetDialog_success(name),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.diveLog_edit_saveAsSetDialog_error(
                          e.toString(),
                        ),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(context.l10n.diveLog_edit_save),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentSection(UnitFormatter units) {
    final canFetchWeather =
        _selectedSite != null && _selectedSite!.hasCoordinates;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header with Fetch Weather button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.diveLog_edit_section_environment,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _isFetchingWeather
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: canFetchWeather
                            ? () => _fetchWeather(units)
                            : null,
                        icon: const Icon(Icons.cloud_download, size: 18),
                        label: Text(
                          context.l10n.diveLog_edit_button_fetchWeather,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            // -- Weather sub-header --
            Text(
              context.l10n.diveLog_edit_subsection_weather,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _buildWeatherFields(units),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // -- Dive Conditions sub-header --
            Text(
              context.l10n.diveLog_edit_subsection_diveConditions,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, child) {
                final diveTypesAsync = ref.watch(diveTypeListNotifierProvider);
                return diveTypesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, st) => Text(
                    context.l10n.diveLog_edit_errorLoadingDiveTypes(
                      e.toString(),
                    ),
                  ),
                  data: (diveTypes) {
                    // Ensure selected dive type exists in the list
                    final selectedExists = diveTypes.any(
                      (t) => t.id == _selectedDiveTypeId,
                    );
                    final effectiveValue = selectedExists
                        ? _selectedDiveTypeId
                        : 'recreational';

                    return DropdownButtonFormField<String>(
                      key: ValueKey(
                        'dive_type_${diveTypes.length}_$effectiveValue',
                      ),
                      initialValue: effectiveValue,
                      decoration: InputDecoration(
                        labelText: context.l10n.diveLog_edit_label_diveType,
                      ),
                      items: diveTypes.map((type) {
                        return DropdownMenuItem(
                          value: type.id,
                          child: Text(type.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedDiveTypeId = value);
                        }
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _waterTempController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_label_waterTemp,
                      suffixText: units.temperatureSymbol,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<Visibility>(
                    initialValue: _selectedVisibility,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_label_visibility,
                    ),
                    items: Visibility.values.map((vis) {
                      return DropdownMenuItem(
                        value: vis,
                        child: Text(vis.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedVisibility = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WaterType>(
              initialValue: _waterType,
              decoration: InputDecoration(
                labelText: context.l10n.diveLog_edit_label_waterType,
              ),
              items: [
                DropdownMenuItem<WaterType>(
                  value: null,
                  child: Text(context.l10n.diveLog_edit_notSpecified),
                ),
                ...WaterType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() => _waterType = value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CurrentDirection>(
                    initialValue: _currentDirection,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.diveLog_edit_label_currentDirection,
                    ),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<CurrentDirection>(
                        value: null,
                        child: Text(context.l10n.diveLog_edit_notSpecified),
                      ),
                      ...CurrentDirection.values.map((dir) {
                        return DropdownMenuItem(
                          value: dir,
                          child: Text(dir.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _currentDirection = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<CurrentStrength>(
                    initialValue: _currentStrength,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.diveLog_edit_label_currentStrength,
                    ),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<CurrentStrength>(
                        value: null,
                        child: Text(context.l10n.diveLog_edit_notSpecified),
                      ),
                      ...CurrentStrength.values.map((str) {
                        return DropdownMenuItem(
                          value: str,
                          child: Text(str.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _currentStrength = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _swellHeightController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_label_swellHeight,
                      suffixText: units.depthSymbol,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _altitudeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_label_altitude,
                      suffixText: units.altitudeSymbol,
                      helperText: _getAltitudeWarning(units),
                      helperStyle: TextStyle(
                        color: _getAltitudeWarningColor(units),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<EntryMethod>(
                    initialValue: _entryMethod,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_label_entryMethod,
                    ),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<EntryMethod>(
                        value: null,
                        child: Text(context.l10n.diveLog_edit_notSpecified),
                      ),
                      ...EntryMethod.values.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _entryMethod = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<EntryMethod>(
                    initialValue: _exitMethod,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_label_exitMethod,
                    ),
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<EntryMethod>(
                        value: null,
                        child: Text(context.l10n.diveLog_edit_notSpecified),
                      ),
                      ...EntryMethod.values.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method.displayName),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _exitMethod = value);
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

  /// Weather fields extracted into a helper to keep the environment section
  /// manageable given the file size.
  Widget _buildWeatherFields(UnitFormatter units) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Air Temp and Humidity row
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _airTempController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_edit_label_airTemp,
                  suffixText: units.temperatureSymbol,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _humidityController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_edit_label_humidity,
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Wind Speed and Wind Direction row
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _windSpeedController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_edit_label_windSpeed,
                  suffixText: units.windSpeedSymbol,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<CurrentDirection>(
                initialValue: _windDirection,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_edit_label_windDirection,
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<CurrentDirection>(
                    value: null,
                    child: Text(context.l10n.diveLog_edit_notSpecified),
                  ),
                  ...CurrentDirection.values.map((dir) {
                    return DropdownMenuItem(
                      value: dir,
                      child: Text(dir.displayName),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _windDirection = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Surface Pressure field (always in mbar)
        TextFormField(
          controller: _surfacePressureController,
          decoration: InputDecoration(
            labelText: context.l10n.diveLog_edit_label_surfacePressure,
            suffixText: 'mbar',
            helperText: context.l10n.diveLog_edit_surfacePressureHint,
            hintText: context.l10n.diveLog_edit_surfacePressureDefault,
            prefixIcon: const Icon(Icons.speed),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        // Cloud Cover and Precipitation row
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<CloudCover>(
                initialValue: _cloudCover,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_edit_label_cloudCover,
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<CloudCover>(
                    value: null,
                    child: Text(context.l10n.diveLog_edit_notSpecified),
                  ),
                  ...CloudCover.values.map((cover) {
                    return DropdownMenuItem(
                      value: cover,
                      child: Text(cover.displayName),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _cloudCover = value);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<Precipitation>(
                initialValue: _precipitation,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_edit_label_precipitation,
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<Precipitation>(
                    value: null,
                    child: Text(context.l10n.diveLog_edit_notSpecified),
                  ),
                  ...Precipitation.values.map((precip) {
                    return DropdownMenuItem(
                      value: precip,
                      child: Text(precip.displayName),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _precipitation = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Weather Description
        TextFormField(
          controller: _weatherDescriptionController,
          decoration: InputDecoration(
            labelText: context.l10n.diveLog_edit_label_weatherDescription,
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  /// Fetch weather data from Open-Meteo for the selected site and dive date.
  Future<void> _fetchWeather(UnitFormatter units) async {
    if (_selectedSite == null || !_selectedSite!.hasCoordinates) return;

    // If any weather field is already populated, confirm before overwriting
    final hasExistingWeatherData =
        _windSpeedController.text.isNotEmpty ||
        _humidityController.text.isNotEmpty ||
        _weatherDescriptionController.text.isNotEmpty ||
        _windDirection != null ||
        _cloudCover != null ||
        _precipitation != null;

    if (hasExistingWeatherData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.diveLog_edit_fetchWeatherConfirm),
          content: Text(context.l10n.diveLog_edit_fetchWeatherConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.common_action_ok),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isFetchingWeather = true);

    try {
      final entryDateTime = DateTime(
        _entryDate.year,
        _entryDate.month,
        _entryDate.day,
        _entryTime.hour,
        _entryTime.minute,
      );

      final service = ref.read(weatherServiceProvider);
      final weather = await service.fetchWeather(
        latitude: _selectedSite!.location!.latitude,
        longitude: _selectedSite!.location!.longitude,
        date: _entryDate,
        entryTime: entryDateTime,
      );

      if (!mounted) return;

      if (weather == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveLog_edit_fetchWeatherUnavailable),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      setState(() {
        // Populate weather fields from fetched data
        if (weather.windSpeed != null) {
          _windSpeedController.text = units
              .convertWindSpeed(weather.windSpeed!)
              .toStringAsFixed(1);
        }
        if (weather.windDirection != null) {
          _windDirection = weather.windDirection;
        }
        if (weather.cloudCover != null) {
          _cloudCover = weather.cloudCover;
        }
        if (weather.precipitation != null) {
          _precipitation = weather.precipitation;
        }
        if (weather.humidity != null) {
          _humidityController.text = weather.humidity!.toStringAsFixed(0);
        }
        if (weather.description != null && weather.description!.isNotEmpty) {
          _weatherDescriptionController.text = weather.description!;
        }
        // Only fill airTemp if the controller is currently empty
        if (weather.airTemp != null && _airTempController.text.isEmpty) {
          _airTempController.text = units
              .convertTemperature(weather.airTemp!)
              .toStringAsFixed(0);
        }
        // Only fill surfacePressure if the controller is currently empty
        if (weather.surfacePressure != null &&
            _surfacePressureController.text.isEmpty) {
          _surfacePressureController.text = (weather.surfacePressure! * 1000)
              .toStringAsFixed(0);
        }
        _weatherSource = WeatherSource.openMeteo;
        _weatherFetchedAt = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.diveLog_edit_weatherFetched)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch weather: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingWeather = false);
      }
    }
  }

  Widget _weightChild(UnitFormatter units) {
    final totalWeight = _weights.fold(0.0, (sum, w) => sum + w.amountKg);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_edit_section_weight,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_weights.isNotEmpty)
                Text(
                  context.l10n.diveLog_edit_weightTotal(
                    units.formatWeight(totalWeight),
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._weights.asMap().entries.map((entry) {
            final index = entry.key;
            final weight = entry.value;
            return _buildWeightEntryRow(index, weight, units);
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _weights.add(
                  DiveWeight(
                    id: _uuid.v4(),
                    diveId: widget.diveId ?? '',
                    weightType: WeightType.integrated,
                    amountKg: 0,
                  ),
                );
              });
            },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.diveLog_edit_addWeightEntry),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightEntryRow(
    int index,
    DiveWeight weight,
    UnitFormatter units,
  ) {
    // Display in user's preferred unit
    final displayAmount = units.convertWeight(weight.amountKg);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<WeightType>(
              initialValue: weight.weightType,
              decoration: InputDecoration(
                labelText: context.l10n.diveLog_edit_label_type,
                isDense: true,
              ),
              isExpanded: true,
              items: WeightType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _weights[index] = weight.copyWith(weightType: value);
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: TextFormField(
              initialValue: displayAmount > 0
                  ? displayAmount.toStringAsFixed(1)
                  : '',
              decoration: InputDecoration(
                labelText: units.weightSymbol,
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                final displayValue = double.tryParse(value) ?? 0;
                // Convert back to kg for storage
                final amountKg = units.weightToKg(displayValue);
                _weights[index] = weight.copyWith(amountKg: amountKg);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _weights.removeAt(index);
              });
            },
            tooltip: context.l10n.diveLog_edit_tooltip_removeWeight,
          ),
        ],
      ),
    );
  }

  Widget _buildBuddySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BuddyPicker(
          diveId: widget.diveId,
          selectedBuddies: _selectedBuddies,
          onChanged: (buddies) {
            setState(() => _selectedBuddies = buddies);
          },
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_section_rating,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  tooltip: '$starNumber star${starNumber > 1 ? 's' : ''}',
                  onPressed: () {
                    setState(() => _rating = index + 1);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSightingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.diveLog_edit_section_marineLife,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _showSpeciesPicker,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.diveLog_edit_add),
                ),
              ],
            ),
            if (_sightings.isEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.water,
                        size: 48,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.diveLog_edit_noMarineLife,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.diveLog_edit_marineLifeHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Divider(),
              ...List.generate(_sightings.length, (index) {
                final sighting = _sightings[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _getCategoryColor(
                      sighting.speciesCategory,
                    ),
                    child: Icon(
                      iconForSpeciesCategory(
                        sighting.speciesCategory ?? SpeciesCategory.other,
                      ),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(sighting.speciesName),
                  subtitle: sighting.notes.isNotEmpty
                      ? Text(
                          sighting.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sighting.count > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'x${sighting.count}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip:
                            context.l10n.diveLog_edit_tooltip_removeSighting,
                        onPressed: () {
                          setState(() {
                            _sightings.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                  onTap: () => _editSighting(index),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(SpeciesCategory? category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Colors.blue;
      case SpeciesCategory.shark:
        return Colors.grey.shade700;
      case SpeciesCategory.ray:
        return Colors.indigo;
      case SpeciesCategory.mammal:
        return Colors.brown;
      case SpeciesCategory.turtle:
        return Colors.green.shade700;
      case SpeciesCategory.invertebrate:
        return Colors.purple;
      case SpeciesCategory.coral:
        return Colors.pink;
      case SpeciesCategory.plant:
        return Colors.green;
      case SpeciesCategory.other:
      case null:
        return Colors.grey;
    }
  }

  void _showSpeciesPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SpeciesPickerSheet(
          scrollController: scrollController,
          onSpeciesSelected: (species, count, notes) {
            setState(() {
              _sightings.add(
                Sighting(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  diveId: widget.diveId ?? '',
                  speciesId: species.id,
                  speciesName: species.commonName,
                  speciesCategory: species.category,
                  count: count,
                  notes: notes,
                ),
              );
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _editSighting(int index) {
    final sighting = _sightings[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditSightingSheet(
        sighting: sighting,
        onSave: (updatedSighting) {
          setState(() {
            _sightings[index] = updatedSighting;
          });
          Navigator.of(context).pop();
        },
        onDelete: () {
          setState(() {
            _sightings.removeAt(index);
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.diveLog_edit_section_notes,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: context.l10n.diveLog_edit_notesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectEntryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) {
      setState(() {
        _entryDate = date;
        // If exit date not set, default it to the same day
        _exitDate ??= date;
      });
    }
  }

  Future<void> _selectEntryTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _entryTime,
    );
    if (time != null) {
      setState(() => _entryTime = time);
    }
  }

  Future<void> _selectExitDate() async {
    // Normalize dates to midnight to avoid time-based comparison issues
    final normalizedEntryDate = DateTime(
      _entryDate.year,
      _entryDate.month,
      _entryDate.day,
    );
    final normalizedExitDate = _exitDate != null
        ? DateTime(_exitDate!.year, _exitDate!.month, _exitDate!.day)
        : normalizedEntryDate;

    // Use the earlier of entry and exit as firstDate to handle existing dives
    // that may have data inconsistencies
    final firstDate = normalizedExitDate.isBefore(normalizedEntryDate)
        ? normalizedExitDate
        : normalizedEntryDate;

    // Allow exit up to 1 day after entry (multi-day dives are rare in scuba)
    final lastDate = normalizedEntryDate.add(const Duration(days: 1));

    // Ensure initialDate is within the valid range
    DateTime initialDate = normalizedExitDate;
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date != null) {
      setState(() => _exitDate = date);
    }
  }

  Future<void> _selectExitTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime:
          _exitTime ??
          TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
    );
    if (time != null) {
      setState(() {
        _exitTime = time;
        // Also set exit date if not set
        _exitDate ??= _entryDate;
      });
    }
  }

  Future<void> _saveDive(UnitFormatter units) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Build entry DateTime from date and time
      final entryDateTime = DateTime.utc(
        _entryDate.year,
        _entryDate.month,
        _entryDate.day,
        _entryTime.hour,
        _entryTime.minute,
      );

      // Build exit DateTime if set
      DateTime? exitDateTime;
      if (_exitDate != null && _exitTime != null) {
        exitDateTime = DateTime.utc(
          _exitDate!.year,
          _exitDate!.month,
          _exitDate!.day,
          _exitTime!.hour,
          _exitTime!.minute,
        );
      }

      // Calculate runtime from entry/exit times (total dive time)
      Duration? runtime;
      if (exitDateTime != null) {
        runtime = exitDateTime.difference(entryDateTime);
        if (runtime.isNegative) runtime = null;
      } else if (_runtimeController.text.isNotEmpty) {
        runtime = Duration(minutes: int.parse(_runtimeController.text));
      }

      // Bottom time is manually entered (time at depth, excluding descent/ascent)
      Duration? duration;
      if (_durationController.text.isNotEmpty) {
        duration = Duration(minutes: int.parse(_durationController.text));
      }

      // Parse form values and convert to metric for storage
      final maxDepth = _maxDepthController.text.isNotEmpty
          ? units.depthToMeters(double.parse(_maxDepthController.text))
          : null;
      final avgDepth = _avgDepthController.text.isNotEmpty
          ? units.depthToMeters(double.parse(_avgDepthController.text))
          : null;
      final waterTemp = _waterTempController.text.isNotEmpty
          ? units.temperatureToCelsius(double.parse(_waterTempController.text))
          : null;
      final airTemp = _airTempController.text.isNotEmpty
          ? units.temperatureToCelsius(double.parse(_airTempController.text))
          : null;

      // Parse conditions values (convert to metric)
      final swellHeight = _swellHeightController.text.isNotEmpty
          ? units.depthToMeters(double.parse(_swellHeightController.text))
          : null;
      final altitude = _altitudeController.text.isNotEmpty
          ? units.altitudeToMeters(double.parse(_altitudeController.text))
          : null;
      final surfacePressure = _surfacePressureController.text.isNotEmpty
          ? double.parse(_surfacePressureController.text) /
                1000 // Convert mbar to bar
          : null;

      // Create dive entity
      final dive = Dive(
        id: widget.diveId ?? '',
        diverId: _existingDive?.diverId, // Preserve diver assignment
        diveNumber: _diveNumberController.text.isNotEmpty
            ? int.parse(_diveNumberController.text)
            : null,
        dateTime: entryDateTime, // Keep for backward compatibility
        entryTime: entryDateTime,
        exitTime: exitDateTime,
        bottomTime: duration,
        runtime: runtime,
        maxDepth: maxDepth,
        avgDepth: avgDepth,
        waterTemp: waterTemp,
        airTemp: airTemp,
        visibility: _selectedVisibility != Visibility.unknown
            ? _selectedVisibility
            : null,
        diveTypeId: _selectedDiveTypeId,
        notes: _notesController.text,
        rating: _rating > 0 ? _rating : null,
        site: _selectedSite,
        trip: _selectedTrip,
        diveCenter: _selectedDiveCenter,
        courseId: _selectedCourse?.id,
        tanks: _tanks,
        equipment: _selectedEquipment,
        // Conditions fields
        currentDirection: _currentDirection,
        currentStrength: _currentStrength,
        swellHeight: swellHeight,
        entryMethod: _entryMethod,
        exitMethod: _exitMethod,
        waterType: _waterType,
        altitude: altitude,
        surfacePressure: surfacePressure,
        // Weather fields
        windSpeed: _windSpeedController.text.isNotEmpty
            ? units.windSpeedToMs(double.parse(_windSpeedController.text))
            : null,
        windDirection: _windDirection,
        cloudCover: _cloudCover,
        precipitation: _precipitation,
        humidity: _humidityController.text.isNotEmpty
            ? double.parse(_humidityController.text)
            : null,
        weatherDescription: _weatherDescriptionController.text.isNotEmpty
            ? _weatherDescriptionController.text
            : null,
        weatherSource: _weatherSource,
        weatherFetchedAt: _weatherFetchedAt,
        // Weight entries (multiple)
        weights: _weights,
        // Tags
        tags: _selectedTags,
        // Custom fields (filter out entries with empty keys)
        customFields: _customFields
            .where((f) => f.key.trim().isNotEmpty)
            .toList(),
        // Preserve favorite status when editing
        isFavorite: _existingDive?.isFavorite ?? false,
        // Preserve dive profile data (time series from dive computer)
        profile: _existingDive?.profile ?? const [],
        // Preserve photo associations
        photoIds: _existingDive?.photoIds ?? const [],
        // Preserve legacy buddy/divemaster text fields
        buddy: _existingDive?.buddy,
        diveMaster: _existingDive?.diveMaster,
        // CCR/SCR rebreather settings
        diveMode: _diveMode,
        setpointLow: _diveMode == DiveMode.ccr ? _setpointLow : null,
        setpointHigh: _diveMode == DiveMode.ccr ? _setpointHigh : null,
        setpointDeco: _diveMode == DiveMode.ccr ? _setpointDeco : null,
        diluentGas: _diveMode == DiveMode.ccr
            ? _diluentGas
            : (_diveMode == DiveMode.scr ? _scrSupplyGas : null),
        loopVolume: _diveMode == DiveMode.ccr ? _loopVolume : null,
        scrubber:
            (_diveMode == DiveMode.ccr || _diveMode == DiveMode.scr) &&
                _scrubberType != null
            ? ScrubberInfo(
                type: _scrubberType!,
                ratedMinutes: _scrubberDurationMinutes,
                remainingMinutes: _scrubberRemainingMinutes,
              )
            : null,
        scrType: _diveMode == DiveMode.scr ? _scrType : null,
        scrInjectionRate: _diveMode == DiveMode.scr ? _scrInjectionRate : null,
        scrAdditionRatio: _diveMode == DiveMode.scr ? _scrAdditionRatio : null,
        scrOrificeSize: _diveMode == DiveMode.scr ? _scrOrificeSize : null,
        assumedVo2: _diveMode == DiveMode.scr ? _assumedVo2 : null,
        loopO2Min: _diveMode == DiveMode.scr ? _loopO2Min : null,
        loopO2Max: _diveMode == DiveMode.scr ? _loopO2Max : null,
        loopO2Avg: _diveMode == DiveMode.scr ? _loopO2Avg : null,
      );

      // Save using the notifier
      final notifier = ref.read(paginatedDiveListProvider.notifier);
      String? savedDiveId;
      if (widget.isEditing) {
        await notifier.updateDive(dive);
        savedDiveId = widget.diveId;
      } else {
        final savedDive = await notifier.addDive(dive);
        savedDiveId = savedDive.id;

        // Auto-fetch weather for new dives with coordinates
        if (_selectedSite != null && _selectedSite!.hasCoordinates) {
          // Fire and forget -- don't await, don't block save
          ref
              .read(weatherRepositoryProvider)
              .fetchAndSaveWeather(
                diveId: savedDiveId,
                latitude: _selectedSite!.location!.latitude,
                longitude: _selectedSite!.location!.longitude,
                dateTime: dive.dateTime,
              );
        }
      }

      // Save sightings
      if (savedDiveId != null) {
        final speciesRepository = ref.read(speciesRepositoryProvider);

        // Get current sighting IDs
        final currentSightingIds = _sightings.map((s) => s.id).toSet();

        // Delete removed sightings (those in original but not in current)
        for (final originalId in _originalSightingIds) {
          if (!currentSightingIds.contains(originalId)) {
            await speciesRepository.deleteSighting(originalId);
          }
        }

        // Add or update sightings
        for (final sighting in _sightings) {
          final isExisting = _originalSightingIds.contains(sighting.id);
          if (isExisting) {
            // Update existing sighting
            await speciesRepository.updateSighting(sighting);
          } else {
            // Add new sighting
            await speciesRepository.addSighting(
              diveId: savedDiveId,
              speciesId: sighting.speciesId,
              count: sighting.count,
              notes: sighting.notes,
            );
          }
        }

        // Invalidate providers so detail pages update
        ref.invalidate(diveSightingsProvider(savedDiveId));
        if (_selectedSite != null) {
          ref.invalidate(siteSpottedSpeciesProvider(_selectedSite!.id));
        }
      }

      // Save buddies
      if (savedDiveId != null) {
        final buddyRepository = ref.read(buddyRepositoryProvider);
        await buddyRepository.setBuddiesForDive(savedDiveId, _selectedBuddies);
        // Invalidate the buddies provider so the detail page shows updated data
        ref.invalidate(buddiesForDiveProvider(savedDiveId));
        // Invalidate providers for all affected buddies (added + removed)
        final newBuddyIds = _selectedBuddies.map((b) => b.buddy.id).toSet();
        final affectedBuddyIds = _originalBuddyIds.union(newBuddyIds);
        for (final buddyId in affectedBuddyIds) {
          ref.invalidate(buddyStatsProvider(buddyId));
          ref.invalidate(diveIdsForBuddyProvider(buddyId));
          ref.invalidate(divesForBuddyProvider(buddyId));
        }
        ref.invalidate(allBuddiesWithDiveCountProvider);
      }

      // Invalidate course providers if course association changed
      if (savedDiveId != null) {
        final oldCourseId = _existingDive?.courseId;
        final newCourseId = _selectedCourse?.id;
        // Invalidate old course's dive list if it changed
        if (oldCourseId != null && oldCourseId != newCourseId) {
          ref.invalidate(courseDivesProvider(oldCourseId));
          ref.invalidate(courseDiveCountProvider(oldCourseId));
        }
        // Invalidate new course's dive list if set
        if (newCourseId != null) {
          ref.invalidate(courseDivesProvider(newCourseId));
          ref.invalidate(courseDiveCountProvider(newCourseId));
        }
        // Always invalidate the courseForDive provider for this dive
        ref.invalidate(courseForDiveProvider(savedDiveId));
      }

      // Record tide conditions if site has coordinates
      if (savedDiveId != null &&
          _selectedSite != null &&
          _selectedSite!.hasCoordinates) {
        try {
          final tideDataService = ref.read(tideDataServiceProvider);
          final calculator = await tideDataService.getCalculatorForLocation(
            _selectedSite!.location!.latitude,
            _selectedSite!.location!.longitude,
          );
          if (calculator != null) {
            // Record tide status at dive entry time
            final status = calculator.getStatus(entryDateTime);
            final tideRepository = ref.read(tideRecordRepositoryProvider);
            await tideRepository.createFromStatus(
              diveId: savedDiveId,
              status: status,
            );
          }
        } catch (e) {
          // Silently fail - tide recording is optional enhancement
          debugPrint('Failed to record tide data: $e');
        }
      }

      if (mounted && savedDiveId != null) {
        if (widget.embedded && widget.onSaved != null) {
          // In embedded mode, call the callback to update selection
          widget.onSaved!(savedDiveId);
        } else {
          // In standalone mode, navigate to the detail page
          context.go('/dives/$savedDiveId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveLog_edit_snackbar_errorSaving(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Get warning text for altitude dives.
  String? _getAltitudeWarning(UnitFormatter units) {
    final altitudeText = _altitudeController.text.trim();
    if (altitudeText.isEmpty) return null;
    final altitudeInUserUnits = double.tryParse(altitudeText);
    if (altitudeInUserUnits == null) return null;

    final altitudeMeters = units.altitudeToMeters(altitudeInUserUnits);
    final group = AltitudeGroup.fromAltitude(altitudeMeters);

    if (group == AltitudeGroup.seaLevel) return null;
    return '${group.displayName} - ${group.rangeDescription}';
  }

  /// Get warning color for altitude dives based on altitude group.
  Color? _getAltitudeWarningColor(UnitFormatter units) {
    final altitudeText = _altitudeController.text.trim();
    if (altitudeText.isEmpty) return null;
    final altitudeInUserUnits = double.tryParse(altitudeText);
    if (altitudeInUserUnits == null) return null;

    final altitudeMeters = units.altitudeToMeters(altitudeInUserUnits);
    final group = AltitudeGroup.fromAltitude(altitudeMeters);

    switch (group.warningLevel) {
      case AltitudeWarningLevel.none:
        return null;
      case AltitudeWarningLevel.info:
        return Colors.blue;
      case AltitudeWarningLevel.caution:
        return Colors.orange;
      case AltitudeWarningLevel.warning:
        return Colors.deepOrange;
      case AltitudeWarningLevel.severe:
        return Colors.red;
    }
  }
}
