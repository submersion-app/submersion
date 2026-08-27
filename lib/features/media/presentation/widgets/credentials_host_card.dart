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
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.l10n.media_credentials_savedHostsTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          asyncHosts.when(
            data: (hosts) => hosts.isEmpty
                ? ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(context.l10n.media_credentials_emptyTitle),
                    subtitle: Text(
                      context.l10n.media_credentials_emptySubtitle,
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
            loading: () =>
                ListTile(title: Text(context.l10n.media_credentials_loading)),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(context.l10n.media_credentials_loadError),
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
      subtitle: Text(_subtitle(context.l10n)),
      trailing: PopupMenuButton<_HostAction>(
        tooltip: context.l10n.common_action_more,
        onSelected: (action) => _handle(context, ref, action),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _HostAction.test,
            child: Text(context.l10n.media_credentials_actionTest),
          ),
          PopupMenuItem(
            value: _HostAction.edit,
            child: Text(context.l10n.common_action_edit),
          ),
          PopupMenuItem(
            value: _HostAction.delete,
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final parts = <String>[];
    parts.add(l10n.media_credentials_authLabel(host.authType));
    if (host.displayName != null && host.displayName!.isNotEmpty) {
      parts.add(host.displayName!);
    }
    if (host.lastUsedAt != null) {
      parts.add(
        l10n.media_credentials_lastUsed(
          _relativeFromMillis(l10n, host.lastUsedAt!),
        ),
      );
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
                ? context.l10n.media_credentials_testOk(host.hostname)
                : context.l10n.media_credentials_testFailed(host.hostname),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.media_credentials_testError('$e'))),
      );
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(networkCredentialsServiceProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.l10n.media_credentials_deleteTitle(host.hostname),
        ),
        content: Text(dialogContext.l10n.media_credentials_deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.common_action_delete),
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
        SnackBar(
          content: Text(context.l10n.media_credentials_deleted(host.hostname)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.media_credentials_deleteError('$e')),
        ),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: host.displayName ?? '');
    final updated = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.l10n.media_credentials_editTitle(host.hostname),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: dialogContext.l10n.common_label_displayName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(dialogContext.l10n.common_action_save),
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
        SnackBar(content: Text(context.l10n.media_credentials_saveError('$e'))),
      );
    }
  }
}

enum _HostAction { test, edit, delete }

/// Converts an epoch-millis timestamp to a short relative string. Mirrors
/// the format produced by the plan's original `_relative(DateTime)` helper.
String _relativeFromMillis(AppLocalizations l10n, int millis) {
  final when = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  final diff = DateTime.now().toUtc().difference(when);
  if (diff.inMinutes < 1) return l10n.common_relativeTime_justNow;
  if (diff.inHours < 1) {
    return l10n.common_relativeTime_minutesAgo(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return l10n.common_relativeTime_hoursAgo(diff.inHours);
  }
  if (diff.inDays < 30) {
    return l10n.common_relativeTime_daysAgo(diff.inDays);
  }
  return l10n.common_relativeTime_monthsAgo((diff.inDays / 30).floor());
}
