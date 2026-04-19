import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';

class TripEditPage extends ConsumerStatefulWidget {
  final String? tripId;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  const TripEditPage({
    super.key,
    this.tripId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
  });

  @override
  ConsumerState<TripEditPage> createState() => _TripEditPageState();
}

class _TripEditPageState extends ConsumerState<TripEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _resortController = TextEditingController();
  final _liveaboardController = TextEditingController();
  final _notesController = TextEditingController();

  TripType _tripType = TripType.shore;
  final _vesselNameController = TextEditingController();
  final _operatorController = TextEditingController();
  final _cabinTypeController = TextEditingController();
  final _capacityController = TextEditingController();
  final _embarkPortController = TextEditingController();
  final _disembarkPortController = TextEditingController();
  String? _vesselType;
  LiveaboardDetails? _originalLiveaboardDetails;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isShared = false;
  Trip? _originalTrip;

  bool get isEditing => widget.tripId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadTrip();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final shareByDefault = await ref.read(shareByDefaultProvider.future);
        if (!mounted) return;
        setState(() => _isShared = shareByDefault);
      });
    }
    _nameController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    _resortController.addListener(_onFieldChanged);
    _liveaboardController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
    _vesselNameController.addListener(_onFieldChanged);
    _operatorController.addListener(_onFieldChanged);
    _cabinTypeController.addListener(_onFieldChanged);
    _capacityController.addListener(_onFieldChanged);
    _embarkPortController.addListener(_onFieldChanged);
    _disembarkPortController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges && !_isLoading) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadTrip() async {
    setState(() => _isLoading = true);
    try {
      final trip = await ref
          .read(tripRepositoryProvider)
          .getTripById(widget.tripId!);
      if (trip != null && mounted) {
        _originalTrip = trip;
        _nameController.text = trip.name;
        _locationController.text = trip.location ?? '';
        _resortController.text = trip.resortName ?? '';
        _liveaboardController.text = trip.liveaboardName ?? '';
        _notesController.text = trip.notes;
        _tripType = trip.tripType;

        // Load liveaboard details if applicable
        if (trip.isLiveaboard) {
          final liveaboardRepo = LiveaboardDetailsRepository();
          final details = await liveaboardRepo.getByTripId(trip.id);
          if (details != null) {
            _originalLiveaboardDetails = details;
            _vesselNameController.text = details.vesselName;
            _operatorController.text = details.operatorName ?? '';
            _vesselType = details.vesselType;
            _cabinTypeController.text = details.cabinType ?? '';
            _capacityController.text = details.capacity?.toString() ?? '';
            _embarkPortController.text = details.embarkPort ?? '';
            _disembarkPortController.text = details.disembarkPort ?? '';
          }
        }

        setState(() {
          _startDate = trip.startDate;
          _endDate = trip.endDate;
          _isShared = trip.isShared;
          _isLoading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_edit_snackBar_errorLoading('$e')),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _resortController.dispose();
    _liveaboardController.dispose();
    _notesController.dispose();
    _vesselNameController.dispose();
    _operatorController.dispose();
    _cabinTypeController.dispose();
    _capacityController.dispose();
    _embarkPortController.dispose();
    _disembarkPortController.dispose();
    super.dispose();
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
    final dateFormat = DateFormat.yMMMd();

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Trip type selector
                  SegmentedButton<TripType>(
                    segments: [
                      ButtonSegment(
                        value: TripType.shore,
                        label: Text(context.l10n.trips_type_shore),
                      ),
                      ButtonSegment(
                        value: TripType.liveaboard,
                        label: Text(context.l10n.trips_type_liveaboard),
                      ),
                      ButtonSegment(
                        value: TripType.resort,
                        label: Text(context.l10n.trips_type_resort),
                      ),
                      ButtonSegment(
                        value: TripType.dayTrip,
                        label: Text(context.l10n.trips_type_dayTrip),
                      ),
                    ],
                    selected: {_tripType},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _tripType = selected.first;
                        _hasChanges = true;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_tripName,
                      prefixIcon: const Icon(Icons.flight_takeoff),
                      hintText: context.l10n.trips_edit_hint_tripName,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.trips_edit_validation_nameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Date section header
                  Text(
                    context.l10n.trips_edit_sectionTitle_dates,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Start date
                  Semantics(
                    button: true,
                    label:
                        '${context.l10n.trips_edit_label_startDate}: ${dateFormat.format(_startDate)}. Tap to change',
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(context.l10n.trips_edit_label_startDate),
                      subtitle: Text(dateFormat.format(_startDate)),
                      onTap: () => _selectDate(context, true),
                      contentPadding: EdgeInsets.zero,
                      trailing: const Icon(Icons.edit),
                    ),
                  ),

                  // End date
                  Semantics(
                    button: true,
                    label:
                        '${context.l10n.trips_edit_label_endDate}: ${dateFormat.format(_endDate)}. Tap to change',
                    child: ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(context.l10n.trips_edit_label_endDate),
                      subtitle: Text(dateFormat.format(_endDate)),
                      onTap: () => _selectDate(context, false),
                      contentPadding: EdgeInsets.zero,
                      trailing: const Icon(Icons.edit),
                    ),
                  ),

                  // Duration display
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 40),
                    child: Text(
                      context.l10n.trips_edit_durationDays(
                        _endDate.difference(_startDate).inDays + 1,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location section header
                  Text(
                    context.l10n.trips_edit_sectionTitle_location,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location field
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_location,
                      prefixIcon: const Icon(Icons.place),
                      hintText: context.l10n.trips_edit_hint_location,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Resort field
                  TextFormField(
                    controller: _resortController,
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_resortName,
                      prefixIcon: const Icon(Icons.hotel),
                      hintText: context.l10n.trips_edit_hint_resortName,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Liveaboard field
                  TextFormField(
                    controller: _liveaboardController,
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_liveaboardName,
                      prefixIcon: const Icon(Icons.sailing),
                      hintText: context.l10n.trips_edit_hint_liveaboardName,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),

                  // Liveaboard vessel details (shown only when type is liveaboard)
                  if (_tripType == TripType.liveaboard) ...[
                    const SizedBox(height: 24),
                    // Vessel section header
                    Text(
                      context.l10n.trips_edit_sectionTitle_vessel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Vessel name (required for liveaboard)
                    TextFormField(
                      controller: _vesselNameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.trips_edit_label_vesselName,
                        prefixIcon: const Icon(Icons.directions_boat),
                        hintText: context.l10n.trips_edit_hint_vesselName,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (_tripType == TripType.liveaboard &&
                            (value == null || value.trim().isEmpty)) {
                          return context
                              .l10n
                              .trips_edit_validation_vesselRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Operator
                    TextFormField(
                      controller: _operatorController,
                      decoration: InputDecoration(
                        labelText: context.l10n.trips_edit_label_operatorName,
                        prefixIcon: const Icon(Icons.business),
                        hintText: context.l10n.trips_edit_hint_operatorName,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Vessel type dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _vesselType,
                      decoration: InputDecoration(
                        labelText: context.l10n.trips_edit_label_vesselType,
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'catamaran',
                          child: Text(context.l10n.trips_vesselType_catamaran),
                        ),
                        DropdownMenuItem(
                          value: 'motorYacht',
                          child: Text(context.l10n.trips_vesselType_motorYacht),
                        ),
                        DropdownMenuItem(
                          value: 'sailingYacht',
                          child: Text(
                            context.l10n.trips_vesselType_sailingYacht,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(context.l10n.trips_vesselType_other),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _vesselType = value;
                          _hasChanges = true;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Cabin type
                    TextFormField(
                      controller: _cabinTypeController,
                      decoration: InputDecoration(
                        labelText: context.l10n.trips_edit_label_cabinType,
                        prefixIcon: const Icon(Icons.bed),
                        hintText: context.l10n.trips_edit_hint_cabinType,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Capacity
                    TextFormField(
                      controller: _capacityController,
                      decoration: InputDecoration(
                        labelText: context.l10n.trips_edit_label_capacity,
                        prefixIcon: const Icon(Icons.people),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    // Embark / Disembark section
                    Text(
                      context.l10n.trips_edit_sectionTitle_embarkDisembark,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _embarkPortController,
                      decoration: InputDecoration(
                        labelText: context.l10n.trips_edit_label_embarkPort,
                        prefixIcon: const Icon(Icons.login),
                        hintText: context.l10n.trips_edit_hint_embarkPort,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _disembarkPortController,
                      decoration: InputDecoration(
                        labelText: context.l10n.trips_edit_label_disembarkPort,
                        prefixIcon: const Icon(Icons.logout),
                        hintText: context.l10n.trips_edit_hint_disembarkPort,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Notes section header
                  Text(
                    context.l10n.trips_edit_sectionTitle_notes,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes field
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_notes,
                      prefixIcon: const Icon(Icons.notes),
                      hintText: context.l10n.trips_edit_hint_notes,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),

                  // Share toggle — only shown when multiple diver profiles exist
                  ref
                      .watch(allDiversProvider)
                      .maybeWhen(
                        data: (divers) => divers.length >= 2
                            ? SwitchListTile(
                                title: Text(
                                  context
                                      .l10n
                                      .common_label_shareWithAllProfiles,
                                ),
                                value: _isShared,
                                onChanged: (v) async {
                                  if (!v &&
                                      isEditing &&
                                      (_originalTrip?.isShared ?? false)) {
                                    final confirmed =
                                        await _showUnshareConfirmDialog(
                                          context,
                                        );
                                    if (!mounted) return;
                                    if (confirmed != true) return;
                                  }
                                  setState(() {
                                    _isShared = v;
                                    _hasChanges = true;
                                  });
                                },
                              )
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
                  const SizedBox(height: 16),

                  if (!widget.embedded) ...[
                    // Save button
                    FilledButton(
                      onPressed: _isSaving ? null : _saveTrip,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isEditing
                                  ? context.l10n.trips_edit_button_update
                                  : context.l10n.trips_edit_button_add,
                            ),
                    ),

                    // Cancel button
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _confirmCancel(),
                      child: Text(context.l10n.trips_edit_button_cancel),
                    ),
                  ],
                ],
              ),
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
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing
                ? context.l10n.trips_edit_appBar_edit
                : context.l10n.trips_edit_appBar_add,
          ),
          actions: [
            if (_isSaving)
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
              Semantics(
                button: true,
                label: context.l10n.trips_edit_semanticLabel_save,
                child: TextButton(
                  onPressed: _saveTrip,
                  child: Text(context.l10n.trips_edit_button_save),
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
              isEditing ? Icons.edit : Icons.add,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing
                  ? context.l10n.trips_edit_appBar_edit
                  : context.l10n.trips_edit_appBar_add,
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
            child: Text(context.l10n.trips_edit_button_cancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSaving ? null : _saveTrip,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(context.l10n.trips_edit_button_save),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = isStartDate ? DateTime(1950) : _startDate;
    final lastDate = DateTime(2100);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = pickedDate;
        }
        _hasChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      return await _showDiscardDialog() ?? false;
    }
    return true;
  }

  Future<void> _confirmCancel() async {
    if (_hasChanges) {
      final discard = await _showDiscardDialog();
      if (discard == true && mounted) {
        _handleCancel();
      }
    } else {
      _handleCancel();
    }
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.trips_edit_dialog_discardTitle),
        content: Text(context.l10n.trips_edit_dialog_discardContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.trips_edit_dialog_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.trips_edit_dialog_discard),
          ),
        ],
      ),
    );
  }

  /// Asks the user to confirm un-sharing an existing shared trip.
  /// Returns [true] if confirmed, [false] or [null] to cancel.
  Future<bool?> _showUnshareConfirmDialog(BuildContext ctx) {
    final tripName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_originalTrip?.name ?? '');
    return showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(dialogCtx.l10n.trips_unshareConfirm_title),
        content: Text(dialogCtx.l10n.trips_unshareConfirm_body(tripName)),
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

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final diverId =
          _originalTrip?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      final now = DateTime.now();
      final trip = Trip(
        id: widget.tripId ?? '',
        diverId: diverId,
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        resortName: _resortController.text.trim().isEmpty
            ? null
            : _resortController.text.trim(),
        liveaboardName: _liveaboardController.text.trim().isEmpty
            ? null
            : _liveaboardController.text.trim(),
        tripType: _tripType,
        notes: _notesController.text.trim(),
        isShared: _isShared,
        createdAt: _originalTrip?.createdAt ?? now,
        updatedAt: now,
      );

      String savedId;
      if (isEditing) {
        await ref.read(tripListNotifierProvider.notifier).updateTrip(trip);
        savedId = widget.tripId!;
      } else {
        final newTrip = await ref
            .read(tripListNotifierProvider.notifier)
            .addTrip(trip);
        savedId = newTrip.id;
      }

      // Save or clean up liveaboard details
      if (_tripType == TripType.liveaboard) {
        final liveaboardRepo = LiveaboardDetailsRepository();
        final capacityText = _capacityController.text.trim();
        final details = LiveaboardDetails(
          id: _originalLiveaboardDetails?.id ?? '',
          tripId: savedId,
          vesselName: _vesselNameController.text.trim(),
          operatorName: _operatorController.text.trim().isEmpty
              ? null
              : _operatorController.text.trim(),
          vesselType: _vesselType,
          cabinType: _cabinTypeController.text.trim().isEmpty
              ? null
              : _cabinTypeController.text.trim(),
          capacity: capacityText.isEmpty ? null : int.tryParse(capacityText),
          embarkPort: _embarkPortController.text.trim().isEmpty
              ? null
              : _embarkPortController.text.trim(),
          disembarkPort: _disembarkPortController.text.trim().isEmpty
              ? null
              : _disembarkPortController.text.trim(),
          createdAt: _originalLiveaboardDetails?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await liveaboardRepo.createOrUpdate(details);

        // Generate itinerary days for new liveaboard trips
        if (!isEditing) {
          final itineraryRepo = ItineraryDayRepository();
          final days = ItineraryDay.generateForTrip(
            tripId: savedId,
            startDate: _startDate,
            endDate: _endDate,
          );
          await itineraryRepo.saveAll(days);
        }
      } else if (isEditing && _originalLiveaboardDetails != null) {
        // Type changed away from liveaboard - clean up details
        final liveaboardRepo = LiveaboardDetailsRepository();
        await liveaboardRepo.deleteByTripId(savedId);
        final itineraryRepo = ItineraryDayRepository();
        await itineraryRepo.deleteByTripId(savedId);
      }

      // Scan for candidate dives (on create, or when dates changed on edit)
      final datesChanged =
          !isEditing ||
          _originalTrip?.startDate != _startDate ||
          _originalTrip?.endDate != _endDate;

      if (mounted && datesChanged && trip.diverId != null) {
        final candidates = await ref
            .read(tripRepositoryProvider)
            .findCandidateDivesForTrip(
              tripId: savedId,
              startDate: _startDate,
              endDate: _endDate,
              diverId: trip.diverId!,
            );

        if (candidates.isNotEmpty && mounted) {
          final selectedIds = await showDiveAssignmentDialog(
            context: context,
            candidates: candidates,
          );

          if (selectedIds != null && selectedIds.isNotEmpty && mounted) {
            // Collect old trip IDs for provider invalidation
            final oldTripIds = candidates
                .where(
                  (c) => selectedIds.contains(c.dive.id) && !c.isUnassigned,
                )
                .map((c) => c.currentTripId!)
                .toSet();

            await ref
                .read(tripListNotifierProvider.notifier)
                .assignDivesToTrip(
                  selectedIds,
                  savedId,
                  oldTripIds: oldTripIds,
                );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.trips_diveScan_added(selectedIds.length),
                  ),
                ),
              );
            }
          }
        }
      }

      if (mounted) {
        if (widget.embedded) {
          widget.onSaved?.call(savedId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? context.l10n.trips_edit_snackBar_updated
                    : context.l10n.trips_edit_snackBar_added,
              ),
            ),
          );
          context.pop(savedId);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_edit_snackBar_errorSaving('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
