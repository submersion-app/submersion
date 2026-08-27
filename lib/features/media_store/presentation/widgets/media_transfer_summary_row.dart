import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Outstanding transfer work on the Media Storage page.
///
/// The indeterminate bar is reserved for bytes actually moving. Work the
/// queue is merely holding renders as text, because an animating bar reads
/// as "this is happening now" - and a row parked in markFailed's retry
/// backoff waits up to 25 hours. Reporting that as progress left the page
/// spinning for a full day against an idle worker.
///
/// Matches how the Transfers page has always drawn the same rows: a
/// progress bar only for 'transferring', a schedule icon for everything
/// still waiting.
class MediaTransferSummaryRow extends ConsumerWidget {
  const MediaTransferSummaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final summary = ref.watch(mediaTransferSummaryProvider).value;
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.transferring > 0)
          Padding(
            key: const Key('media-transfer-progress'),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Expanded(child: LinearProgressIndicator()),
                const SizedBox(width: 12),
                Text('${summary.transferring + summary.queued}'),
              ],
            ),
          )
        else if (summary.queued > 0)
          Padding(
            key: const Key('media-transfer-queued'),
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.settings_mediaStorage_transfers_queued(summary.queued),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        if (summary.waiting > 0)
          ListTile(
            key: const Key('media-transfer-waiting'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule, color: theme.colorScheme.tertiary),
            title: Text(
              l10n.settings_mediaStorage_transfers_waitingRetry(
                summary.waiting,
              ),
            ),
            // The raw queue error, exactly as the Transfers page shows it.
            // Not localized: these are diagnostic strings the pipeline
            // writes, and translating them would lose the wording anyone
            // searching for the problem would recognize.
            subtitle: summary.waitingReason == null
                ? null
                : Text(summary.waitingReason!, maxLines: 2),
            trailing: const Icon(Icons.chevron_right),
            // Retry lives on the Transfers page, which offers it for a
            // still-pending row precisely so nobody has to wait out a
            // multi-hour backoff they are looking at right now.
            onTap: () => context.push('/settings/media-storage/transfers'),
          ),
      ],
    );
  }
}
