import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/features/dive_computer/presentation/utils/connection_presentation.dart';
import 'package:submersion/features/dive_computer/presentation/utils/last_download_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every way [computer] has reached the library (issue #3106): each direct
/// transport, file format and cloud provider, when it was last used, and
/// whether this device can download over it.
///
/// Shrinks to nothing while loading or on a failed read, so the detail page
/// never reserves space for a card it may not show.
class DiveComputerConnectionsCard extends ConsumerWidget {
  const DiveComputerConnectionsCard({super.key, required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref
        .watch(diveComputerConnectionsProvider(computer.id))
        .valueOrNull;
    if (connections == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.diveComputer_connections_title,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (connections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.diveComputer_connections_empty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final connection in connections)
              _ConnectionTile(computer: computer, connection: connection),
          ],
        ),
      ),
    );
  }
}

class _ConnectionTile extends ConsumerWidget {
  const _ConnectionTile({required this.computer, required this.connection});

  final DiveComputer computer;
  final DiveComputerConnection connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final label = connectionLabel(l10n, connection);
    final lastUsed = l10n.diveComputer_connections_lastUsed(
      formatLastDownload(context, connection.lastUsedAt, units: units),
    );

    return ListTile(
      leading: Icon(connectionIcon(connection.kind)),
      title: Text(label),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(lastUsed),
          if (connection.reachableHere)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.diveComputer_connections_thisDevice,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
        ],
      ),
      trailing: connection.reachableHere
          ? IconButton(
              icon: const Icon(Icons.download),
              tooltip: l10n.diveComputer_connections_downloadVia(label),
              onPressed: () => context.push(
                '/dive-computers/${computer.id}/download'
                '?connection=${Uri.encodeQueryComponent(connection.id)}',
              ),
            )
          : null,
    );
  }
}
