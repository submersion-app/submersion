import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Listening or stopped, the URL, the last request, and the bind error.
class AgentAccessStatusCard extends ConsumerWidget {
  const AgentAccessStatusCard({super.key, required this.status});

  final AgentAccessStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final s = status;
    final listening = s?.listening ?? false;
    final lastRequest = s?.lastRequestAt;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  listening ? Icons.check_circle : Icons.pause_circle_outline,
                  color: listening
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  listening
                      ? l10n.settings_agentAccess_statusListening
                      : l10n.settings_agentAccess_statusStopped,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (listening && s != null) ...[
              const SizedBox(height: 8),
              SelectableText(s.url, style: theme.textTheme.bodyMedium),
            ],
            if (s?.error != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.settings_agentAccess_portInUse(s!.port),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (lastRequest != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.settings_agentAccess_lastRequest(
                  ref.watch(unitFormatterProvider).formatDateTime(lastRequest),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
