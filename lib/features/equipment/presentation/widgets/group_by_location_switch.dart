import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Equipment page's own grouping switch. Not part of the shared gear
/// arrangement: where gear is stored says nothing about a dive, so the dive
/// surfaces never offer it.
class GroupByLocationSwitch extends ConsumerWidget {
  const GroupByLocationSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(equipmentGroupByLocationProvider).value ?? false;
    return SwitchListTile(
      key: const ValueKey('equipment_group_by_location'),
      value: on,
      onChanged: (value) async {
        try {
          await ref
              .read(appSettingsRepositoryProvider)
              .setEquipmentGroupByLocation(value);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.common_error_tryAgain)));
        }
      },
      title: Text(l10n.equipment_arrange_groupByLocation),
      subtitle: Text(l10n.equipment_arrange_groupByLocationSubtitle),
    );
  }
}
