import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One coherent entry point for everything photo/media related, grouped by
/// the two-layer model (program spec section 7): link sources ("where
/// photos come from") and the media store ("where copies are kept"), plus
/// the account roster and the guided setup flow.
class PhotosMediaHubPage extends ConsumerWidget {
  const PhotosMediaHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_photosMedia_title),
        actions: [
          IconButton(
            tooltip: l10n.settings_photosMedia_guidedSetup,
            icon: const Icon(Icons.checklist_outlined),
            onPressed: () => context.push('/settings/photos-media/setup'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vertical-only margin: this ListView already pads 16 on all
          // sides, so the default horizontal margin would double-inset.
          const PendingSetupCard(margin: EdgeInsets.only(bottom: 16)),
          _header(context, l10n.settings_photosMedia_sourcesHeader),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l10n.settings_photosMedia_photoSources_title),
                  subtitle: Text(
                    l10n.settings_photosMedia_photoSources_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/media-sources'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: Text(l10n.settings_lightroom_title),
                  subtitle: Text(l10n.settings_lightroom_subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/lightroom'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.rss_feed_outlined),
                  title: Text(l10n.settings_photosMedia_networkSources_title),
                  subtitle: Text(
                    l10n.settings_photosMedia_networkSources_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/settings/media-sources/network-sources'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _header(context, l10n.settings_photosMedia_storageHeader),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.perm_media_outlined),
                  title: Text(l10n.settings_mediaStorage_entry_title),
                  subtitle: Text(l10n.settings_mediaStorage_entry_subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/media-storage'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.swap_vert_outlined),
                  title: Text(l10n.settings_mediaStorage_transfers_title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/settings/media-storage/transfers'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _header(context, l10n.settings_photosMedia_accountsHeader),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(l10n.settings_connectedAccounts_title),
              subtitle: Text(l10n.settings_connectedAccounts_subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/connected-accounts'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
