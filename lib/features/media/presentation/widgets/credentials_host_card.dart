// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 6. Deviations from the plan code:
//
// - The plan calls `NetworkCredentialsService.testCredentials(host)`,
//   `updateHost(host)`, and `deleteHost(id)`. The real Phase 3a service
//   exposes `delete(id)` and (Phase 3c seam) `updateDisplayName(id, name)`.
//   "Test credentials" is implemented here against [NetworkUrlResolver.fetch]
//   probing `https://<hostname>/`; the plan note (line 1854) blesses that
//   alternative.
// - The plan imports `domain/entities/network_credential_host.dart`. That
//   file does not exist; `NetworkCredentialHost` is the Drift dataclass
//   exported from `core/database/database.dart` (same adaptation already
//   applied in Task 5).
// - The plan's `NetworkCredentialHost.copyWith({String? displayName})` does
//   not match the Drift-generated signature (`Value<String?> displayName`).
//   We bypass `copyWith` entirely by calling
//   `service.updateDisplayName(id, name)` directly.
// - The plan compares `host != hosts.last` to draw a divider. That works at
//   runtime but reads as a value-equality check; we switch to index-based
//   iteration (`for (var i = 0; ...)`) to make the intent explicit.
// - `lastUsedAt` is stored as `int?` epoch millis (not `DateTime`); the
//   relative formatter takes the int and converts internally.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/services/network_url_resolver.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

/// Settings -> Network Sources -> Saved hosts card.
///
/// Lists `network_credential_hosts` rows. Per row:
/// - Hostname (title)
/// - Auth type + display name + last-used info (subtitle)
/// - Action menu (Test credentials, Edit, Delete)
class CredentialsHostCard extends ConsumerWidget {
  const CredentialsHostCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHosts = ref.watch(savedHostsProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                // TODO(media): l10n
                Text(
                  'Saved hosts',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
          ),
          asyncHosts.when(
            data: (hosts) => hosts.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.lock_outline),
                    // TODO(media): l10n
                    title: Text('No saved credentials'),
                    subtitle: Text(
                      'Per-host credentials added during URL or manifest '
                      'imports show up here.',
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < hosts.length; i++) ...[
                        _HostTile(host: hosts[i]),
                        if (i < hosts.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
            loading: () => const ListTile(
              // TODO(media): l10n
              title: Text('Loading saved hosts...'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              // TODO(media): l10n
              title: const Text('Could not load saved hosts'),
              subtitle: Text('$e'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostTile extends ConsumerWidget {
  const _HostTile({required this.host});
  final NetworkCredentialHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.lock_outline),
      title: Text(host.hostname),
      subtitle: Text(_subtitle()),
      trailing: PopupMenuButton<_HostAction>(
        // TODO(media): l10n
        tooltip: 'More',
        onSelected: (action) => _handle(context, ref, action),
        itemBuilder: (_) => const [
          // TODO(media): l10n
          PopupMenuItem(
            value: _HostAction.test,
            child: Text('Test credentials'),
          ),
          // TODO(media): l10n
          PopupMenuItem(value: _HostAction.edit, child: Text('Edit')),
          // TODO(media): l10n
          PopupMenuItem(value: _HostAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    parts.add('Auth: ${host.authType}');
    if (host.displayName != null && host.displayName!.isNotEmpty) {
      parts.add(host.displayName!);
    }
    if (host.lastUsedAt != null) {
      parts.add('Last used ${_relativeFromMillis(host.lastUsedAt!)}');
    }
    return parts.join('  -  ');
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _HostAction action,
  ) async {
    switch (action) {
      case _HostAction.test:
        await _testCredentials(context, ref);
      case _HostAction.edit:
        await _showEditDialog(context, ref);
      case _HostAction.delete:
        await _confirmAndDelete(context, ref);
    }
  }

  Future<void> _testCredentials(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final resolver = ref.read(networkUrlResolverProvider);
    try {
      final result = await resolver.fetch(
        Uri.parse('https://${host.hostname}/'),
      );
      if (!context.mounted) return;
      final ok = result is NetworkBytesOk;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                // TODO(media): l10n
                ? 'Credentials OK for ${host.hostname}'
                // TODO(media): l10n
                : 'Credentials failed for ${host.hostname}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Test failed: $e')),
      );
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(networkCredentialsServiceProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // TODO(media): l10n
        title: Text('Delete ${host.hostname}?'),
        // TODO(media): l10n
        content: const Text(
          'Removes the saved credentials. Items linked through this host '
          'will start showing "Sign in required" until you re-add them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            // TODO(media): l10n
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            // TODO(media): l10n
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    try {
      await service.delete(host.id);
      if (!context.mounted) return;
      ref.invalidate(savedHostsProvider);
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Deleted ${host.hostname}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: host.displayName ?? '');
    final updated = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // TODO(media): l10n
        title: Text('Edit ${host.hostname}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            // TODO(media): l10n
            labelText: 'Display name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            // TODO(media): l10n
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            // TODO(media): l10n
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(networkCredentialsServiceProvider);
    final newName = updated.isEmpty ? null : updated;
    try {
      await service.updateDisplayName(host.id, newName);
      if (!context.mounted) return;
      ref.invalidate(savedHostsProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}

enum _HostAction { test, edit, delete }

/// Converts an epoch-millis timestamp to a short relative string. Mirrors
/// the format produced by the plan's original `_relative(DateTime)` helper.
String _relativeFromMillis(int millis) {
  final when = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  final diff = DateTime.now().toUtc().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}
