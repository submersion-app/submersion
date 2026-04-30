// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 10. The page is pure composition: it stacks Tasks 6/7/8's cards in
// a `ListView` and adds a final "Scan all network media" tonal action that
// opens Task 9's `NetworkScanDialog`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/widgets/credentials_host_card.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_subscription_card.dart';
import 'package:submersion/features/media/presentation/widgets/network_cache_card.dart';
import 'package:submersion/features/media/presentation/widgets/network_scan_dialog.dart';

/// Settings -> Data -> Media Sources -> Network Sources page.
///
/// Hosts:
///  - Saved hosts (per-host credentials)
///  - Manifest subscriptions
///  - Cache management
///  - Scan all network media (HTTP scan dialog launcher)
class NetworkSourcesPage extends ConsumerWidget {
  const NetworkSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // TODO(media): l10n
      appBar: AppBar(title: const Text('Network Sources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CredentialsHostCard(),
          const SizedBox(height: 16),
          const ManifestSubscriptionCard(),
          const SizedBox(height: 16),
          const NetworkCacheCard(),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.travel_explore_outlined),
            // TODO(media): l10n
            label: const Text('Scan all network media'),
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => const NetworkScanDialog(),
            ),
          ),
          const SizedBox(height: 16),
          // TODO(media): l10n
          Text(
            'Re-checks every URL- or manifest-imported photo against its '
            'host. Marks unreachable items so they show "missing" in your '
            'library and can be cleaned up.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
