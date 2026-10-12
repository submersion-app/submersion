import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const String kEquipmentDefaultViewRoute = '/settings/equipment-default-view';

/// Which statuses the Equipment list shows with no filter set (issue
/// #2628). Changes save as they are made; at least one status stays ticked
/// so the list never opens empty by design.
class EquipmentDefaultViewPage extends ConsumerWidget {
  const EquipmentDefaultViewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(equipmentDefaultStatusesProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_equipmentDefaultView_title)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.settings_equipmentDefaultView_intro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final status in EquipmentStatus.values)
            CheckboxListTile(
              key: ValueKey('equipment_default_view_${status.name}'),
              title: Text(status.localizedName(l10n)),
              value: selected.contains(status),
              onChanged: selected.length == 1 && selected.contains(status)
                  ? null
                  : (ticked) => notifier.setEquipmentDefaultStatusIncluded(
                      status,
                      ticked == true,
                    ),
            ),
          // The button's own 12px inset brings its label in line with the
          // status names above.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('equipment_default_view_reset'),
                onPressed: isFactoryDefaultEquipmentStatuses(selected)
                    ? null
                    : () => notifier.setEquipmentDefaultStatuses(
                        factoryDefaultEquipmentStatuses,
                      ),
                child: Text(l10n.equipment_arrange_reset),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
