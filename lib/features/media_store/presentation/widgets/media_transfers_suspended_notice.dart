import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Tells the user the transfer queue is paused because the store could not
/// be verified (issue #1356). Nothing while the worker is not suspended.
///
/// The rows underneath still read "Waiting" / "N queued", which is true: the
/// worker leaves them untouched. This is what says why they are not moving
/// and what to do about it, since the retry is automatic but the one repair
/// the user can make (reconnecting) is not.
class MediaTransfersSuspendedNotice extends ConsumerWidget {
  const MediaTransfersSuspendedNotice({super.key, this.contentPadding});

  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suspended = ref.watch(mediaTransfersSuspendedProvider).value ?? false;
    if (!suspended) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      key: const Key('media-transfers-suspended'),
      contentPadding: contentPadding,
      leading: Icon(
        Icons.pause_circle_outline,
        color: theme.colorScheme.tertiary,
      ),
      title: Text(l10n.settings_mediaStorage_transfers_suspended_title),
      subtitle: Text(l10n.settings_mediaStorage_transfers_suspended_subtitle),
    );
  }
}
