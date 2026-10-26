import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/presentation/providers/device_item_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_key_widgets.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage > Transmitters (issue #3676): every Transmitter
/// Equipment item, whether a download created it or the diver added it.
/// Each row opens the item's Equipment page, where it is set up.
class TransmittersPage extends ConsumerWidget {
  const TransmittersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(transmitterItemsProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transmitters_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: l10n.common_action_back,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/equipment/new?type=${EquipmentType.transmitter.name}',
        ),
        tooltip: l10n.transmitters_add,
        icon: const Icon(Icons.add),
        label: Text(l10n.transmitters_add),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.common_label_error}: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.transmitters_emptyItems,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final row in list) _ItemTile(row: row, units: units),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.row, required this.units});

  final TransmitterItem row;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final setup = row.keys.firstOrNull;
    return ListTile(
      leading: Icon(
        MdiIcons.divingScubaTank,
        color: theme.colorScheme.secondary,
      ),
      title: Text(row.item.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.item.status != EquipmentStatus.active)
            Text(
              row.item.status.localizedName(l10n),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          for (final key in row.keys) TransmitterKeyLabel(entry: key),
          // An item added by hand needs its serial or channel before a
          // cylinder means anything.
          if (setup == null)
            Text(
              l10n.transmitters_list_noKey,
              style: TextStyle(color: theme.colorScheme.tertiary),
            )
          else if (!setup.isSetUp)
            Text(
              l10n.transmitters_noCylinder,
              style: TextStyle(color: theme.colorScheme.tertiary),
            )
          else
            Text(transmitterSpecLine(l10n, units, setup)),
        ],
      ),
      isThreeLine: row.keys.isNotEmpty,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/equipment/${row.item.id}'),
    );
  }
}
