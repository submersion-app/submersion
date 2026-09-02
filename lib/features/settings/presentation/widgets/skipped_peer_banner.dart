import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Names the devices the library-epoch fence held back on the last pull.
///
/// Deliberately a conditional banner rather than a standing device list: in a
/// healthy fleet every peer is on the current epoch, so a list would say
/// "everything is fine" and nothing else. The banner has a zero-noise resting
/// state and appears only when there is something to act on. Mirrors the
/// newer-schema banner next to it.
class SkippedPeerBanner extends StatelessWidget {
  const SkippedPeerBanner({super.key, required this.peers});

  /// A null name means the peer published none -- either it is on a manifest
  /// written before the field existed, or nothing identifies it by name.
  final List<({String? name, String shortId})> peers;

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;

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
    final text = labels.length == 1
        ? l10n.settings_cloudSync_peerNeedsAdopt_banner(list)
        : l10n.settings_cloudSync_peerNeedsAdopt_bannerPlural(list);

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
                  text,
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
