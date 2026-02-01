import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

class DiveCenterEditPage extends ConsumerStatefulWidget {
  final String? centerId;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  const DiveCenterEditPage({
    super.key,
    this.centerId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  });

  @override
  ConsumerState<DiveCenterEditPage> createState() => _DiveCenterEditPageState();
}

class _DiveCenterEditPageState extends ConsumerState<DiveCenterEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateProvinceController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _notesController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  double? _rating;
  List<String> _selectedAffiliations = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasChanges = false;
  bool _isGettingLocation = false;
  bool _isGeocoding = false;

  // Focus nodes for auto-geocoding on blur
  final _streetFocusNode = FocusNode();
  final _cityFocusNode = FocusNode();
  final _stateProvinceFocusNode = FocusNode();
  final _postalCodeFocusNode = FocusNode();
  final _countryFocusNode = FocusNode();

  static const List<String> _availableAffiliations = [
    'PADI',
    'SSI',
    'NAUI',
    'SDI/TDI',
    'GUE',
    'RAID',
    'BSAC',
    'CMAS',
    'IANTD',
    'PSAI',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateProvinceController = TextEditingController();
    _postalCodeController = TextEditingController();
    _countryController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _websiteController = TextEditingController();
    _notesController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();

    // Add listeners for change tracking
    _nameController.addListener(_onFieldChanged);
    _streetController.addListener(_onFieldChanged);
    _cityController.addListener(_onFieldChanged);
    _stateProvinceController.addListener(_onFieldChanged);
    _postalCodeController.addListener(_onFieldChanged);
    _countryController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _websiteController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
    _latitudeController.addListener(_onFieldChanged);
    _longitudeController.addListener(_onFieldChanged);

    // Add focus listeners for auto-geocoding when leaving address fields
    _streetFocusNode.addListener(_onAddressFieldFocusChange);
    _cityFocusNode.addListener(_onAddressFieldFocusChange);
    _stateProvinceFocusNode.addListener(_onAddressFieldFocusChange);
    _postalCodeFocusNode.addListener(_onAddressFieldFocusChange);
    _countryFocusNode.addListener(_onAddressFieldFocusChange);
  }

  void _onAddressFieldFocusChange() {
    // Check if any address field just lost focus (all have hasFocus == false now)
    final anyAddressFieldHasFocus =
        _streetFocusNode.hasFocus ||
        _cityFocusNode.hasFocus ||
        _stateProvinceFocusNode.hasFocus ||
        _postalCodeFocusNode.hasFocus ||
        _countryFocusNode.hasFocus;

    // Only trigger when all address fields have lost focus
    if (!anyAddressFieldHasFocus) {
      _onAddressFieldBlur();
    }
  }

  void _onFieldChanged() {
    if (_isInitialized && !_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateProvinceController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _streetFocusNode.dispose();
    _cityFocusNode.dispose();
    _stateProvinceFocusNode.dispose();
    _postalCodeFocusNode.dispose();
    _countryFocusNode.dispose();
    super.dispose();
  }

  void _initializeFromCenter(DiveCenter center) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = center.name;
    _streetController.text = center.street ?? '';
    _cityController.text = center.city ?? '';
    _stateProvinceController.text = center.stateProvince ?? '';
    _postalCodeController.text = center.postalCode ?? '';
    _countryController.text = center.country ?? '';
    _phoneController.text = center.phone ?? '';
    _emailController.text = center.email ?? '';
    _websiteController.text = center.website ?? '';
    _notesController.text = center.notes;
    _latitudeController.text = center.latitude?.toStringAsFixed(6) ?? '';
    _longitudeController.text = center.longitude?.toStringAsFixed(6) ?? '';
    _rating = center.rating;
    _selectedAffiliations = List.from(center.affiliations);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get the current diver ID - preserve existing for edits, get fresh for new centers
      final existingCenter = widget.centerId != null
          ? ref.read(diveCenterByIdProvider(widget.centerId!)).value
          : null;
      final diverId =
          existingCenter?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      final now = DateTime.now();
      final center = DiveCenter(
        id: widget.centerId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        street: _streetController.text.trim().isEmpty
            ? null
            : _streetController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        stateProvince: _stateProvinceController.text.trim().isEmpty
            ? null
            : _stateProvinceController.text.trim(),
        postalCode: _postalCodeController.text.trim().isEmpty
            ? null
            : _postalCodeController.text.trim(),
        latitude: _latitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_latitudeController.text.trim()),
        longitude: _longitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_longitudeController.text.trim()),
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        affiliations: _selectedAffiliations,
        rating: _rating,
        notes: _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final notifier = ref.read(diveCenterListNotifierProvider.notifier);
      String savedId;

      if (widget.centerId != null) {
        await notifier.updateDiveCenter(center);
        savedId = widget.centerId!;
      } else {
        final newCenter = await notifier.addDiveCenter(center);
        savedId = newCenter.id;
      }

      if (mounted) {
        if (widget.embedded) {
          widget.onSaved?.call(savedId);
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving dive center: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final isEditing = widget.centerId != null;

    if (isEditing) {
      final centerAsync = ref.watch(diveCenterByIdProvider(widget.centerId!));

      return centerAsync.when(
        loading: () => widget.embedded
            ? const Center(child: CircularProgressIndicator())
            : Scaffold(
                appBar: AppBar(title: const Text('Edit Dive Center')),
                body: const Center(child: CircularProgressIndicator()),
              ),
        error: (error, _) => widget.embedded
            ? Center(child: Text('Error: $error'))
            : Scaffold(
                appBar: AppBar(title: const Text('Edit Dive Center')),
                body: Center(child: Text('Error: $error')),
              ),
        data: (center) {
          if (center == null) {
            return widget.embedded
                ? const Center(child: Text('Dive center not found'))
                : Scaffold(
                    appBar: AppBar(title: const Text('Edit Dive Center')),
                    body: const Center(child: Text('Dive center not found')),
                  );
          }
          _initializeFromCenter(center);
          return _buildForm(context, isEditing: true);
        },
      );
    }

    // For new dive centers, mark as initialized immediately
    if (!_isInitialized) {
      _isInitialized = true;
    }

    return _buildForm(context, isEditing: false);
  }

  Widget _buildForm(BuildContext context, {required bool isEditing}) {
    final body = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic Info Section
          Text(
            'Basic Information',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name *',
              hintText: 'Enter dive center name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Rating
          _buildRatingSelector(),

          const SizedBox(height: 24),

          // Address Section
          Text('Address', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Optional street address for navigation',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _streetController,
            focusNode: _streetFocusNode,
            decoration: const InputDecoration(
              labelText: 'Street Address',
              hintText: 'e.g., 123 Beach Road',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cityController,
                  focusNode: _cityFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    hintText: 'e.g., Phuket',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _stateProvinceController,
                  focusNode: _stateProvinceFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'State/Province',
                    hintText: 'e.g., Phuket',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _postalCodeController,
                  focusNode: _postalCodeFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Postal Code',
                    hintText: 'e.g., 83100',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _countryController,
                  focusNode: _countryFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    hintText: 'e.g., Thailand',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Affiliations Section
          Text('Affiliations', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Select training agencies this center is affiliated with',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableAffiliations.map((affiliation) {
              final isSelected = _selectedAffiliations.contains(affiliation);
              return FilterChip(
                label: Text(affiliation),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedAffiliations.add(affiliation);
                    } else {
                      _selectedAffiliations.remove(affiliation);
                    }
                    _hasChanges = true;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Contact Section
          Text(
            'Contact Information',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              hintText: '+1 234 567 890',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'info@divecenter.com',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null &&
                  value.isNotEmpty &&
                  !RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _websiteController,
            decoration: const InputDecoration(
              labelText: 'Website',
              hintText: 'www.divecenter.com',
              prefixIcon: Icon(Icons.language_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),

          const SizedBox(height: 24),

          // Coordinates Section
          _buildGpsSection(context),

          const SizedBox(height: 24),

          // Notes Section
          Text('Notes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Any additional information...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );

    if (widget.embedded) {
      return PopScope(
        canPop: !_hasChanges,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _hasChanges) {
            _showDiscardDialog();
          }
        },
        child: Column(
          children: [
            _buildEmbeddedHeader(context, isEditing: isEditing),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Dive Center' : 'Add Dive Center'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context, {required bool isEditing}) {
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEditing ? Icons.edit : Icons.add,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Edit Dive Center' : 'Add Dive Center',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: _handleCancel, child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDiscardDialog() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) {
      _handleCancel();
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
                  'GPS Coordinates',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a location method or enter coordinates manually',
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
                    _isGettingLocation ? 'Getting...' : 'Use My Location',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFromMap,
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Pick from Map'),
                ),
                OutlinedButton.icon(
                  onPressed: _isGeocoding ? null : _geocodeFromAddress,
                  icon: _isGeocoding
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text(
                    _isGeocoding ? 'Looking up...' : 'Lookup from Address',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'e.g., 10.4613',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'Invalid latitude';
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
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'e.g., 99.8359',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final lng = double.tryParse(value);
                        if (lng == null || lng < -180 || lng > 180) {
                          return 'Invalid longitude';
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

  Widget _buildRatingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rating', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            ...List.generate(
              5,
              (index) => IconButton(
                onPressed: () {
                  setState(() {
                    if (_rating == index + 1) {
                      _rating = null;
                    } else {
                      _rating = (index + 1).toDouble();
                    }
                    _hasChanges = true;
                  });
                },
                icon: Icon(
                  _rating != null && index < _rating!
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber.shade700,
                  size: 32,
                ),
              ),
            ),
            if (_rating != null) ...[
              const SizedBox(width: 8),
              Text(
                _rating!.toStringAsFixed(0),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => setState(() {
                  _rating = null;
                  _hasChanges = true;
                }),
                child: const Text('Clear'),
              ),
            ],
          ],
        ),
      ],
    );
  }

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
                    ? 'Unable to get location. Please check permissions.'
                    : 'Unable to get location. Location services may not be available.',
              ),
              action: isMobile
                  ? SnackBarAction(
                      label: 'Settings',
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
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location captured${result.accuracy != null ? ' (±${result.accuracy!.toStringAsFixed(0)}m)' : ''}',
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location selected from map')),
      );
    }
  }

  /// Build full address string from address fields for geocoding
  String _buildFullAddress() {
    final parts = <String>[];
    if (_streetController.text.trim().isNotEmpty) {
      parts.add(_streetController.text.trim());
    }
    if (_cityController.text.trim().isNotEmpty) {
      parts.add(_cityController.text.trim());
    }
    if (_stateProvinceController.text.trim().isNotEmpty) {
      parts.add(_stateProvinceController.text.trim());
    }
    if (_postalCodeController.text.trim().isNotEmpty) {
      parts.add(_postalCodeController.text.trim());
    }
    if (_countryController.text.trim().isNotEmpty) {
      parts.add(_countryController.text.trim());
    }
    return parts.join(', ');
  }

  Future<void> _geocodeFromAddress() async {
    final address = _buildFullAddress();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an address to look up coordinates'),
        ),
      );
      return;
    }

    setState(() => _isGeocoding = true);

    try {
      final result = await LocationService.instance.forwardGeocode(address);

      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find coordinates for this address'),
            ),
          );
        }
        return;
      }

      setState(() {
        _latitudeController.text = result.latitude.toStringAsFixed(6);
        _longitudeController.text = result.longitude.toStringAsFixed(6);
        _hasChanges = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coordinates found from address')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  Future<void> _onAddressFieldBlur() async {
    // Only auto-geocode if we have address data but no coordinates
    final hasAddress = _buildFullAddress().isNotEmpty;
    final hasCoordinates =
        _latitudeController.text.trim().isNotEmpty &&
        _longitudeController.text.trim().isNotEmpty;

    if (hasAddress && !hasCoordinates && !_isGeocoding) {
      await _geocodeFromAddress();
    }
  }
}
