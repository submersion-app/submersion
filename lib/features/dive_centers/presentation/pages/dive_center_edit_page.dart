import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/l10n/l10n_extension.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveCenters_error_saving(e.toString())),
          ),
        );
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
                appBar: AppBar(
                  title: Text(context.l10n.diveCenters_title_edit),
                ),
                body: const Center(child: CircularProgressIndicator()),
              ),
        error: (error, _) => widget.embedded
            ? Center(
                child: Text(
                  context.l10n.diveCenters_error_generic(error.toString()),
                ),
              )
            : Scaffold(
                appBar: AppBar(
                  title: Text(context.l10n.diveCenters_title_edit),
                ),
                body: Center(
                  child: Text(
                    context.l10n.diveCenters_error_generic(error.toString()),
                  ),
                ),
              ),
        data: (center) {
          if (center == null) {
            return widget.embedded
                ? Center(child: Text(context.l10n.diveCenters_error_notFound))
                : Scaffold(
                    appBar: AppBar(
                      title: Text(context.l10n.diveCenters_title_edit),
                    ),
                    body: Center(
                      child: Text(context.l10n.diveCenters_error_notFound),
                    ),
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
            context.l10n.diveCenters_section_basicInfo,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.diveCenters_field_nameRequired,
              hintText: context.l10n.diveCenters_hint_name,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.diveCenters_validation_nameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Rating
          _buildRatingSelector(),

          const SizedBox(height: 24),

          // Address Section
          Text(
            context.l10n.diveCenters_section_address,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diveCenters_hint_addressDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _streetController,
            focusNode: _streetFocusNode,
            decoration: InputDecoration(
              labelText: context.l10n.diveCenters_field_street,
              hintText: context.l10n.diveCenters_hint_street,
              border: const OutlineInputBorder(),
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
                  decoration: InputDecoration(
                    labelText: context.l10n.diveCenters_field_city,
                    hintText: context.l10n.diveCenters_hint_city,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _stateProvinceController,
                  focusNode: _stateProvinceFocusNode,
                  decoration: InputDecoration(
                    labelText: context.l10n.diveCenters_field_stateProvince,
                    hintText: context.l10n.diveCenters_hint_stateProvince,
                    border: const OutlineInputBorder(),
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
                  decoration: InputDecoration(
                    labelText: context.l10n.diveCenters_field_postalCode,
                    hintText: context.l10n.diveCenters_hint_postalCode,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _countryController,
                  focusNode: _countryFocusNode,
                  decoration: InputDecoration(
                    labelText: context.l10n.diveCenters_field_country,
                    hintText: context.l10n.diveCenters_hint_country,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Affiliations Section
          Text(
            context.l10n.diveCenters_section_affiliations,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diveCenters_hint_affiliationsDescription,
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
            context.l10n.diveCenters_section_contactInfo,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: context.l10n.diveCenters_label_phone,
              hintText: context.l10n.diveCenters_hint_phone,
              prefixIcon: const Icon(Icons.phone_outlined),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: context.l10n.diveCenters_label_email,
              hintText: context.l10n.diveCenters_hint_email,
              prefixIcon: const Icon(Icons.email_outlined),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null &&
                  value.isNotEmpty &&
                  !RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                return context.l10n.diveCenters_validation_invalidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _websiteController,
            decoration: InputDecoration(
              labelText: context.l10n.diveCenters_label_website,
              hintText: context.l10n.diveCenters_hint_website,
              prefixIcon: const Icon(Icons.language_outlined),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),

          const SizedBox(height: 24),

          // Coordinates Section
          _buildGpsSection(context),

          const SizedBox(height: 24),

          // Notes Section
          Text(
            context.l10n.diveCenters_section_notes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: context.l10n.diveCenters_section_notes,
              hintText: context.l10n.diveCenters_hint_notes,
              border: const OutlineInputBorder(),
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
        title: Text(
          isEditing
              ? context.l10n.diveCenters_title_edit
              : context.l10n.diveCenters_title_add,
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.common_action_save),
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
              isEditing
                  ? context.l10n.diveCenters_title_edit
                  : context.l10n.diveCenters_title_add,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _handleCancel,
            child: Text(context.l10n.common_action_cancel),
          ),
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
                : Text(context.l10n.common_action_save),
          ),
        ],
      ),
    );
  }

  Future<void> _showDiscardDialog() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveCenters_dialog_discardTitle),
        content: Text(context.l10n.diveCenters_dialog_discardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.diveCenters_dialog_keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.diveCenters_dialog_discard),
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
                  context.l10n.diveCenters_section_gpsCoordinates,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveCenters_hint_gpsDescription,
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
                        ? context.l10n.diveCenters_action_gettingLocation
                        : context.l10n.diveCenters_action_useMyLocation,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFromMap,
                  icon: const Icon(Icons.map, size: 18),
                  label: Text(context.l10n.diveCenters_action_pickFromMap),
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
                    _isGeocoding
                        ? context.l10n.diveCenters_action_lookingUp
                        : context.l10n.diveCenters_action_lookupFromAddress,
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
                    decoration: InputDecoration(
                      labelText: context.l10n.diveCenters_field_latitude,
                      hintText: context.l10n.diveCenters_hint_latitude,
                      border: const OutlineInputBorder(),
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
                              .diveCenters_validation_invalidLatitude;
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
                      labelText: context.l10n.diveCenters_field_longitude,
                      hintText: context.l10n.diveCenters_hint_longitude,
                      border: const OutlineInputBorder(),
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
                              .diveCenters_validation_invalidLongitude;
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
        Text(
          context.l10n.diveCenters_field_rating,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...List.generate(
              5,
              (index) => IconButton(
                tooltip: '${index + 1} star${index > 0 ? 's' : ''}',
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
                child: Text(context.l10n.diveCenters_action_clearRating),
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
                    ? context.l10n.diveCenters_error_locationPermission
                    : context.l10n.diveCenters_error_locationUnavailable,
              ),
              action: isMobile
                  ? SnackBarAction(
                      label: context.l10n.diveCenters_action_settings,
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
              result.accuracy != null
                  ? context.l10n
                        .diveCenters_snackbar_locationCapturedWithAccuracy(
                          result.accuracy!.toStringAsFixed(0),
                        )
                  : context.l10n.diveCenters_snackbar_locationCaptured,
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
        SnackBar(
          content: Text(
            context.l10n.diveCenters_snackbar_locationSelectedFromMap,
          ),
        ),
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
        SnackBar(
          content: Text(context.l10n.diveCenters_error_noAddressForLookup),
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
            SnackBar(
              content: Text(context.l10n.diveCenters_error_geocodeFailed),
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
            content: Text(context.l10n.diveCenters_snackbar_coordinatesFound),
          ),
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
