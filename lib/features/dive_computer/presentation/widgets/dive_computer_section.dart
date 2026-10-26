import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_controls.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Dive computer section of a Dive Computer item's Equipment page
/// (issue #3676). A registered item shows every control for its device,
/// acting on the most recently downloaded registration behind it; an item
/// added by hand offers to connect, which binds the discovered device to
/// this item.
class DiveComputerSection extends ConsumerWidget {
  const DiveComputerSection({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computers = ref.watch(computersForEquipmentProvider(equipmentId));
    return computers.when(
      data: (list) => list.isEmpty
          ? _ConnectCard(equipmentId: equipmentId)
          : DiveComputerControls(computerId: list.first.id),
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.diveComputer_title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.diveComputer_section_notConnected,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push(
                Uri(
                  path: '/dive-computers/discover',
                  queryParameters: {'equipment': equipmentId},
                ).toString(),
              ),
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(l10n.diveComputer_section_connect),
            ),
          ],
        ),
      ),
    );
  }
}
