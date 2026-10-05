import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_scrubber_margin_details.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The detail behind a Gear row's state line (#2845): every service clock
/// falling due before the trip ends, and the rebreather's scrubber margin
/// breakdown (the four figures, the n behind each, the caution line).
Future<void> showTripGearAlertSheet(
  BuildContext context, {
  required EquipmentItem item,
  required List<DueClock> alerts,
  ScrubberMargin? margin,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: theme.textTheme.titleLarge),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              TripServiceAlertList(alerts: alerts, showItemName: false),
            ],
            if (margin != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.air, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sheetContext.l10n.trips_scrubber_title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const Divider(),
              TripScrubberMarginDetails(margins: [margin]),
            ],
          ],
        ),
      );
    },
  );
}

/// A gear row's tinted line for its most pressing service clock (#2845):
/// [alerts] come most pressing first, the line reads the first and tapping
/// it opens the sheet with them all. Shared by the slot rows and the
/// slotless tank rows of the Gear tab.
class TripGearAlertLine extends StatelessWidget {
  final List<DueClock> alerts;
  final UnitFormatter units;

  const TripGearAlertLine({
    super.key,
    required this.alerts,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final item = alerts.first.item;
    final worst = alerts.first.status;
    return InkWell(
      key: Key('trip-gear-alert-${item.id}'),
      onTap: () => showTripGearAlertSheet(context, item: item, alerts: alerts),
      child: Text(
        tripServiceAlertSubtitle(context, units, worst),
        style: TextStyle(
          color: serviceSeveritySwatch(
            StatusColors.of(context),
            worst.severity,
          )?.accent,
        ),
      ),
    );
  }
}
