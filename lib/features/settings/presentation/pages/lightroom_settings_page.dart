import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/adapters/lightroom_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/lightroom/lightroom_models.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/media/presentation/helpers/lightroom_scan_helper.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/lightroom_connect_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings page for the Adobe Lightroom connector: BYO-credentials
/// connect flow when disconnected; account, album filter, auto-poll,
/// manual scan, and disconnect when connected.
class LightroomSettingsPage extends ConsumerStatefulWidget {
  const LightroomSettingsPage({super.key});

  @override
  ConsumerState<LightroomSettingsPage> createState() =>
      _LightroomSettingsPageState();
}

class _LightroomSettingsPageState extends ConsumerState<LightroomSettingsPage> {
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final l10n = context.l10n;
    final authManager = ref.read(lightroomAuthManagerProvider);
    final clientId = _clientIdController.text.trim();
    if (clientId.isEmpty) return;

    final connected = await showDialog<bool>(
      context: context,
      builder: (_) => LightroomConnectDialog(
        authManager: authManager,
        clientId: clientId,
        clientSecret: _clientSecretController.text,
      ),
    );
    if (connected != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // Fetch identity and catalog, persist them on the auth blob, then
      // create the connector account row that flips every provider.
      final api = ref.read(lightroomApiClientProvider);
      final account = await api.getAccount();
      final catalogId = await api.getCatalogId();
      final auth = await authManager.loadAuth();
      if (auth != null) {
        await authManager.updateAuth(
          auth.copyWith(
            catalogId: catalogId,
            displayName: account.fullName,
            email: account.email,
          ),
        );
      }
      final created = await ref
          .read(connectedAccountsRepositoryProvider)
          .create(
            kind: AccountKind.adobeLightroom,
            label: account.fullName ?? account.email ?? 'Adobe account',
            accountIdentifier: catalogId,
          );
      // The OAuth dance above wrote tokens to the legacy connect-time key;
      // copy them to the account's own key (runtime reads only that one).
      await ref
          .read(accountCredentialsStoreProvider)
          .rekeyFromLegacy(
            legacyKey: LightroomAuthStore.storageKey,
            accountId: created.id,
          );
      ref.invalidate(lightroomAccountProvider);
    } on Exception catch (e) {
      if (!mounted) return;
      final message = switch (e) {
        CloudStorageException(:final displayMessage) => displayMessage,
        _ => e.toString(),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settings_lightroom_connect_failed(message)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect(domain.ConnectedAccount account) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settings_lightroom_disconnect_confirmTitle),
        content: Text(l10n.settings_lightroom_disconnect_confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.settings_lightroom_disconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Clear both credential locations: the account's own key (runtime) and
    // the legacy connect-time key (scratch from the OAuth dance).
    final adapter =
        ref
                .read(accountProviderRegistryProvider)
                .adapterFor(AccountKind.adobeLightroom)
            as LightroomAccountAdapter;
    await adapter.authManagerFor(account).disconnect();
    await ref.read(lightroomAuthManagerProvider).disconnect();
    await ref.read(lightroomConnectorStateProvider(account.id)).clear();
    await ref.read(connectedAccountsRepositoryProvider).delete(account.id);
    ref.invalidate(lightroomAccountProvider);
  }

  Future<void> _editAlbumFilter(domain.ConnectedAccount account) async {
    final l10n = context.l10n;
    final catalogId = account.accountIdentifier;
    if (catalogId == null) return;
    final state = ref.read(lightroomConnectorStateProvider(account.id));
    final selected = (await state.albumIds()).toSet();
    if (!mounted) return;

    final api = ref.read(lightroomApiClientProvider);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settings_lightroom_albumFilter_title),
        content: SizedBox(
          width: 360,
          child: FutureBuilder<List<LightroomAlbum>>(
            future: api.listAlbums(catalogId),
            builder: (ctx, snapshot) {
              final albums = snapshot.data;
              if (snapshot.hasError) {
                return Text(snapshot.error.toString());
              }
              if (albums == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return StatefulBuilder(
                builder: (ctx, setDialogState) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final album in albums)
                      CheckboxListTile(
                        title: Text(album.name),
                        value: selected.contains(album.id),
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selected.add(album.id);
                          } else {
                            selected.remove(album.id);
                          }
                        }),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(selected),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
    if (result == null) return;
    await state.setAlbumIds(result.toList());
    if (mounted) setState(() {});
  }

  Future<void> _scanAll() async {
    final dives = await ref.read(diveRepositoryProvider).getAllDives();
    if (!mounted) return;
    await runLightroomScan(context, ref, dives);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(lightroomAccountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_lightroom_title)),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (account) => account == null
            ? _disconnectedBody(l10n)
            : _connectedBody(l10n, account),
      ),
    );
  }

  Widget _disconnectedBody(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.settings_lightroom_subtitle),
        const SizedBox(height: 16),
        TextField(
          controller: _clientIdController,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: l10n.settings_lightroom_clientId_label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clientSecretController,
          enabled: !_busy,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.settings_lightroom_clientSecret_label,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.settings_lightroom_clientId_help(
            AdobeImsAuthManager.redirectUri,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy || _clientIdController.text.trim().isEmpty
              ? null
              : _connect,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link),
          label: Text(l10n.settings_lightroom_connect),
        ),
      ],
    );
  }

  Widget _connectedBody(
    AppLocalizations l10n,
    domain.ConnectedAccount account,
  ) {
    final state = ref.read(lightroomConnectorStateProvider(account.id));
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(l10n.settings_lightroom_connected(account.label)),
          subtitle: FutureBuilder<DateTime?>(
            future: state.lastPollAt(),
            builder: (_, snapshot) {
              final last = snapshot.data;
              if (last == null) return const SizedBox.shrink();
              return Text(
                l10n.settings_lightroom_lastPoll(
                  MaterialLocalizations.of(
                    context,
                  ).formatShortDate(last.toLocal()),
                ),
              );
            },
          ),
          trailing: FutureBuilder<String?>(
            future: state.lastError(),
            builder: (_, snapshot) => snapshot.data == null
                ? const SizedBox.shrink()
                : Chip(
                    label: Text(l10n.settings_lightroom_needsReauth),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                  ),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.photo_album_outlined),
          title: Text(l10n.settings_lightroom_albumFilter_title),
          subtitle: FutureBuilder<List<String>>(
            future: state.albumIds(),
            builder: (_, snapshot) => Text(
              (snapshot.data?.isEmpty ?? true)
                  ? l10n.settings_lightroom_albumFilter_all
                  : '${snapshot.data!.length}',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _editAlbumFilter(account),
        ),
        FutureBuilder<bool>(
          future: state.autoPollEnabled(),
          builder: (_, snapshot) => SwitchListTile(
            secondary: const Icon(Icons.autorenew),
            title: Text(l10n.settings_lightroom_autoPoll_title),
            value: snapshot.data ?? true,
            onChanged: (enabled) async {
              await state.setAutoPollEnabled(enabled);
              if (mounted) setState(() {});
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_sync_outlined),
          title: Text(l10n.settings_lightroom_scanNow),
          onTap: _scanAll,
        ),
        const Divider(),
        ListTile(
          leading: Icon(
            Icons.link_off,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            l10n.settings_lightroom_disconnect,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () => _disconnect(account),
        ),
      ],
    );
  }
}
