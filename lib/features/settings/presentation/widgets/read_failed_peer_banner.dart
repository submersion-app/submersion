import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Names the devices whose changeset read failed on the last pull.
///
/// A read failure is transient by design: the peer's cursor stays put and the
/// next sync retries, so this is informational rather than a call to action.
/// Without it a run in which a peer's data silently stopped merging would
/// look identical to a fully converged one (issue #1417). Mirrors
/// SkippedPeerBanner: zero-noise resting state, appears only when a peer
/// actually failed.
class ReadFailedPeerBanner extends StatelessWidget {
  const ReadFailedPeerBanner({super.key, required this.peers});

  /// A null name means the peer's manifest named no device (or the failure
  /// came before the manifest could be parsed at all).
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
        ? l10n.settings_cloudSync_peerReadFailed_banner(list)
        : l10n.settings_cloudSync_peerReadFailed_bannerPlural(list);

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
