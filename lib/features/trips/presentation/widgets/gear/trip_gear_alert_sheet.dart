import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
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
