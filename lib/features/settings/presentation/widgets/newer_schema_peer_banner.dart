import 'package:flutter/material.dart';

import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/settings/presentation/widgets/peer_device_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Names the devices held back because their sync payloads declare a
/// compatibility floor above this build's database schema.
///
/// Mirrors SkippedPeerBanner: zero-noise resting state, appears only when a
/// peer is actually held. The call to action never promises an update this
/// device's channel may not offer yet: a store build is told the store update
/// may still be in review (issue #1089) or not released yet, and a direct
/// build on the stable channel is told the peer may be on beta, whose changes
/// stable only reaches at the next release (issue #2619). Only the beta
/// channel, which always carries the newest build, is told to update.
class NewerSchemaPeerBanner extends StatelessWidget {
  const NewerSchemaPeerBanner({
    super.key,
    required this.peers,
    required this.releaseChannel,
    this.channelOverride,
  });

  /// A null name means the peer published none -- either it is on a manifest
  /// written before the field existed, or nothing identifies it by name.
  final List<({String? name, String shortId})> peers;

  /// This device's update channel. Only consulted on a direct (non-store)
  /// build, where the in-app picker sets it.
  final ReleaseChannel releaseChannel;

  /// Test seam: UpdateChannelConfig.current reads a compile-time constant,
  /// which a test binary cannot vary.
  final UpdateChannel? channelOverride;

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final channel = channelOverride ?? UpdateChannelConfig.current;

    final list = peerDeviceList(l10n, peers);
    final headline = peers.length == 1
        ? l10n.settings_cloudSync_peerRequiresUpdate_bannerNamed(list)
        : l10n.settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(list);
    final action = UpdateChannelConfig.isStoreChannel(channel)
        ? l10n.settings_cloudSync_peerRequiresUpdate_storeAction
        : switch (releaseChannel) {
            ReleaseChannel.beta =>
              l10n.settings_cloudSync_peerRequiresUpdate_updateAction,
            ReleaseChannel.stable =>
              l10n.settings_cloudSync_peerRequiresUpdate_stableAction,
          };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.system_update_alt, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$headline $action',
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
