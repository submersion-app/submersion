import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/synology/synology_album_source.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/synology_password_dialog.dart';

/// Asks for a shared album's password while its subscription's last poll
/// says it wants one, saves each answer for that share and polls again,
/// until the poll gets past the password or the user cancels.
///
/// [polled] is what the caller's own poll returned; returned unchanged when
/// nothing was asked, else what the last poll here returned. Shared by the
/// subscription card's Poll now and the Set up this device card, so both
/// fix a missing password the same way.
Future<bool> resolveSharePassword(
  BuildContext context,
  WidgetRef ref, {
  required String subscriptionId,
  bool polled = true,
  bool askFirst = false,
}) async {
  final repo = ref.read(manifestSubscriptionRepositoryProvider);
  final credentials = ref.read(networkCredentialsServiceProvider);
  final poller = ref.read(subscriptionPollerProvider);
  // [askFirst]: the caller already knows the password is wanted (a photo
  // check found no session), though the last poll may not have said so yet.
  var ask = askFirst;
  while (context.mounted) {
    final sub = await repo.getById(subscriptionId);
    if (sub == null) break;
    final share = SynologyShareLink.tryParseShareUrl(sub.manifestUrl);
    final error = sub.lastError;
    if (share == null ||
        !(ask || synologyNeedsPassword(error)) ||
        !context.mounted) {
      break;
    }
    ask = false;
    final password = await showSynologyPasswordDialog(
      context,
      shareLabel: sub.label,
      rejected: error == kSynologyPasswordRejectedMessage,
    );
    if (password == null) break;
    await credentials.save(
      hostname: NetworkCredentialsService.synologyShareKey(share),
      authType: kSynologyShareAuthType,
      password: password,
      // TODO(media): l10n
      displayName: 'Synology Photos share',
    );
    // The Saved hosts list reads the store once; show the new row.
    ref.invalidate(savedHostsProvider);
    polled = await poller.pollNow(subscriptionId, clock.now().toUtc());
  }
  return polled;
}
