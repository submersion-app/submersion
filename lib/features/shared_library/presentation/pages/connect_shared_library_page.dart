import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Connect a club library (issue #2567): pick an S3 or WebDAV account,
/// name the prefix, then join what is there or create a new library.
class ConnectSharedLibraryPage extends ConsumerStatefulWidget {
  const ConnectSharedLibraryPage({super.key, this.initialPrefix});

  final String? initialPrefix;

  @override
  ConsumerState<ConnectSharedLibraryPage> createState() =>
      _ConnectSharedLibraryPageState();
}

class _ConnectSharedLibraryPageState
    extends ConsumerState<ConnectSharedLibraryPage> {
  late final TextEditingController _prefix = TextEditingController(
    text: widget.initialPrefix ?? '',
  );
  final _libraryName = TextEditingController();
  final _displayName = TextEditingController();
  ConnectedAccount? _account;
  LibraryProbe? _probe;
  String? _probedPrefix;
  bool _busy = false;
  String? _error;
  bool _nameSeeded = false;

  @override
  void dispose() {
    _prefix.dispose();
    _libraryName.dispose();
    _displayName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accounts = ref.watch(eligibleLibraryAccountsProvider);
    final diver = ref.watch(currentDiverProvider).valueOrNull;
    if (!_nameSeeded && diver != null) {
      _displayName.text = diver.name;
      _nameSeeded = true;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharedLibrary_connect_action)),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) {
          if (list.isEmpty) return _noAccounts(context);
          _account ??= list.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<ConnectedAccount>(
                initialValue: _account,
                decoration: InputDecoration(
                  labelText: l10n.sharedLibrary_connect_account_label,
                ),
                items: [
                  for (final a in list)
                    DropdownMenuItem(value: a, child: Text(a.label)),
                ],
                onChanged: (a) => setState(() {
                  _account = a;
                  _probe = null;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('library-prefix'),
                controller: _prefix,
                decoration: InputDecoration(
                  labelText: l10n.sharedLibrary_connect_prefix_label,
                  helperText: l10n.sharedLibrary_connect_prefix_help,
                ),
                onChanged: (_) => setState(() => _probe = null),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _busy ? null : _runProbe,
                  child: Text(l10n.sharedLibrary_connect_probe_action),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_probe != null) ...[const SizedBox(height: 16), _result()],
            ],
          );
        },
      ),
    );
  }

  Widget _noAccounts(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.sharedLibrary_connect_onlyS3Webdav,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => context.push('/settings/connected-accounts'),
              child: Text(l10n.sharedLibrary_connect_account_label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _result() {
    final l10n = context.l10n;
    final probe = _probe!;
    if (probe.needsNewerApp) {
      return Text(l10n.sharedLibrary_connect_needsNewerApp);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!probe.exists) ...[
          Text(l10n.sharedLibrary_connect_notALibrary),
          const SizedBox(height: 8),
          TextField(
            key: const Key('library-name'),
            controller: _libraryName,
            decoration: InputDecoration(
              labelText: l10n.sharedLibrary_connect_create_name_label,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          key: const Key('member-display-name'),
          controller: _displayName,
          decoration: InputDecoration(
            labelText: l10n.sharedLibrary_connect_displayName_label,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: Text(
            probe.exists
                ? l10n.sharedLibrary_connect_join_action(probe.name ?? '')
                : l10n.sharedLibrary_connect_create_action,
          ),
        ),
      ],
    );
  }

  Future<void> _runProbe() async {
    final account = _account;
    if (account == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final probe = await ref
          .read(sharedLibraryMembershipServiceProvider)
          .probe(account: account, prefix: _prefix.text.trim());
      if (!mounted) return;
      setState(() {
        _probe = probe;
        _probedPrefix = _prefix.text.trim();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    final account = _account;
    final probe = _probe;
    if (account == null || probe == null) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    final displayName = _displayName.text.trim();
    if (displayName.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(sharedLibraryMembershipServiceProvider);
      final prefix = _probedPrefix ?? _prefix.text.trim();
      final library = probe.exists
          ? await service.join(
              account: account,
              prefix: prefix,
              diverId: diverId,
              displayName: displayName,
            )
          : await service.create(
              account: account,
              prefix: prefix,
              name: _libraryName.text.trim().isEmpty
                  ? prefix
                  : _libraryName.text.trim(),
              diverId: diverId,
              displayName: displayName,
            );
      ref.invalidate(currentMembershipsProvider);
      ref.invalidate(sitesProvider);
      if (!mounted) return;
      await ref.read(sharedLibrarySyncProvider.notifier).syncOne(library.id);
      ref.invalidate(sitesProvider);
      if (!mounted) return;
      context.pushReplacement('/settings/club-libraries/${library.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
