import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Divers on their own swap screens nearby (issues #3728, #4598). A tap asks
/// one to swap; while they decide, the row says so. When the radio cannot
/// look, the section says why in place of the list.
class NearbySection extends StatelessWidget {
  const NearbySection({
    super.key,
    required this.availability,
    required this.failed,
    required this.peers,
    required this.waitingFor,
    required this.onTap,
    required this.onRetry,
  });

  /// Null while the session is still starting.
  final NearbyAvailability? availability;

  /// The session could not start (a platform error).
  final bool failed;
  final List<NearbyCardPeer> peers;

  /// Swap ids of divers asked and not yet answered.
  final Set<String> waitingFor;
  final ValueChanged<NearbyCardPeer> onTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            context.l10n.buddySwap_nearby_title,
            style: theme.textTheme.labelLarge,
          ),
        ),
        if (availability == NearbyAvailability.ready)
          ..._list(context)
        else
          _Unavailable(
            availability: availability,
            failed: failed,
            onRetry: onRetry,
          ),
      ],
    );
  }

  List<Widget> _list(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return [
      for (final peer in peers)
        _PeerRow(
          peer: peer,
          waiting: waitingFor.contains(peer.swapId),
          onTap: () => onTap(peer),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.buddySwap_nearby_status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({
    required this.peer,
    required this.waiting,
    required this.onTap,
  });

  final NearbyCardPeer peer;
  final bool waiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      leading: ProfileAvatar(
        photo: peer.photo,
        initials: Buddy.initialsOf(peer.name),
      ),
      title: Text(peer.name),
      subtitle: waiting ? Text(l10n.buddySwap_waiting(peer.name)) : null,
      trailing: waiting
          ? null
          : Text(
              l10n.buddySwap_request_swap,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
      enabled: !waiting,
      onTap: onTap,
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.availability,
    required this.failed,
    required this.onRetry,
  });

  final NearbyAvailability? availability;
  final bool failed;
  final VoidCallback onRetry;

  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String _message(AppLocalizations l10n) => failed
      ? l10n.buddySwap_nearby_failed
      : switch (availability) {
          NearbyAvailability.unauthorized => l10n.nearbyPair_permissionDenied,
          NearbyAvailability.bluetoothOff => l10n.nearbyPair_bluetoothOff,
          _ => l10n.nearbyPair_unsupported,
        };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (availability == null && !failed) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.bluetooth_disabled,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_message(l10n))),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              if (availability != NearbyAvailability.unsupported)
                TextButton(
                  onPressed: onRetry,
                  child: Text(l10n.common_action_tryAgain),
                ),
              if (availability == NearbyAvailability.unauthorized && _isPhone)
                TextButton(
                  onPressed: () async {
                    try {
                      await permissions.openAppSettings();
                    } on Object {
                      // Nowhere to send the diver on this platform.
                    }
                  },
                  child: Text(l10n.nearbyPair_openSettings),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
