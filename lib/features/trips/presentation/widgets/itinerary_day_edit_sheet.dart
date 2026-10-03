import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

const _log = LoggerService('itineraryDayEditSheet');

/// Shows a modal bottom sheet to edit an itinerary day's type, location,
/// notes and planned dives. Persists changes via ItineraryDayRepository and
/// invalidates the itineraryDaysProvider on save. [isLiveaboard] offers the
/// maritime day types and labels the place a port (#2845).
Future<void> showItineraryDayEditSheet({
  required BuildContext context,
  required ItineraryDay day,
  required String tripId,
  required bool isLiveaboard,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ItineraryDayEditSheet(
      day: day,
      tripId: tripId,
      isLiveaboard: isLiveaboard,
    ),
  );
}

class _ItineraryDayEditSheet extends ConsumerStatefulWidget {
  final ItineraryDay day;
  final String tripId;
  final bool isLiveaboard;

  const _ItineraryDayEditSheet({
    required this.day,
    required this.tripId,
    required this.isLiveaboard,
  });

  @override
  ConsumerState<_ItineraryDayEditSheet> createState() =>
      _ItineraryDayEditSheetState();
}

class _ItineraryDayEditSheetState
    extends ConsumerState<_ItineraryDayEditSheet> {
  late DayType _selectedDayType;
  late TextEditingController _portNameController;
  late TextEditingController _notesController;
  late TextEditingController _plannedDivesController;
  String? _plannedDivesError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDayType = widget.day.dayType;
    _portNameController = TextEditingController(
      text: widget.day.portName ?? '',
    );
    _notesController = TextEditingController(text: widget.day.notes);
    _plannedDivesController = TextEditingController(
      text: widget.day.plannedDives?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _portNameController.dispose();
    _notesController.dispose();
    _plannedDivesController.dispose();
    super.dispose();
  }

  /// Land types for every trip, the maritime ones on a boat; a row carrying
  /// a type the trip no longer offers keeps it listed so Save does not
  /// retype it.
  List<DayType> _offeredTypes() {
    const land = [DayType.travel, DayType.diveDay, DayType.rest];
    const sea = [
      DayType.embark,
      DayType.disembark,
      DayType.seaDay,
      DayType.portDay,
    ];
    final offered = [...land, if (widget.isLiveaboard) ...sea];
    if (!offered.contains(_selectedDayType)) offered.add(_selectedDayType);
    return offered;
  }

  Future<void> _save() async {
    // Blank derives the count; 0 is a rest day; a word is refused in place.
    final int? plannedDives;
    switch (readNumber(
      _plannedDivesController.text,
      integer: true,
      allowNegative: false,
    )) {
      case NumberValue(:final value):
        plannedDives = value.toInt();
      case NumberBlank():
        plannedDives = null;
      case NumberInvalid():
        setState(
          () => _plannedDivesError =
              context.l10n.trips_itinerary_plannedDives_invalid,
        );
        return;
    }
    setState(() {
      _isSaving = true;
      _plannedDivesError = null;
    });

    try {
      final portName = _portNameController.text.trim();
      final notes = _notesController.text.trim();
      // Saving a day as Rest plans it at none (#2658).
      final dayType = _selectedDayType;
      final updatedDay = widget.day.copyWith(
        dayType: dayType,
        portName: portName.isEmpty ? null : portName,
        notes: notes,
        plannedDives: dayType == DayType.rest ? 0 : plannedDives,
      );

      final repository = ref.read(itineraryDayRepositoryProvider);
      await repository.updateDay(updatedDay);

      ref.invalidate(itineraryDaysProvider(widget.tripId));

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save itinerary day',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.trips_itinerary_daySaveError)),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              '${l10n.trips_itinerary_editDay} ${widget.day.dayNumber}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Day type dropdown
            DropdownButtonFormField<DayType>(
              initialValue: _selectedDayType,
              decoration: InputDecoration(
                labelText: l10n.trips_itinerary_dayType_label,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final type in _offeredTypes())
                  DropdownMenuItem<DayType>(
                    value: type,
                    child: Text(type.localizedName(context)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  // A rest day plans no dives: the field shows the 0 it saves
                  // and is locked. Leaving Rest drops that 0, so the day goes
                  // back to the estimate instead of a dive day planned at
                  // none.
                  if (value == DayType.rest) {
                    _plannedDivesController.text = '0';
                    _plannedDivesError = null;
                  } else if (_selectedDayType == DayType.rest &&
                      _plannedDivesController.text.trim() == '0') {
                    _plannedDivesController.clear();
                  }
                  _selectedDayType = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Port name text field
            TextFormField(
              controller: _portNameController,
              decoration: InputDecoration(
                labelText: widget.isLiveaboard
                    ? l10n.trips_itinerary_portName_label
                    : l10n.trips_itinerary_location_label,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Notes text field
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: l10n.trips_itinerary_notes_label,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Planned dives: the per-day override the fill forecast reads.
            TextFormField(
              key: const Key('itinerary-planned-dives'),
              controller: _plannedDivesController,
              enabled: _selectedDayType != DayType.rest,
              decoration: InputDecoration(
                labelText: l10n.trips_itinerary_plannedDives_label,
                border: const OutlineInputBorder(),
                errorText: _plannedDivesError,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.common_action_save),
            ),
          ],
        ),
      ),
    );
  }
}
