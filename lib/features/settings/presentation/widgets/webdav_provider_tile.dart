import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The WebDAV row in Cloud Sync's provider list. Tapping selects WebDAV once
/// it is configured, otherwise opens its settings; the gear always edits.
class WebDavProviderTile extends ConsumerWidget {
  const WebDavProviderTile({
    super.key,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
  });

  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(webdavConfigProvider).valueOrNull;
    return Semantics(
      selected: isSelected,
      child: ListTile(
        key: const Key('webdav-provider-tile'),
        leading: const Icon(Icons.folder_shared),
        title: Text(l10n.settings_cloudSync_provider_webdav_title),
        subtitle: Text(
          config?.displayLabel ??
              l10n.settings_cloudSync_provider_webdav_subtitle,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.green,
                semanticLabel: l10n.settings_cloudSync_provider_connected,
              ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settings_cloudSync_provider_webdav_edit,
              onPressed: onEdit,
            ),
          ],
        ),
        onTap: config != null ? onSelect : onEdit,
      ),
    );
  }
}
