import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';

/// The details row with the total time of the dives in the Dives row above
/// it (issue #3550), in the Exposure card's hours format so ordinary gear
/// reads the same in both. Nothing is drawn until there is a time to show:
/// no dives, dives with no recorded length, a failed read, or a read still
/// in flight, which would otherwise flash a row that may never fill in.
class EquipmentDiveTimeRow extends ConsumerWidget {
  final String equipmentId;

  const EquipmentDiveTimeRow({super.key, required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref
        .watch(equipmentDiveTimeProvider(equipmentId))
        .maybeWhen(data: (value) => value, orElse: () => 0);
    if (seconds <= 0) return const SizedBox.shrink();
    return DetailRow.text(
      label: context.l10n.equipment_detail_diveTimeLabel,
      value: context.l10n.equipmentCondition_exposure_hours(
        formatFixedForDisplay(seconds / Duration.secondsPerHour, 1),
      ),
      valueStyle: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
