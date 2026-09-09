import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/features/media/presentation/providers/google_photos_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings page for the Google Photos connector: a one-tap connect flow
/// when disconnected; the connected account plus disconnect when connected.
///
/// The import flow itself (opening the Google picker, downloading the
/// chosen photos, matching them to dives) is a follow-up; this page only
/// establishes and tears down the connection.
class GooglePhotosSettingsPage extends ConsumerStatefulWidget {
  const GooglePhotosSettingsPage({super.key});

  @override
  ConsumerState<GooglePhotosSettingsPage> createState() =>
      _GooglePhotosSettingsPageState();
}

class _GooglePhotosSettingsPageState
    extends ConsumerState<GooglePhotosSettingsPage> {
  bool _busy = false;

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final auth = await ref.read(googlePhotosConnectProvider).run();
      await _finishConnect(auth);
    } on Exception catch (e) {
      if (!mounted) return;
      final message = e is GooglePhotosAuthException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.settings_googlePhotos_connectFailed(message),
          ),
        ),
      );
      setState(() => _busy = false);
    }
  }

  /// Shared post-sign-in work: create or reuse the roster row, then move
  /// the connect-time tokens ([GooglePhotosConnect.run] wrote them under the
  /// default store key) onto the account's own key.
  Future<void> _finishConnect(GooglePhotosAuthData auth) async {
    final label = auth.displayName ?? auth.email ?? 'Google account';

    final repo = ref.read(connectedAccountsRepositoryProvider);
    final existing = await repo.getByKind(AccountKind.googlePhotos);
    final target =
        existing ??
        await repo.create(kind: AccountKind.googlePhotos, label: label);

    await ref
        .read(accountCredentialsStoreProvider)
        .rekeyFromLegacy(
          legacyKey: GooglePhotosAuthStore.storageKey,
          accountId: target.id,
          overwrite: true,
        );

    ref.invalidate(googlePhotosAccountProvider);
    ref.invalidate(googlePhotosDeviceStatusProvider);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _disconnect(domain.ConnectedAccount account) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settings_googlePhotos_disconnect_confirmTitle),
        content: Text(l10n.settings_googlePhotos_disconnect_confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settings_googlePhotos_disconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Through the adapter: disconnect(account) revokes with Google, clears
    // the account's own key and evicts the cached auth manager. Then clear
    // the connect-time scratch key and drop the roster row.
    await ref
        .read(accountProviderRegistryProvider)
        .adapterFor(AccountKind.googlePhotos)
        .disconnect(account);
    await ref.read(googlePhotosAuthManagerProvider).disconnect();
    await ref.read(connectedAccountsRepositoryProvider).delete(account.id);

    ref.invalidate(googlePhotosAccountProvider);
    ref.invalidate(googlePhotosDeviceStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusAsync = ref.watch(googlePhotosDeviceStatusProvider);
    final account = ref.watch(googlePhotosAccountProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_googlePhotos_title)),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (status) =>
            status == GooglePhotosDeviceStatus.connected && account != null
            ? _connectedBody(l10n, account)
            : _disconnectedBody(l10n, status),
      ),
    );
  }

  Widget _disconnectedBody(AppLocalizations l10n, GooglePhotosDeviceStatus s) {
    final configured = ref.watch(googlePhotosConnectProvider).isConfigured;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.settings_googlePhotos_subtitle),
        const SizedBox(height: 16),
        if (s == GooglePhotosDeviceStatus.needsSignIn)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.settings_googlePhotos_needsReauth,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton.icon(
          onPressed: (_busy || !configured) ? null : _connect,
          icon: const Icon(Icons.link),
          label: Text(l10n.settings_googlePhotos_connect),
        ),
        if (!configured)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.settings_googlePhotos_unconfigured,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _connectedBody(
    AppLocalizations l10n,
    domain.ConnectedAccount account,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: Text(l10n.settings_googlePhotos_connected(account.label)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _disconnect(account),
          icon: const Icon(Icons.link_off),
          label: Text(l10n.settings_googlePhotos_disconnect),
        ),
      ],
    );
  }
}
