import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

/// Shows a modal bottom sheet to edit an itinerary day's type, location,
/// notes and planned dives. Save hands the edited day to [hold]: the trip
/// page holds it in its sitting until its own Save (issue #4527).
/// [isLiveaboard] offers the maritime day types and labels the place a port
/// (#2845).
Future<void> showItineraryDayEditSheet({
  required BuildContext context,
  required ItineraryDay day,
  required bool isLiveaboard,
  required ValueChanged<ItineraryDay> hold,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ItineraryDayEditSheet(
      day: day,
      isLiveaboard: isLiveaboard,
      hold: hold,
    ),
  );
}

class _ItineraryDayEditSheet extends StatefulWidget {
  final ItineraryDay day;
  final bool isLiveaboard;

  /// Takes the edited day: the trip page holds it in its sitting until Save
  /// (issue #4527).
  final ValueChanged<ItineraryDay> hold;

  const _ItineraryDayEditSheet({
    required this.day,
    required this.isLiveaboard,
    required this.hold,
  });

  @override
  State<_ItineraryDayEditSheet> createState() => _ItineraryDayEditSheetState();
}

class _ItineraryDayEditSheetState extends State<_ItineraryDayEditSheet> {
  late DayType _selectedDayType;
  late TextEditingController _portNameController;
  late TextEditingController _notesController;
  late TextEditingController _plannedDivesController;
  String? _plannedDivesError;

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

  void _save() {
    // Blank derives the count; 0 is a rest day; a word, or more dives than
    // the planning board can show, is refused in place.
    final int? plannedDives;
    switch (readNumber(
      _plannedDivesController.text,
      integer: true,
      allowNegative: false,
    )) {
      case NumberValue(:final value) when value > kMaxPlannedDivesPerDay:
        setState(
          () => _plannedDivesError = context.l10n
              .trips_itinerary_plannedDives_tooMany(kMaxPlannedDivesPerDay),
        );
        return;
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
    final portName = _portNameController.text.trim();
    final notes = _notesController.text.trim();
    // Saving a day as Rest plans it at none (#2658).
    final dayType = _selectedDayType;
    widget.hold(
      widget.day.copyWith(
        dayType: dayType,
        portName: portName.isEmpty ? null : portName,
        notes: notes,
        plannedDives: dayType == DayType.rest ? 0 : plannedDives,
      ),
    );
    Navigator.of(context).pop();
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
                  // back to the trip's default instead of a dive day planned
                  // at none.
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
            MarkdownNotesField(
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
              onPressed: _save,
              child: Text(l10n.common_action_save),
            ),
          ],
        ),
      ),
    );
  }
}
