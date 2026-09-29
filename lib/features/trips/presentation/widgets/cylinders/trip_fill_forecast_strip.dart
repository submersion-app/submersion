import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The most dives the day editor offers (ruling R7).
const int _maxPlannedDives = 12;

/// The remaining trip days with their planned dives, for the board.
/// Tapping a day edits its plan; the forecast refreshes through the
/// itinerary provider's change stream.
class TripFillForecastStrip extends ConsumerStatefulWidget {
  const TripFillForecastStrip({
    super.key,
    required this.tripId,
    required this.days,
    required this.units,
  });

  final String tripId;
  final List<FillForecastDay> days;
  final UnitFormatter units;

  @override
  ConsumerState<TripFillForecastStrip> createState() =>
      _TripFillForecastStripState();
}

class _TripFillForecastStripState extends ConsumerState<TripFillForecastStrip> {
  /// One save at a time: the repository's transaction keeps the rows
  /// right, and this keeps a second dialog from opening over a save.
  bool _saving = false;

  Future<void> _edit(FillForecastDay day) async {
    if (_saving) return;
    final result = await showTripDayPlanDialog(
      context,
      day: day,
      dateLabel: widget.units.formatWeekdayMonthDay(day.date),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(itineraryDayRepositoryProvider)
          .setPlannedDives(
            tripId: widget.tripId,
            date: day.date,
            plannedDives: result.plannedDives,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.trips_cylinders_forecast_saveError('$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.trips_cylinders_forecast_daysTitle,
            style: theme.textTheme.titleSmall,
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = widget.days[i];
              return ActionChip(
                key: Key('forecast-day-$i'),
                avatar: day.isOverride
                    ? const Icon(Icons.edit_calendar, size: 16)
                    : null,
                label: Text(
                  '${widget.units.formatWeekdayMonthDay(day.date)} · '
                  '${l10n.trips_cylinders_forecast_plannedDives(day.plannedDives)}',
                ),
                onPressed: _saving ? null : () => _edit(day),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Asks for [day]'s planned dives, 0 to 12. Returns the number, or a null
/// number to return the day to the estimate (offered when the day has its
/// own plan), or null when the diver cancels.
Future<({int? plannedDives})?> showTripDayPlanDialog(
  BuildContext context, {
  required FillForecastDay day,
  required String dateLabel,
}) {
  var count = day.plannedDives.clamp(0, _maxPlannedDives);
  return showDialog<({int? plannedDives})>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.trips_cylinders_forecast_dayTitle(dateLabel)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('plan-fewer'),
                tooltip: l10n.trips_cylinders_forecast_fewer,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: count > 0 ? () => setState(() => count--) : null,
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$count',
                  key: const Key('plan-count'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                key: const Key('plan-more'),
                tooltip: l10n.trips_cylinders_forecast_more,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: count < _maxPlannedDives
                    ? () => setState(() => count++)
                    : null,
              ),
            ],
          ),
          actions: [
            if (day.isOverride)
              TextButton(
                key: const Key('plan-use-estimate'),
                onPressed: () =>
                    Navigator.of(dialogContext).pop((plannedDives: null)),
                child: Text(l10n.trips_cylinders_forecast_useEstimate),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop((plannedDives: count)),
              child: Text(l10n.common_action_save),
            ),
          ],
        ),
      );
    },
  );
}
