import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Tells the user the transfer queue is paused because the store could not
/// be verified (issue #1356). Nothing while the worker is not suspended.
///
/// The rows underneath still read "Waiting" / "N queued", which is true: the
/// worker leaves them untouched. This is what says why they are not moving
/// and what to do about it, since the retry is automatic but the one repair
/// the user can make (reconnecting) is not.
///
/// Names the queue's hold (media sync program spec 7.1): a detached device,
/// a store that could not be checked, or, by default, a marker mismatch. The
/// unreachable case adds the raw error beneath, not localized for the same
/// reason row errors are not: it is the wording anyone searching for the
/// problem would recognize.
class MediaTransfersSuspendedNotice extends ConsumerWidget {
  const MediaTransfersSuspendedNotice({super.key, this.contentPadding});

  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suspended = ref.watch(mediaTransfersSuspendedProvider).value ?? false;
    if (!suspended) return const SizedBox.shrink();
    final hold = ref.watch(mediaTransferSummaryProvider).value?.hold;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final subtitle = switch (hold?.kind) {
      MediaTransferHoldKind.detached =>
        l10n.settings_mediaStorage_transfers_suspended_detached,
      MediaTransferHoldKind.storeUnreachable =>
        '${l10n.settings_mediaStorage_transfers_suspended_unreachable}\n'
            '${hold!.message}',
      _ => l10n.settings_mediaStorage_transfers_suspended_subtitle,
    };
    return ListTile(
      key: const Key('media-transfers-suspended'),
      contentPadding: contentPadding,
      leading: Icon(
        Icons.pause_circle_outline,
        color: theme.colorScheme.tertiary,
      ),
      title: Text(l10n.settings_mediaStorage_transfers_suspended_title),
      subtitle: Text(subtitle),
    );
  }
}
