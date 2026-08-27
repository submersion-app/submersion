import 'package:flutter/material.dart';

import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Names the devices held back because their sync payloads declare a
/// compatibility floor above this build's database schema.
///
/// Mirrors SkippedPeerBanner: zero-noise resting state, appears only when a
/// peer is actually held. On store-channel builds the call to action
/// acknowledges that the store update may still be in review, rather than
/// telling the user to take an update their channel does not offer yet
/// (issue #1089).
class NewerSchemaPeerBanner extends StatelessWidget {
  const NewerSchemaPeerBanner({
    super.key,
    required this.peers,
    this.channelOverride,
  });

  /// A null name means the peer published none -- either it is on a manifest
  /// written before the field existed, or nothing identifies it by name.
  final List<({String? name, String shortId})> peers;

  /// Test seam: UpdateChannelConfig.current reads a compile-time constant,
  /// which a test binary cannot vary.
  final UpdateChannel? channelOverride;

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final channel = channelOverride ?? UpdateChannelConfig.current;

    final labels = peers
        .map(
          (p) =>
              p.name ??
              l10n.settings_cloudSync_peerNeedsAdopt_unnamedDevice(p.shortId),
        )
        .toList();
    final list = labels.length == 1
        ? labels.single
        : labels
                  .sublist(0, labels.length - 1)
                  .join(l10n.settings_cloudSync_peerNeedsAdopt_listSeparator) +
              l10n.settings_cloudSync_peerNeedsAdopt_listLastSeparator +
              labels.last;
    final headline = labels.length == 1
        ? l10n.settings_cloudSync_peerRequiresUpdate_bannerNamed(list)
        : l10n.settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(list);
    final action = UpdateChannelConfig.isStoreChannel(channel)
        ? l10n.settings_cloudSync_peerRequiresUpdate_storeAction
        : l10n.settings_cloudSync_peerRequiresUpdate_updateAction;

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
