import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/dive_assignment_dialog.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/shared/widgets/label_with_control.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/part_of_trip_field.dart';

const _log = LoggerService('tripEditPage');

class TripEditPage extends ConsumerStatefulWidget {
  final String? tripId;
  final bool embedded;
  final void Function(String savedId)? onSaved;
  final VoidCallback? onCancel;

  /// The section the form scrolls to once the trip has loaded; null opens
  /// at the top (#2880).
  final TripEditSection? initialSection;

  /// A new trip prefilled from selected dives, which move into it on save
  /// (issue #3658). Only for a new trip.
  final TripDraft? draft;

  const TripEditPage({
    super.key,
    this.tripId,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.initialSection,
    this.draft,
  });

  @override
  ConsumerState<TripEditPage> createState() => _TripEditPageState();
}

class _TripEditPageState extends ConsumerState<TripEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _planningKey = GlobalKey();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _resortController = TextEditingController();
  final _liveaboardController = TextEditingController();
  final _notesController = TextEditingController();
  final _expectedDivesController = TextEditingController();
  final _expectedRuntimeController = TextEditingController();
  final _diversSharingController = TextEditingController();
  final _divesPerDayController = TextEditingController();

  TripType _tripType = TripType.shore;
  final _vesselNameController = TextEditingController();
  final _operatorController = TextEditingController();
  final _cabinTypeController = TextEditingController();
  final _capacityController = TextEditingController();
  final _embarkPortController = TextEditingController();
  final _disembarkPortController = TextEditingController();
  String? _vesselType;
  LiveaboardDetails? _originalLiveaboardDetails;

  late DateTime _startDate;
  DateTime? _returnFlightAt;

  /// The larger trip this one is a side trip of (issue #3658).
  String? _parentTripId;

  /// A new trip already created by a save that failed afterwards: a retry
  /// updates it instead of creating a second one.
  String? _createdTripId;
  late DateTime _endDate;
  // Controls where the end-date picker opens, not whether _endDate still
  // holds the placeholder value -- _endDate can also get auto-synced to
  // _startDate (below) while this stays false. False until the diver
  // deliberately sets an end date (picked here, or loaded from an existing
  // trip); while false, the picker opens at _startDate instead of dragging
  // the diver back through the calendar to it.
  bool _endDateTouched = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  // Who the trip is shared with (issue #2151): the pending choice, and what
  // is stored, so a save writes only a change.
  ItemSharing _sharing = ItemSharing.none;
  ItemSharing _originalSharing = ItemSharing.none;

  /// The stored sharing could not be read: the field stays locked, so a
  /// save never overwrites sharing the page never saw.
  bool _sharingUnread = false;

  /// Share rows stored beside the everyone flag (a sync race): an owner's
  /// save clears them, or a later unshare would bring them back.
  bool _staleShareRows = false;
  Trip? _originalTrip;

  bool get isEditing => widget.tripId != null;

  /// Seeds the form from a trip made from selected dives (issue #3658).
  void _applyDraft(Trip trip) {
    _nameController.text = trip.name;
    _locationController.text = trip.location ?? '';
    _resortController.text = trip.resortName ?? '';
    _startDate = trip.startDate;
    _endDate = trip.endDate;
    _endDateTouched = true;
    _parentTripId = trip.parentTripId;
  }

  bool get _hasSideTrips =>
      isEditing &&
      (ref.watch(hasSideTripsProvider(widget.tripId!)).value ?? false);

  /// A day trip's end follows its start. A day trip stored before the form
  /// enforced that can span several days; its end stays editable until the
  /// trip is one day, so the row never locks on a range it contradicts.
  bool get _endDateLocked =>
      _tripType == TripType.dayTrip &&
      calendarDaysBetween(_startDate, _endDate) == 0;

  @override
  void initState() {
    super.initState();
    // A new trip defaults to a week, counted in calendar days from a single
    // clock read.
    //
    // `now.add(Duration(days: 7))` adds elapsed time, which shifts the wall
    // clock by an hour across a daylight-saving change. That only crosses a
    // date boundary when the trip is started within an hour of midnight, but
    // then it does: opening the page at 00:30 in the week before a fall-back
    // defaulted the end to 23:30 on the sixth day, so the new trip was a day
    // short, and the duration label and the generated itinerary agreed with
    // each other on the wrong number. Before a spring-forward the same
    // arithmetic at 23:30 hands out an extra day.
    //
    // Reading the clock once also keeps the two defaults consistent: separate
    // reads could straddle midnight and set them six days apart.
    final now = clock.now();
    _startDate = now;
    _endDate = now.copyWith(day: now.day + 7);
    final draft = widget.draft;
    if (!isEditing && draft != null) _applyDraft(draft.trip);
    if (isEditing) {
      _loadTrip();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final shareByDefault = await ref.read(shareByDefaultProvider.future);
        if (!mounted) return;
        setState(
          () => _sharing = shareByDefault ? ItemSharing.all : ItemSharing.none,
        );
      });
    }
    _nameController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    _resortController.addListener(_onFieldChanged);
    _liveaboardController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
    _expectedDivesController.addListener(_onFieldChanged);
    _expectedRuntimeController.addListener(_onFieldChanged);
    _diversSharingController.addListener(_onFieldChanged);
    _divesPerDayController.addListener(_onFieldChanged);
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
        // The everyone flag comes with the trip; the read adds the chosen
        // profiles. A failed read leaves the flag, so a save keeps it.
        _originalSharing = ItemSharing(everyone: trip.isShared);
        try {
          final stored = await ref
              .read(itemSharesRepositoryProvider)
              .storedProfileIds(SharedItemKind.trip, trip.id);
          _originalSharing = ItemSharing(
            everyone: trip.isShared,
            profileIds: stored,
          );
          _staleShareRows = trip.isShared && stored.isNotEmpty;
        } catch (e, stackTrace) {
          _sharingUnread = true;
          _log.warning(
            'Could not read who trip ${trip.id} is shared with',
            error: e,
            stackTrace: stackTrace,
          );
        }
        if (!mounted) return;
        _nameController.text = trip.name;
        _parentTripId = trip.parentTripId;
        _locationController.text = trip.location ?? '';
        _resortController.text = trip.resortName ?? '';
        _liveaboardController.text = trip.liveaboardName ?? '';
        _notesController.text = trip.notes;
        _expectedDivesController.text = trip.expectedDives?.toString() ?? '';
        _expectedRuntimeController.text =
            trip.expectedRuntimeMinutes?.toString() ?? '';
        _diversSharingController.text = '${trip.diversSharingCylinders}';
        _divesPerDayController.text = trip.divesPerDayTarget?.toString() ?? '';
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
          _endDateTouched = true;
          _returnFlightAt = trip.returnFlightAt;
          _sharing = _originalSharing;
          _isLoading = false;
          _hasChanges = false;
        });
        if (widget.initialSection == TripEditSection.planning) {
          // The form replaces the spinner on the next frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final planning = _planningKey.currentContext;
            if (planning != null) Scrollable.ensureVisible(planning);
          });
        }
      }
    } catch (e, stackTrace) {
      _log.error('Failed to load trip', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_edit_snackBar_errorLoading),
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
    _expectedDivesController.dispose();
    _expectedRuntimeController.dispose();
    _diversSharingController.dispose();
    _divesPerDayController.dispose();
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
    final units = UnitFormatter(ref.watch(settingsProvider));

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
                        // A day trip is one calendar day. Switching away
                        // leaves the dates alone for the diver to widen.
                        if (_tripType == TripType.dayTrip) {
                          _endDate = _startDate;
                        }
                        _hasChanges = true;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  // Says what each type is for, so a diver with a single
                  // local dive learns that Day Trip is its home (#2625).
                  Text(
                    _tripTypeDescription(context, _tripType),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                  // A trip with side trips of its own cannot be one: one
                  // level deep (issue #3658).
                  if (!_hasSideTrips) ...[
                    const SizedBox(height: 8),
                    PartOfTripField(
                      tripId: widget.tripId,
                      value: _parentTripId,
                      onChanged: (id) => setState(() {
                        _parentTripId = id;
                        _hasChanges = true;
                      }),
                    ),
                  ],
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
                        '${context.l10n.trips_edit_label_startDate}: ${units.formatDate(_startDate)}. Tap to change',
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(context.l10n.trips_edit_label_startDate),
                      subtitle: Text(units.formatDate(_startDate)),
                      onTap: () => _selectDate(context, true),
                      contentPadding: EdgeInsets.zero,
                      trailing: const Icon(Icons.edit),
                    ),
                  ),

                  // End date, locked on a one-day Day Trip.
                  Semantics(
                    button: true,
                    enabled: !_endDateLocked,
                    label:
                        '${context.l10n.trips_edit_label_endDate}: ${units.formatDate(_endDate)}'
                        '${_endDateLocked ? '' : '. Tap to change'}',
                    child: ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(context.l10n.trips_edit_label_endDate),
                      subtitle: Text(units.formatDate(_endDate)),
                      enabled: !_endDateLocked,
                      onTap: _endDateLocked
                          ? null
                          : () => _selectDate(context, false),
                      contentPadding: EdgeInsets.zero,
                      trailing: Icon(
                        _endDateLocked ? Icons.lock_outline : Icons.edit,
                      ),
                    ),
                  ),

                  // Duration display
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 40),
                    child: Text(
                      context.l10n.trips_edit_durationDays(
                        // Calendar days, not elapsed hours: `Duration.inDays`
                        // floors, so a trip spanning a spring-forward is 71
                        // hours and would read a day short of the itinerary
                        // the same range generates.
                        calendarDaysBetween(_startDate, _endDate) + 1,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  // Return flight (optional; drives the no-fly countdown)
                  Semantics(
                    button: true,
                    label: context.l10n.trips_edit_label_returnFlight,
                    child: ListTile(
                      leading: const Icon(Icons.flight_land),
                      title: Text(context.l10n.trips_edit_label_returnFlight),
                      subtitle: Text(
                        _returnFlightAt == null
                            ? context.l10n.trips_edit_returnFlightNotSet
                            // TimeOfDay.format reads MediaQuery's
                            // alwaysUse24HourFormat, which is the platform
                            // setting, not the diver's TimeFormat (#1512).
                            : '${units.formatDate(_returnFlightAt)}, '
                                  '${units.formatTime(_returnFlightAt)}',
                      ),
                      trailing: _returnFlightAt == null
                          ? const Icon(Icons.edit)
                          : IconButton(
                              tooltip:
                                  context.l10n.trips_edit_returnFlightClear,
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _returnFlightAt = null;
                                _hasChanges = true;
                              }),
                            ),
                      contentPadding: EdgeInsets.zero,
                      onTap: _selectReturnFlight,
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
                      // The filter keeps '-', so "-3" saves as none rather than as 3.
                      inputFormatters: numberInputFormatters(),
                      validator: numberValidator(context, integer: true),
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
                  MarkdownNotesField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_notes,
                      prefixIcon: const Icon(Icons.notes),
                      hintText: context.l10n.trips_edit_hint_notes,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),

                  // Planning (condition phase 4b): the scrubber margin's
                  // two overrides. Empty means estimate from history.
                  Text(
                    context.l10n.trips_edit_sectionTitle_planning,
                    key: _planningKey,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _expectedDivesController,
                    // The filter keeps '-', so "-3" saves as none rather than as 3.
                    inputFormatters: numberInputFormatters(),
                    validator: numberValidator(context, integer: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_expectedDives,
                      prefixIcon: const Icon(Icons.scuba_diving),
                      hintText: context.l10n.trips_edit_hint_expectedDives,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _expectedRuntimeController,
                    // The filter keeps '-', so "-3" saves as none rather than as 3.
                    inputFormatters: numberInputFormatters(),
                    validator: numberValidator(context, integer: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_expectedRuntime,
                      prefixIcon: const Icon(Icons.timer_outlined),
                      hintText: context.l10n.trips_edit_hint_expectedRuntime,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  // Fill forecast (#2325): who breathes from the trip's
                  // cylinders, and a dives-per-day target. Blank sharing is
                  // one diver; a blank target falls back to the expected
                  // dives, else only the days the diver plans (#2903).
                  TextFormField(
                    controller: _diversSharingController,
                    inputFormatters: numberInputFormatters(),
                    validator: numberValidator(context, integer: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_diversSharing,
                      prefixIcon: const Icon(Icons.groups_outlined),
                      hintText: context.l10n.trips_edit_hint_diversSharing,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _divesPerDayController,
                    inputFormatters: numberInputFormatters(),
                    validator: numberValidator(context, integer: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.trips_edit_label_divesPerDay,
                      prefixIcon: const Icon(Icons.today_outlined),
                      hintText: context.l10n.trips_edit_hint_divesPerDay,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Who sees the trip, with two or more profiles (issue
                  // #2151). Built only then, so a single profile's page
                  // never reads the active profile for it.
                  if (ref.watch(allDiversProvider).value?.length case final n?
                      when n >= 2)
                    ItemSharingField(
                      kind: SharedItemKind.trip,
                      value: _sharing,
                      original: _originalSharing,
                      mayShare: _sharingUnread ? null : _mayShare(),
                      ownerId:
                          _originalTrip?.diverId ??
                          ref.watch(validatedCurrentDiverIdProvider).value,
                      itemName: _nameController.text.trim().isNotEmpty
                          ? _nameController.text.trim()
                          : (_originalTrip?.name ?? ''),
                      onChanged: (v) => setState(() {
                        _sharing = v;
                        _hasChanges = true;
                      }),
                    ),
                  const SizedBox(height: 16),
                  // No Save or Cancel buttons down here: the app bar's Save
                  // and back button (or the embedded header) are the form's
                  // only actions, since a second, differently labelled save
                  // read as another action (issue #3174).
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
            Semantics(
              button: true,
              label: context.l10n.trips_edit_semanticLabel_save,
              child: AppBarTextAction(
                label: context.l10n.trips_edit_button_save,
                onPressed: _isSaving ? null : _saveTrip,
                busy: _isSaving,
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
      child: LabelWithControl(
        label: Row(
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: Text(
                isEditing
                    ? context.l10n.trips_edit_appBar_edit
                    : context.l10n.trips_edit_appBar_add,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        control: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.trips_edit_button_save),
            ),
          ],
        ),
      ),
    );
  }

  String _tripTypeDescription(BuildContext context, TripType type) {
    return switch (type) {
      TripType.shore => context.l10n.trips_type_description_shore,
      TripType.liveaboard => context.l10n.trips_type_description_liveaboard,
      TripType.resort => context.l10n.trips_type_description_resort,
      TripType.dayTrip => context.l10n.trips_type_description_dayTrip,
    };
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate
        ? _startDate
        : (_endDateTouched ? _endDate : _startDate);
    final firstDate = isStartDate ? DateTime(1950) : _startDate;
    final lastDate = DateTime(2100);

    final pickedDate = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_tripType == TripType.dayTrip || _startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = pickedDate;
          _endDateTouched = true;
        }
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectReturnFlight() async {
    final initial =
        _returnFlightAt ??
        DateTime(_endDate.year, _endDate.month, _endDate.day, 12);
    final pickedDate = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      // Wall-clock-as-UTC, the same frame as dive times, so the no-fly
      // math can compare this directly against dive end times.
      _returnFlightAt = DateTime.utc(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _hasChanges = true;
    });
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      return await _showDiscardDialog() ?? false;
    }
    return true;
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

  /// Whether the active profile may change this trip's sharing: always for
  /// a new trip, and only the owner for an existing one (issue #2594); null
  /// while the profile is unknown, which locks it without naming an owner
  /// (issue #2682). Read during build, so it watches the active profile.
  bool? _mayShare() => _originalTrip == null
      // A new trip is the active profile's; until that profile is known the
      // picker could offer it to itself, so sharing waits (issue #2151).
      ? (ref.watch(validatedCurrentDiverIdProvider).hasValue ? true : null)
      : canDestroySharedItemOnceKnown(
          ref.watch(validatedCurrentDiverIdProvider),
          ownerId: _originalTrip?.diverId,
        );

  /// A whole number above zero, or null for blank and for zero or below,
  /// as before. The field validators have already stopped unreadable text,
  /// which used to save as null and erase the stored value (#1900).
  static int? _positiveOrNull(String text) =>
      switch (readNumber(text, integer: true)) {
        NumberValue(:final value) when value > 0 => value.toInt(),
        NumberValue() || NumberBlank() || NumberInvalid() => null,
      };

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final diverId =
          _originalTrip?.diverId ??
          await ref.read(validatedCurrentDiverIdProvider.future);

      final now = DateTime.now();
      final trip = Trip(
        id: widget.tripId ?? _createdTripId ?? '',
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
        isShared: _sharing.everyone,
        parentTripId: _parentTripId,
        returnFlightAt: _returnFlightAt,
        // Non-positive is not a plan, it is an empty field said twice:
        // the scrubber margin multiplies both of these, and a zero or a
        // negative would make the arithmetic meaningless rather than
        // conservative. Unset falls back to the history estimate.
        expectedDives: _positiveOrNull(_expectedDivesController.text),
        expectedRuntimeMinutes: _positiveOrNull(
          _expectedRuntimeController.text,
        ),
        // Blank or non-positive is the default: one diver, the estimate.
        diversSharingCylinders:
            _positiveOrNull(_diversSharingController.text) ?? 1,
        divesPerDayTarget: _positiveOrNull(_divesPerDayController.text),
        createdAt: _originalTrip?.createdAt ?? now,
        updatedAt: now,
      );

      String savedId;
      final createdId = _createdTripId;
      if (isEditing || createdId != null) {
        await ref.read(tripListNotifierProvider.notifier).updateTrip(trip);
        savedId = widget.tripId ?? createdId!;
      } else {
        final newTrip = await ref
            .read(tripListNotifierProvider.notifier)
            .addTrip(trip);
        savedId = newTrip.id;
        _createdTripId = savedId;
      }

      // The chosen profiles (issue #2151), only when the owner changed
      // them; the save above already wrote the everyone flag. Checked in
      // this order so an unchanged save never reads the active profile.
      var sharingRefused = false;
      if (!_sharingUnread &&
          (_sharing != _originalSharing ||
              (_staleShareRows && _sharing.everyone)) &&
          (!isEditing ||
              canDestroySharedItemOnceKnown(
                    ref.read(validatedCurrentDiverIdProvider),
                    ownerId: _originalTrip?.diverId,
                  ) ==
                  true)) {
        sharingRefused = !await ref
            .read(itemSharesRepositoryProvider)
            .setSharing(
              SharedItemKind.trip,
              savedId,
              _sharing,
              // The profile acting now, which the repository checks; never
              // the owner on its behalf.
              actingDiverId: ref.read(validatedCurrentDiverIdProvider).value,
            );
      }

      // Save or clean up liveaboard details
      if (_tripType == TripType.liveaboard) {
        final liveaboardRepo = LiveaboardDetailsRepository();
        final capacityText = _capacityController.text.trim();
        // A retry after a failed create finds the details its first attempt
        // wrote, so it updates them instead of adding a second set.
        final existingDetails =
            _originalLiveaboardDetails ??
            (createdId != null
                ? await liveaboardRepo.getByTripId(savedId)
                : null);
        final details = LiveaboardDetails(
          id: existingDetails?.id ?? '',
          tripId: savedId,
          vesselName: _vesselNameController.text.trim(),
          operatorName: _operatorController.text.trim().isEmpty
              ? null
              : _operatorController.text.trim(),
          vesselType: _vesselType,
          cabinType: _cabinTypeController.text.trim().isEmpty
              ? null
              : _cabinTypeController.text.trim(),
          capacity: _positiveOrNull(capacityText),
          embarkPort: _embarkPortController.text.trim().isEmpty
              ? null
              : _embarkPortController.text.trim(),
          disembarkPort: _disembarkPortController.text.trim().isEmpty
              ? null
              : _disembarkPortController.text.trim(),
          createdAt: existingDetails?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await liveaboardRepo.createOrUpdate(details);

        // Generate itinerary days for new liveaboard trips, once: a retry
        // after a failed create keeps the days its first attempt wrote.
        final itineraryRepo = ItineraryDayRepository();
        if (!isEditing &&
            (createdId == null ||
                (await itineraryRepo.getByTripId(savedId)).isEmpty)) {
          final days = ItineraryDay.generateForTrip(
            tripId: savedId,
            startDate: _startDate,
            endDate: _endDate,
          );
          await itineraryRepo.saveAll(days);
        }
      } else if (isEditing && _originalLiveaboardDetails != null) {
        // Type changed away from liveaboard: the vessel details go, since only
        // a liveaboard has them. The itinerary stays; every trip type has one
        // (#2845), and its maritime days keep their labels.
        final liveaboardRepo = LiveaboardDetailsRepository();
        await liveaboardRepo.deleteByTripId(savedId);
      }

      // A trip made from selected dives takes exactly those dives, so no
      // date-range scan offers others (issue #3658).
      final draft = widget.draft;
      if (!isEditing && draft != null && draft.diveIds.isNotEmpty) {
        await ref
            .read(tripListNotifierProvider.notifier)
            .assignDivesToTrip(
              draft.diveIds,
              savedId,
              oldTripIds: draft.sourceTripIds,
            );
      }

      // Scan for candidate dives (on create, or when dates changed on edit)
      final datesChanged =
          !isEditing ||
          _originalTrip?.startDate != _startDate ||
          _originalTrip?.endDate != _endDate;

      if (mounted && datesChanged && draft == null) {
        // Resolved only once a scan is actually going to run: this provider
        // hits the database, and the save above may not have warmed it (the
        // `??` at the top of this method short-circuits for existing trips).
        final activeDiverId = await ref.read(
          validatedCurrentDiverIdProvider.future,
        );

        if (mounted && activeDiverId != null) {
          final candidates = await ref
              .read(tripRepositoryProvider)
              .findCandidateDivesForTrip(
                tripId: savedId,
                startDate: _startDate,
                endDate: _endDate,
                diverId: activeDiverId,
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
      }

      if (mounted) {
        // The rest of the trip is saved, so a refused sharing change says
        // so in place of the saved message rather than keeping the page.
        final l10n = context.l10n;
        final message = sharingRefused
            ? sharingRefusedMessage(l10n)
            : widget.embedded
            ? null
            : isEditing
            ? l10n.trips_edit_snackBar_updated
            : l10n.trips_edit_snackBar_added;
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        if (widget.embedded) {
          widget.onSaved?.call(savedId);
        } else {
          context.pop(savedId);
        }
      }
    } catch (e, stackTrace) {
      _log.error('Failed to save trip', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_edit_snackBar_errorSaving),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}
