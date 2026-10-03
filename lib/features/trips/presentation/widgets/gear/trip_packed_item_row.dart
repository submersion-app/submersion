import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_scrubber_margin_details.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One packed item on the Gear tab (#2845). The subtitle is the item's
/// state for this trip when it has one (a service clock falling due, a
/// rebreather's scrubber margin), else its type. Tap opens the item.
class TripPackedItemRow extends ConsumerWidget {
  final EquipmentItem item;
  final DueClock? alert;
  final ScrubberMargin? margin;
  final Future<void> Function() onUnpack;

  const TripPackedItemRow({
    super.key,
    required this.item,
    this.alert,
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
    final clock = alert?.status;
    final scrubber = margin;
    if (clock != null) {
      subtitle = tripServiceAlertSubtitle(context, units, clock);
      tint = clock.severity == ServiceClockSeverity.overdue
          ? status.alert.accent
          : status.warn.accent;
    } else if (scrubber != null && scrubber.marginAfter != null) {
      subtitle = l10n.trips_scrubber_bannerMargin(
        tripScrubberMarginMinutes(scrubber.marginAfter!),
      );
      if (scrubber.caution) tint = status.alert.accent;
    }

    return ListTile(
      leading: Icon(equipmentTypeIcon(item.type)),
      title: Text(item.name),
      subtitle: Text(subtitle, style: TextStyle(color: tint)),
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
