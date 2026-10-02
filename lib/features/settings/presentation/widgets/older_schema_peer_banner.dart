import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/peer_device_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Names the devices too old to read what this device publishes: their own
/// schema is below this build's compatibility floor, so they hold every
/// payload from here until they update (issue #2619).
///
/// The reverse of NewerSchemaPeerBanner. Without it the newer device, the
/// beta one in a beta and stable pair, reports a clean sync while its peer
/// receives nothing. Mirrors the sibling banners: zero-noise resting state,
/// appears only when a peer is actually behind.
class OlderSchemaPeerBanner extends StatelessWidget {
  const OlderSchemaPeerBanner({super.key, required this.peers});

  /// A null name means the peer published none.
  final List<({String? name, String shortId})> peers;

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final list = peerDeviceList(l10n, peers);
    final headline = peers.length == 1
        ? l10n.settings_cloudSync_peerBehind_banner(list)
        : l10n.settings_cloudSync_peerBehind_bannerPlural(list);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.sync_problem, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$headline ${l10n.settings_cloudSync_peerBehind_action}',
                  // Card is secondaryContainer, and Material does not
                  // re-derive text colour from its background, so bodyMedium
                  // would keep onSurface. Pair it with the container
                  // explicitly, as the icon already is.
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
