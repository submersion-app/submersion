import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';

/// Shows a modal bottom sheet to edit an itinerary day's type, port name,
/// and notes. Persists changes via ItineraryDayRepository and invalidates
/// the itineraryDaysProvider on save.
Future<void> showItineraryDayEditSheet({
  required BuildContext context,
  required ItineraryDay day,
  required String tripId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ItineraryDayEditSheet(day: day, tripId: tripId),
  );
}

class _ItineraryDayEditSheet extends ConsumerStatefulWidget {
  final ItineraryDay day;
  final String tripId;

  const _ItineraryDayEditSheet({required this.day, required this.tripId});

  @override
  ConsumerState<_ItineraryDayEditSheet> createState() =>
      _ItineraryDayEditSheetState();
}

class _ItineraryDayEditSheetState
    extends ConsumerState<_ItineraryDayEditSheet> {
  late DayType _selectedDayType;
  late TextEditingController _portNameController;
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDayType = widget.day.dayType;
    _portNameController = TextEditingController(
      text: widget.day.portName ?? '',
    );
    _notesController = TextEditingController(text: widget.day.notes);
  }

  @override
  void dispose() {
    _portNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final portName = _portNameController.text.trim();
      final notes = _notesController.text.trim();

      final updatedDay = widget.day.copyWith(
        dayType: _selectedDayType,
        portName: portName.isEmpty ? null : portName,
        notes: notes,
      );

      final repository = ref.read(itineraryDayRepositoryProvider);
      await repository.updateDay(updatedDay);

      ref.invalidate(itineraryDaysProvider(widget.tripId));

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.common_label_error}: $e')),
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
              items: DayType.values
                  .map(
                    (type) => DropdownMenuItem<DayType>(
                      value: type,
                      child: Text(type.localizedName(context)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDayType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Port name text field
            TextFormField(
              controller: _portNameController,
              decoration: InputDecoration(
                labelText: l10n.trips_itinerary_portName_label,
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
