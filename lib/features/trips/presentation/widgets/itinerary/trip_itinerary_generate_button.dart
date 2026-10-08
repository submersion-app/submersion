import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('tripItineraryGenerateButton');

/// Fills the itinerary from the trip's dates, typed for the trip
/// (ItineraryDay.generateForTrip). With no rows it reads "Generate
/// itinerary"; with some dates missing, "Fill in missing days"; with every
/// date covered it renders nothing. Only the missing dates are written, so
/// a day the diver already planned keeps its row.
class TripItineraryGenerateButton extends ConsumerStatefulWidget {
  final Trip trip;
  final List<ItineraryDay> days;

  const TripItineraryGenerateButton({
    super.key,
    required this.trip,
    required this.days,
  });

  @override
  ConsumerState<TripItineraryGenerateButton> createState() =>
      _TripItineraryGenerateButtonState();
}

class _TripItineraryGenerateButtonState
    extends ConsumerState<TripItineraryGenerateButton> {
  bool _saving = false;

  Set<DateTime> _covered() => {for (final d in widget.days) tripDay(d.date)};

  /// Whether any trip date has no row: answered from the dates, so a
  /// rebuild does not build the rows themselves.
  bool _anyMissing() {
    final covered = _covered();
    return tripDaysBetween(
      widget.trip.startDate,
      widget.trip.endDate,
    ).any((d) => !covered.contains(d));
  }

  List<ItineraryDay> _missing() {
    final covered = _covered();
    return ItineraryDay.generateForTrip(
      tripId: widget.trip.id,
      startDate: widget.trip.startDate,
      endDate: widget.trip.endDate,
      tripType: widget.trip.tripType,
    ).where((d) => !covered.contains(tripDay(d.date))).toList();
  }

  Future<void> _generate() async {
    // A second tap while the first save is in flight would insert the days
    // twice: the table has no (trip, date) uniqueness.
    if (_saving) return;
    setState(() => _saving = true);
    final tripId = widget.trip.id;
    try {
      await ref.read(itineraryDayRepositoryProvider).saveAll(_missing());
      ref.invalidate(itineraryDaysProvider(tripId));
      ref.invalidate(tripStoryProvider(tripId));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to generate trip itinerary',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.trips_story_generateItineraryError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_anyMissing()) return const SizedBox.shrink();
    final l10n = context.l10n;
    final label = widget.days.isEmpty
        ? l10n.trips_story_generateItinerary
        : l10n.trips_itinerary_fillMissing;
    return OutlinedButton.icon(
      key: const Key('trip-itinerary-generate'),
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.event_note, size: 18),
      label: Text(label),
      onPressed: _saving ? null : _generate,
    );
  }
}
