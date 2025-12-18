import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../buddies/domain/entities/buddy.dart';
import '../../../buddies/presentation/providers/buddy_providers.dart';
import '../../../buddies/presentation/widgets/buddy_picker.dart';
import '../../../dive_sites/domain/entities/dive_site.dart';
import '../../../dive_sites/presentation/providers/site_providers.dart';
import '../../../equipment/domain/entities/equipment_item.dart';
import '../../../equipment/domain/entities/equipment_set.dart';
import '../../../equipment/presentation/providers/equipment_providers.dart';
import '../../../equipment/presentation/providers/equipment_set_providers.dart';
import '../../../marine_life/domain/entities/species.dart';
import '../../../marine_life/presentation/providers/species_providers.dart';
import '../../../dive_centers/domain/entities/dive_center.dart';
import '../../../dive_centers/presentation/widgets/dive_center_picker.dart';
import '../../../tags/domain/entities/tag.dart';
import '../../../tags/presentation/widgets/tag_input_widget.dart';
import '../../../trips/domain/entities/trip.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../trips/presentation/widgets/trip_picker.dart';
import '../../../dive_types/presentation/providers/dive_type_providers.dart';
import '../../domain/entities/dive.dart';
import '../../domain/entities/dive_weight.dart';
import '../providers/dive_providers.dart';
import '../widgets/tank_editor.dart';

class DiveEditPage extends ConsumerStatefulWidget {
  final String? diveId;

  const DiveEditPage({
    super.key,
    this.diveId,
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
  final _durationController = TextEditingController();
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
  List<Sighting> _sightings = [];
  List<EquipmentItem> _selectedEquipment = [];
  List<BuddyWithRole> _selectedBuddies = [];

  // Conditions fields
  CurrentDirection? _currentDirection;
  CurrentStrength? _currentStrength;
  EntryMethod? _entryMethod;
  EntryMethod? _exitMethod;
  WaterType? _waterType;
  final _swellHeightController = TextEditingController();

  // Weight fields - multiple weight entries per dive
  List<DiveWeight> _weights = [];

  // Tank data - list of tanks with multi-tank support
  List<DiveTank> _tanks = [];
  final _uuid = const Uuid();

  // Tags
  List<Tag> _selectedTags = [];

  // Existing dive for editing
  Dive? _existingDive;

  // Current device location (for new dives - to suggest nearby sites)
  LocationResult? _currentLocation;
  bool _isCapturingLocation = false;

  @override
  void initState() {
    super.initState();
    _entryDate = DateTime.now();
    _entryTime = TimeOfDay.now();

    // Initialize with one default tank
    _tanks = [
      DiveTank(
        id: _uuid.v4(),
        volume: 12.0,
        startPressure: 200,
        endPressure: 50,
        gasMix: const GasMix(),
        role: TankRole.backGas,
        order: 0,
      ),
    ];

    if (widget.isEditing) {
      _loadExistingDive();
    } else {
      // For new dives, capture GPS in the background to suggest nearby sites
      _captureLocationForNearby();
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
        
        setState(() {
          _existingDive = dive;
          // Use entryTime if available, otherwise fall back to dateTime
          final entryDateTime = dive.entryTime ?? dive.dateTime;
          _entryDate = entryDateTime;
          _entryTime = TimeOfDay.fromDateTime(entryDateTime);
          // Set exit time if available
          if (dive.exitTime != null) {
            _exitDate = dive.exitTime;
            _exitTime = TimeOfDay.fromDateTime(dive.exitTime!);
          } else if (dive.duration != null) {
            // Calculate exit time from entry + duration
            final exitDateTime = entryDateTime.add(dive.duration!);
            _exitDate = exitDateTime;
            _exitTime = TimeOfDay.fromDateTime(exitDateTime);
          }
          _durationController.text = dive.calculatedDuration?.inMinutes.toString() ?? '';
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

          // Load all tanks from the dive
          if (dive.tanks.isNotEmpty) {
            _tanks = List.from(dive.tanks);
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

          // Load weight entries (weights already stored in kg, conversion happens in display)
          _weights = List.from(dive.weights);
          // Migrate legacy single weight to weights list if needed
          if (_weights.isEmpty && dive.weightAmount != null && dive.weightAmount! > 0) {
            _weights.add(DiveWeight(
              id: _uuid.v4(),
              diveId: dive.id,
              weightType: dive.weightType ?? WeightType.belt,
              amountKg: dive.weightAmount!,
            ),);
          }

          // Load tags
          _selectedTags = List.from(dive.tags);
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
        includeGeocoding: false, // We just need coordinates for distance calculation
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
      setState(() => _sightings = sightings);
    }
  }

  Future<void> _loadBuddies() async {
    if (widget.diveId == null) return;
    final repository = ref.read(buddyRepositoryProvider);
    final buddies = await repository.getBuddiesForDive(widget.diveId!);
    if (mounted) {
      setState(() => _selectedBuddies = buddies);
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _maxDepthController.dispose();
    _avgDepthController.dispose();
    _waterTempController.dispose();
    _airTempController.dispose();
    _notesController.dispose();
    _swellHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Dive' : 'Log Dive'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Dive' : 'Log Dive'),
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
                  child: const Text('Save'),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDateTimeSection(),
            const SizedBox(height: 16),
            _buildSiteSection(),
            const SizedBox(height: 16),
            _buildTripSection(),
            const SizedBox(height: 16),
            _buildDiveCenterSection(),
            const SizedBox(height: 16),
            _buildDepthDurationSection(units),
            const SizedBox(height: 16),
            _buildTankSection(),
            const SizedBox(height: 16),
            _buildEquipmentSection(),
            const SizedBox(height: 16),
            _buildConditionsSection(units),
            const SizedBox(height: 16),
            _buildWeightSection(units),
            const SizedBox(height: 16),
            _buildBuddySection(),
            const SizedBox(height: 16),
            _buildRatingSection(),
            const SizedBox(height: 16),
            _buildSightingsSection(),
            const SizedBox(height: 16),
            _buildNotesSection(),
            const SizedBox(height: 16),
            _buildTagsSection(),
            const SizedBox(height: 32),
          ],
        ),
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
            Text('Tags', style: Theme.of(context).textTheme.titleMedium),
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

  Widget _buildDateTimeSection() {
    // Calculate duration from entry/exit times
    Duration? calculatedDuration;
    if (_exitDate != null && _exitTime != null) {
      final entryDateTime = DateTime(
        _entryDate.year,
        _entryDate.month,
        _entryDate.day,
        _entryTime.hour,
        _entryTime.minute,
      );
      final exitDateTime = DateTime(
        _exitDate!.year,
        _exitDate!.month,
        _exitDate!.day,
        _exitTime!.hour,
        _exitTime!.minute,
      );
      calculatedDuration = exitDateTime.difference(entryDateTime);
      if (calculatedDuration.isNegative) calculatedDuration = null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entry Time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectEntryDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('MMM d, y').format(_entryDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectEntryTime,
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(_entryTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Exit Time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectExitDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_exitDate != null 
                        ? DateFormat('MMM d, y').format(_exitDate!)
                        : 'Select',),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectExitTime,
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(_exitTime?.format(context) ?? 'Select'),
                  ),
                ),
              ],
            ),
            if (calculatedDuration != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Duration: ${calculatedDuration.inMinutes} min',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Show surface interval for existing dives
            if (widget.isEditing && widget.diveId != null)
              _buildSurfaceIntervalDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildSurfaceIntervalDisplay() {
    final surfaceIntervalAsync = ref.watch(surfaceIntervalProvider(widget.diveId!));
    
    return surfaceIntervalAsync.when(
      data: (interval) {
        if (interval == null) return const SizedBox.shrink();
        
        final hours = interval.inHours;
        final minutes = interval.inMinutes % 60;
        final intervalText = hours > 0 
            ? '${hours}h ${minutes}m' 
            : '${minutes}m';
        
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.waves,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Surface Interval: $intervalText',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSiteSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Dive Site', style: Theme.of(context).textTheme.titleMedium),
                if (_isCapturingLocation) ...[
                  const SizedBox(width: 8),
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
                    'Getting location...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                ] else if (_currentLocation != null && !widget.isEditing) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.my_location, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Nearby sites first',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showSitePicker,
                    icon: const Icon(Icons.location_on),
                    label: Text(
                      _selectedSite?.name ?? 'Select Dive Site',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                if (_selectedSite != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _selectedSite = null),
                    tooltip: 'Clear site',
                  ),
                ],
              ],
            ),
            if (_selectedSite != null && _selectedSite!.locationString.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _selectedSite!.locationString,
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

  void _showSitePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _SitePickerSheet(
          scrollController: scrollController,
          selectedSiteId: _selectedSite?.id,
          currentLocation: _currentLocation,
          onSiteSelected: (site) {
            setState(() => _selectedSite = site);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Widget _buildTripSection() {
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
            Text('Trip', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showTripPicker,
                    icon: const Icon(Icons.flight_takeoff),
                    label: Text(
                      _selectedTrip?.name ?? 'Select Trip',
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
                    tooltip: 'Clear trip',
                  ),
                ],
              ],
            ),
            if (_selectedTrip != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${DateFormat.yMMMd().format(_selectedTrip!.startDate)} - ${DateFormat.yMMMd().format(_selectedTrip!.endDate)}',
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
                    'Suggested: ${suggestedTrip.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedTrip = suggestedTrip),
                  child: const Text('Use'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showTripPicker() {
    showModalBottomSheet(
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
        ),
      ),
    );
  }

  Widget _buildDiveCenterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dive Center', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showDiveCenterPicker,
                    icon: const Icon(Icons.store),
                    label: Text(
                      _selectedDiveCenter?.name ?? 'Select Dive Center',
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
                    tooltip: 'Clear dive center',
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

  void _showDiveCenterPicker() {
    showModalBottomSheet(
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
        ),
      ),
    );
  }

  Widget _buildDepthDurationSection(UnitFormatter units) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Depth & Duration', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxDepthController,
                    decoration: InputDecoration(
                      labelText: 'Max Depth',
                      suffixText: units.depthSymbol,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _avgDepthController,
                    decoration: InputDecoration(
                      labelText: 'Avg Depth',
                      suffixText: units.depthSymbol,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duration',
                suffixText: 'min',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTankSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with tank count and add button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tanks (${_tanks.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: _addTank,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Tank'),
              ),
            ],
          ),
        ),
        // Tank editors
        ..._tanks.asMap().entries.map((entry) {
          final index = entry.key;
          final tank = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TankEditor(
              tank: tank,
              tankNumber: index + 1,
              canRemove: _tanks.length > 1,
              onChanged: (updatedTank) {
                setState(() {
                  _tanks[index] = updatedTank;
                });
              },
              onRemove: () => _removeTank(index),
            ),
          );
        }),
      ],
    );
  }

  void _addTank() {
    setState(() {
      _tanks.add(DiveTank(
        id: _uuid.v4(),
        volume: 12.0,
        startPressure: 200,
        gasMix: const GasMix(),
        role: _tanks.isEmpty ? TankRole.backGas : TankRole.stage,
        order: _tanks.length,
      ),);
    });
  }

  void _removeTank(int index) {
    setState(() {
      _tanks.removeAt(index);
      // Update order for remaining tanks
      for (var i = 0; i < _tanks.length; i++) {
        _tanks[i] = _tanks[i].copyWith(order: i);
      }
    });
  }

  Widget _buildEquipmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Equipment', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _showEquipmentSetPicker,
                      icon: const Icon(Icons.folder_special, size: 18),
                      label: const Text('Use Set'),
                    ),
                    TextButton.icon(
                      onPressed: _showEquipmentPicker,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No equipment selected',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Use Set" or "Add" to select equipment',
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
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                      label: const Text('Save as Set'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedEquipment.clear();
                        });
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
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
        return Icons.propane_tank;
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
        builder: (context, scrollController) => _EquipmentPickerSheet(
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
        builder: (context, scrollController) => _EquipmentSetPickerSheet(
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
        title: const Text('Save as Equipment Set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Save ${_selectedEquipment.length} item(s) as a new equipment set.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Set Name',
                hintText: 'e.g., Tropical Diving',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., Light gear for warm water',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a set name')),
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
                    SnackBar(content: Text('Equipment set "$name" created')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating set: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsSection(UnitFormatter units) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Conditions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final diveTypesAsync = ref.watch(diveTypeListNotifierProvider);
                return diveTypesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, st) => Text('Error loading dive types: $e'),
                  data: (diveTypes) {
                    // Ensure selected dive type exists in the list
                    final selectedExists = diveTypes.any((t) => t.id == _selectedDiveTypeId);
                    final effectiveValue = selectedExists ? _selectedDiveTypeId : 'recreational';

                    return DropdownButtonFormField<String>(
                      key: ValueKey('dive_type_${diveTypes.length}_$effectiveValue'),
                      initialValue: effectiveValue,
                      decoration: const InputDecoration(
                        labelText: 'Dive Type',
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
            DropdownButtonFormField<Visibility>(
              initialValue: _selectedVisibility,
              decoration: const InputDecoration(labelText: 'Visibility'),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _waterTempController,
                    decoration: InputDecoration(
                      labelText: 'Water Temp',
                      suffixText: units.temperatureSymbol,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _airTempController,
                    decoration: InputDecoration(
                      labelText: 'Air Temp',
                      suffixText: units.temperatureSymbol,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WaterType>(
              initialValue: _waterType,
              decoration: const InputDecoration(labelText: 'Water Type'),
              items: [
                const DropdownMenuItem<WaterType>(
                  value: null,
                  child: Text('Not specified'),
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
                    decoration: const InputDecoration(labelText: 'Current Direction'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<CurrentDirection>(
                        value: null,
                        child: Text('Not specified'),
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
                    decoration: const InputDecoration(labelText: 'Current Strength'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<CurrentStrength>(
                        value: null,
                        child: Text('Not specified'),
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
            TextFormField(
              controller: _swellHeightController,
              decoration: InputDecoration(
                labelText: 'Swell Height',
                suffixText: units.depthSymbol,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<EntryMethod>(
                    initialValue: _entryMethod,
                    decoration: const InputDecoration(labelText: 'Entry Method'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<EntryMethod>(
                        value: null,
                        child: Text('Not specified'),
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
                    decoration: const InputDecoration(labelText: 'Exit Method'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<EntryMethod>(
                        value: null,
                        child: Text('Not specified'),
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

  Widget _buildWeightSection(UnitFormatter units) {
    final totalWeight = _weights.fold(0.0, (sum, w) => sum + w.amountKg);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Weight', style: Theme.of(context).textTheme.titleMedium),
                if (_weights.isNotEmpty)
                  Text(
                    'Total: ${units.formatWeight(totalWeight)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                  _weights.add(DiveWeight(
                    id: _uuid.v4(),
                    diveId: widget.diveId ?? '',
                    weightType: WeightType.integrated,
                    amountKg: 0,
                  ),);
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Weight Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightEntryRow(int index, DiveWeight weight, UnitFormatter units) {
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
              decoration: const InputDecoration(
                labelText: 'Type',
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
              initialValue: displayAmount > 0 ? displayAmount.toStringAsFixed(1) : '',
              decoration: InputDecoration(
                labelText: units.weightSymbol,
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            tooltip: 'Remove',
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
            Text('Rating', style: Theme.of(context).textTheme.titleMedium),
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
                Text('Marine Life', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _showSpeciesPicker,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No marine life logged',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Add" to record sightings',
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
                    backgroundColor: _getCategoryColor(sighting.speciesCategory),
                    child: Icon(
                      _getCategoryIcon(sighting.speciesCategory),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(sighting.speciesName),
                  subtitle: sighting.notes.isNotEmpty
                      ? Text(sighting.notes, maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sighting.count > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'x${sighting.count}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
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

  IconData _getCategoryIcon(SpeciesCategory? category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Icons.set_meal;
      case SpeciesCategory.shark:
        return Icons.water;
      case SpeciesCategory.ray:
        return Icons.water;
      case SpeciesCategory.mammal:
        return Icons.pets;
      case SpeciesCategory.turtle:
        return Icons.water;
      case SpeciesCategory.invertebrate:
        return Icons.bug_report;
      case SpeciesCategory.coral:
        return Icons.nature;
      case SpeciesCategory.plant:
        return Icons.eco;
      case SpeciesCategory.other:
      case null:
        return Icons.water;
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
        builder: (context, scrollController) => _SpeciesPickerSheet(
          scrollController: scrollController,
          onSpeciesSelected: (species, count, notes) {
            setState(() {
              _sightings.add(Sighting(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                diveId: widget.diveId ?? '',
                speciesId: species.id,
                speciesName: species.commonName,
                speciesCategory: species.category,
                count: count,
                notes: notes,
              ),);
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
      builder: (context) => _EditSightingSheet(
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
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Add notes about this dive...',
                border: OutlineInputBorder(),
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
    final date = await showDatePicker(
      context: context,
      initialDate: _exitDate ?? _entryDate,
      firstDate: _entryDate,
      lastDate: _entryDate.add(const Duration(days: 1)),
    );
    if (date != null) {
      setState(() => _exitDate = date);
    }
  }

  Future<void> _selectExitTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _exitTime ?? TimeOfDay.fromDateTime(
        DateTime.now().add(const Duration(hours: 1)),
      ),
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
      final entryDateTime = DateTime(
        _entryDate.year,
        _entryDate.month,
        _entryDate.day,
        _entryTime.hour,
        _entryTime.minute,
      );

      // Build exit DateTime if set
      DateTime? exitDateTime;
      if (_exitDate != null && _exitTime != null) {
        exitDateTime = DateTime(
          _exitDate!.year,
          _exitDate!.month,
          _exitDate!.day,
          _exitTime!.hour,
          _exitTime!.minute,
        );
      }

      // Calculate duration from entry/exit times, or use manual input
      Duration? duration;
      if (exitDateTime != null) {
        duration = exitDateTime.difference(entryDateTime);
        if (duration.isNegative) duration = null;
      } else if (_durationController.text.isNotEmpty) {
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

      // Create dive entity
      final dive = Dive(
        id: widget.diveId ?? '',
        diveNumber: _existingDive?.diveNumber,
        dateTime: entryDateTime, // Keep for backward compatibility
        entryTime: entryDateTime,
        exitTime: exitDateTime,
        duration: duration,
        maxDepth: maxDepth,
        avgDepth: avgDepth,
        waterTemp: waterTemp,
        airTemp: airTemp,
        visibility: _selectedVisibility != Visibility.unknown ? _selectedVisibility : null,
        diveTypeId: _selectedDiveTypeId,
        notes: _notesController.text,
        rating: _rating > 0 ? _rating : null,
        site: _selectedSite,
        trip: _selectedTrip,
        diveCenter: _selectedDiveCenter,
        tanks: _tanks,
        equipment: _selectedEquipment,
        // Conditions fields
        currentDirection: _currentDirection,
        currentStrength: _currentStrength,
        swellHeight: swellHeight,
        entryMethod: _entryMethod,
        exitMethod: _exitMethod,
        waterType: _waterType,
        // Weight entries (multiple)
        weights: _weights,
        // Tags
        tags: _selectedTags,
        // Preserve favorite status when editing
        isFavorite: _existingDive?.isFavorite ?? false,
      );

      // Save using the notifier
      final notifier = ref.read(diveListNotifierProvider.notifier);
      String? savedDiveId;
      if (widget.isEditing) {
        await notifier.updateDive(dive);
        savedDiveId = widget.diveId;
      } else {
        final savedDive = await notifier.addDive(dive);
        savedDiveId = savedDive.id;
      }

      // Save sightings
      if (savedDiveId != null && _sightings.isNotEmpty) {
        final speciesRepository = ref.read(speciesRepositoryProvider);
        for (final sighting in _sightings) {
          // Only save new sightings (those without a proper ID or for new dives)
          if (!widget.isEditing || sighting.diveId.isEmpty) {
            await speciesRepository.addSighting(
              diveId: savedDiveId,
              speciesId: sighting.speciesId,
              count: sighting.count,
              notes: sighting.notes,
            );
          }
        }
      }

      // Save buddies
      if (savedDiveId != null) {
        final buddyRepository = ref.read(buddyRepositoryProvider);
        await buddyRepository.setBuddiesForDive(savedDiveId, _selectedBuddies);
        // Invalidate the buddies provider so the detail page shows updated data
        ref.invalidate(buddiesForDiveProvider(savedDiveId));
      }

      if (mounted && savedDiveId != null) {
        context.go('/dives/$savedDiveId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving dive: $e'),
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

}

/// Site picker bottom sheet with nearby site suggestions
class _SitePickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final String? selectedSiteId;
  final LocationResult? currentLocation;
  final void Function(DiveSite) onSiteSelected;

  const _SitePickerSheet({
    required this.scrollController,
    required this.selectedSiteId,
    this.currentLocation,
    required this.onSiteSelected,
  });

  /// Calculate distance from current location to a site in km
  double? _distanceToSite(DiveSite site) {
    if (currentLocation == null || site.location == null) return null;
    final distanceMeters = LocationService.instance.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      site.location!.latitude,
      site.location!.longitude,
    );
    return distanceMeters / 1000; // Convert to km
  }

  /// Format distance for display
  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m away';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)} km away';
    } else {
      return '${km.round()} km away';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Dive Site',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (currentLocation != null)
                    Row(
                      children: [
                        Icon(Icons.my_location, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Sorted by distance',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/sites/new');
                },
                icon: const Icon(Icons.add),
                label: const Text('New Dive Site'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: sitesAsync.when(
            data: (sites) {
              if (sites.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No dive sites yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/sites/new');
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Dive Site'),
                      ),
                    ],
                  ),
                );
              }

              // Sort sites by distance if we have current location
              List<_SiteWithDistance> sortedSites;
              if (currentLocation != null) {
                sortedSites = sites.map((site) {
                  return _SiteWithDistance(site, _distanceToSite(site));
                }).toList();
                // Sort: sites with distance first (by distance), then sites without GPS
                sortedSites.sort((a, b) {
                  if (a.distance == null && b.distance == null) return 0;
                  if (a.distance == null) return 1;
                  if (b.distance == null) return 1;
                  return a.distance!.compareTo(b.distance!);
                });
              } else {
                sortedSites = sites.map((site) => _SiteWithDistance(site, null)).toList();
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: sortedSites.length,
                itemBuilder: (context, index) {
                  final siteWithDist = sortedSites[index];
                  final site = siteWithDist.site;
                  final distance = siteWithDist.distance;
                  final isSelected = site.id == selectedSiteId;
                  final isNearby = distance != null && distance < 50; // Within 50km

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? colorScheme.primaryContainer
                          : isNearby
                              ? colorScheme.tertiaryContainer
                              : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        isNearby ? Icons.near_me : Icons.location_on,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : isNearby
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(site.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (site.locationString.isNotEmpty)
                          Text(site.locationString),
                        if (distance != null)
                          Text(
                            _formatDistance(distance),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isNearby ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
                                  fontWeight: isNearby ? FontWeight.w600 : null,
                                ),
                          ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                          )
                        : null,
                    onTap: () => onSiteSelected(site),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error loading sites: $error'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Helper class to hold a site with its calculated distance
class _SiteWithDistance {
  final DiveSite site;
  final double? distance;

  _SiteWithDistance(this.site, this.distance);
}

/// Species picker bottom sheet with search
class _SpeciesPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final void Function(Species species, int count, String notes) onSpeciesSelected;

  const _SpeciesPickerSheet({
    required this.scrollController,
    required this.onSpeciesSelected,
  });

  @override
  ConsumerState<_SpeciesPickerSheet> createState() => _SpeciesPickerSheetState();
}

class _SpeciesPickerSheetState extends ConsumerState<_SpeciesPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SpeciesCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speciesAsync = _searchQuery.isEmpty && _selectedCategory == null
        ? ref.watch(allSpeciesProvider)
        : _selectedCategory != null
            ? ref.watch(speciesByCategoryProvider(_selectedCategory!))
            : ref.watch(speciesSearchProvider(_searchQuery));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Marine Life',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search species...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                if (value.isNotEmpty) {
                  _selectedCategory = null;
                }
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryChip(null, 'All'),
              ...SpeciesCategory.values.map((category) =>
                _buildCategoryChip(category, category.displayName),),
            ],
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: speciesAsync.when(
            data: (speciesList) {
              if (speciesList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.water,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No species found'
                            : 'No species available',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () => _addCustomSpecies(_searchQuery),
                          child: Text('Add "$_searchQuery" as new species'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: speciesList.length,
                itemBuilder: (context, index) {
                  final species = speciesList[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(species.category),
                      child: Icon(
                        _getCategoryIcon(species.category),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(species.commonName),
                    subtitle: species.scientificName != null
                        ? Text(
                            species.scientificName!,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          )
                        : null,
                    trailing: Text(
                      species.category.displayName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () => _showSightingDetails(species),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error loading species: $error'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(SpeciesCategory? category, String label) {
    final isSelected = _selectedCategory == category && _searchQuery.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
            if (selected) {
              _searchController.clear();
              _searchQuery = '';
            }
          });
        },
      ),
    );
  }

  Color _getCategoryColor(SpeciesCategory category) {
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
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(SpeciesCategory category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Icons.set_meal;
      case SpeciesCategory.shark:
        return Icons.water;
      case SpeciesCategory.ray:
        return Icons.water;
      case SpeciesCategory.mammal:
        return Icons.pets;
      case SpeciesCategory.turtle:
        return Icons.water;
      case SpeciesCategory.invertebrate:
        return Icons.bug_report;
      case SpeciesCategory.coral:
        return Icons.nature;
      case SpeciesCategory.plant:
        return Icons.eco;
      case SpeciesCategory.other:
        return Icons.water;
    }
  }

  void _showSightingDetails(Species species) {
    int count = 1;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(species.commonName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: count > 1
                        ? () => setDialogState(() => count--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setDialogState(() => count++),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g., size, behavior, location...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onSpeciesSelected(species, count, notesController.text);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomSpecies(String name) async {
    final repository = ref.read(speciesRepositoryProvider);
    final species = await repository.getOrCreateSpecies(
      commonName: name,
      category: SpeciesCategory.other,
    );
    if (mounted) {
      _showSightingDetails(species);
    }
  }
}

/// Edit sighting sheet
class _EditSightingSheet extends StatefulWidget {
  final Sighting sighting;
  final void Function(Sighting) onSave;
  final VoidCallback onDelete;

  const _EditSightingSheet({
    required this.sighting,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditSightingSheet> createState() => _EditSightingSheetState();
}

class _EditSightingSheetState extends State<_EditSightingSheet> {
  late int _count;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _count = widget.sighting.count;
    _notesController = TextEditingController(text: widget.sighting.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.sighting.speciesName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Remove Sighting?'),
                      content: Text(
                        'Remove ${widget.sighting.speciesName} from this dive?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            widget.onDelete();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Count',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                icon: const Icon(Icons.remove),
                onPressed: _count > 1 ? () => setState(() => _count--) : null,
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_count',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _count++),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Size, behavior, location...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              widget.onSave(widget.sighting.copyWith(
                count: _count,
                notes: _notesController.text,
              ),);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

/// Equipment picker bottom sheet
class _EquipmentPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final Set<String> selectedEquipmentIds;
  final void Function(EquipmentItem) onEquipmentSelected;

  const _EquipmentPickerSheet({
    required this.scrollController,
    required this.selectedEquipmentIds,
    required this.onEquipmentSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipmentAsync = ref.watch(allEquipmentProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Equipment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: equipmentAsync.when(
            data: (equipmentList) {
              // Filter out already selected equipment
              final available = equipmentList
                  .where((e) => !selectedEquipmentIds.contains(e.id))
                  .toList();

              if (available.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        equipmentList.isEmpty
                            ? 'No equipment yet'
                            : 'All equipment already selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        equipmentList.isEmpty
                            ? 'Add equipment from the Equipment tab'
                            : 'Remove items to add different ones',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: available.length,
                itemBuilder: (context, index) {
                  final equipment = available[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        _getEquipmentIcon(equipment.type),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(equipment.name),
                    subtitle: Text(equipment.type.displayName),
                    onTap: () => onEquipmentSelected(equipment),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error loading equipment: $error'),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getEquipmentIcon(EquipmentType type) {
    switch (type) {
      case EquipmentType.regulator:
        return Icons.air;
      case EquipmentType.bcd:
        return Icons.checkroom;
      case EquipmentType.wetsuit:
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
        return Icons.propane_tank;
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
}

/// Equipment set picker bottom sheet
class _EquipmentSetPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final void Function(EquipmentSet set, List<EquipmentItem> items) onSetSelected;

  const _EquipmentSetPickerSheet({
    required this.scrollController,
    required this.onSetSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(equipmentSetsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Use Equipment Set',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: setsAsync.when(
            data: (sets) {
              if (sets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_special_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No equipment sets yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create sets in Equipment > Sets',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: sets.length,
                itemBuilder: (context, index) {
                  final set = sets[index];
                  return _EquipmentSetTile(
                    set: set,
                    onTap: (items) => onSetSelected(set, items),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error loading equipment sets: $error'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Individual equipment set tile that loads its items
class _EquipmentSetTile extends ConsumerWidget {
  final EquipmentSet set;
  final void Function(List<EquipmentItem> items) onTap;

  const _EquipmentSetTile({
    required this.set,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setWithItemsAsync = ref.watch(equipmentSetWithItemsProvider(set.id));

    return setWithItemsAsync.when(
      data: (setWithItems) {
        if (setWithItems == null) {
          return const SizedBox.shrink();
        }
        final items = setWithItems.items ?? [];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.folder_special,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(set.name),
          subtitle: Text(
            items.isEmpty
                ? 'Empty set'
                : '${items.length} item${items.length == 1 ? '' : 's'}: ${items.map((e) => e.name).join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: items.isEmpty ? null : () => onTap(items),
        );
      },
      loading: () => ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: Text(set.name),
        subtitle: const Text('Loading...'),
      ),
      error: (_, __) => ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        title: Text(set.name),
        subtitle: const Text('Error loading items'),
      ),
    );
  }
}
