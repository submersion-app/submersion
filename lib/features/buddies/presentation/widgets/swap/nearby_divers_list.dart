import 'package:flutter/material.dart';

import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Divers on their own swap screens nearby (issue #3728). A tap asks one
/// to swap; while they decide, the row says so.
class NearbyDiversList extends StatelessWidget {
  const NearbyDiversList({
    super.key,
    required this.peers,
    required this.waitingFor,
    required this.onTap,
  });

  final List<NearbyCardPeer> peers;

  /// Swap ids of divers asked and not yet answered.
  final Set<String> waitingFor;
  final ValueChanged<NearbyCardPeer> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.buddySwap_nearby_heading,
            style: theme.textTheme.labelLarge,
          ),
        ),
        for (final peer in peers)
          Card(
            child: ListTile(
              leading: ProfileAvatar(
                photo: peer.photo,
                initials: Buddy.initialsOf(peer.name),
              ),
              title: Text(peer.name),
              subtitle: Text(
                waitingFor.contains(peer.swapId)
                    ? l10n.buddySwap_waiting(peer.name)
                    : l10n.buddySwap_nearby_tapToSwap,
              ),
              enabled: !waitingFor.contains(peer.swapId),
              onTap: () => onTap(peer),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.buddySwap_nearby_looking,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.buddySwap_nearby_hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
