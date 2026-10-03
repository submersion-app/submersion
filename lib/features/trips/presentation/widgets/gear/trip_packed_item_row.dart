import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_alert_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_scrubber_margin_details.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One packed item on the Gear tab (#2845). The subtitle is the item's
/// state for this trip when it has one (a service clock falling due, a
/// rebreather's scrubber margin), else its type. Tapping that state line
/// opens its detail; tapping the rest of the row opens the item.
class TripPackedItemRow extends ConsumerWidget {
  final EquipmentItem item;

  /// Every blocking clock on the item, most pressing first: the first is
  /// the one-line subtitle, the sheet lists them all.
  final List<DueClock> alerts;
  final ScrubberMargin? margin;
  final Future<void> Function() onUnpack;

  const TripPackedItemRow({
    super.key,
    required this.item,
    this.alerts = const [],
    this.margin,
    required this.onUnpack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = StatusColors.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));

    var subtitle = item.type.localizedName(l10n);
    Color? tint;
    final clock = alerts.firstOrNull?.status;
    final scrubber = margin;
    if (clock != null) {
      subtitle = tripServiceAlertSubtitle(context, units, clock);
      tint = serviceSeveritySwatch(status, clock.severity)?.accent;
    } else if (scrubber != null) {
      // With no rated duration there is no margin to give; the line names
      // the section and the sheet carries the hint.
      final after = scrubber.marginAfter;
      subtitle = after == null
          ? l10n.trips_scrubber_title
          : l10n.trips_scrubber_bannerMargin(tripScrubberMarginMinutes(after));
      if (scrubber.caution) tint = status.alert.accent;
    }
    final hasDetail = clock != null || scrubber != null;
    final subtitleText = Text(subtitle, style: TextStyle(color: tint));

    return ListTile(
      leading: Icon(equipmentTypeIcon(item.type)),
      title: Text(item.name),
      subtitle: hasDetail
          ? InkWell(
              key: Key('trip-gear-alert-${item.id}'),
              onTap: () => showTripGearAlertSheet(
                context,
                item: item,
                alerts: alerts,
                margin: scrubber,
              ),
              child: subtitleText,
            )
          : subtitleText,
      trailing: PopupMenuButton<String>(
        key: Key('trip-gear-menu-${item.id}'),
        onSelected: (_) => onUnpack(),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'unpack', child: Text(l10n.trips_gear_remove)),
        ],
      ),
      onTap: () => context.push('/equipment/${item.id}'),
    );
  }
}
