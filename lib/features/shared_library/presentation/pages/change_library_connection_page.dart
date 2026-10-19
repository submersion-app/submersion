import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/shared_library/library_connection_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_connection_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_location_fields.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Points this device's connection to a library at another account or
/// folder that holds the same library (issue #3389). Nothing is saved
/// until a check finds this library there, and the save checks again.
class ChangeLibraryConnectionPage extends ConsumerStatefulWidget {
  const ChangeLibraryConnectionPage({super.key, required this.libraryId});

  final String libraryId;

  @override
  ConsumerState<ChangeLibraryConnectionPage> createState() =>
      _ChangeLibraryConnectionPageState();
}

class _ChangeLibraryConnectionPageState
    extends ConsumerState<ChangeLibraryConnectionPage> {
  late final _location = LibraryLocationController()..addListener(_relayout);
  final _secret = TextEditingController();
  bool _seeded = false;
  bool _busy = false;
  String? _error;
  LibraryLocationCheck? _result;

  /// The passphrase that opened a locked copy, used again to save.
  String? _usedSecret;

  void _relayout() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _location.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _edited() => setState(() {
    _result = null;
    _usedSecret = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final libraries = ref.watch(sharedLibrariesProvider).valueOrNull;
    SharedLibrary? library;
    for (final l in libraries ?? const <SharedLibrary>[]) {
      if (l.id == widget.libraryId) library = l;
    }
    if (library != null && !_seeded) {
      _seeded = true;
      _location.seed(
        folder: library.prefix,
        accountId: library.connectedAccountId,
      );
    }
    // Own servers only: no Google or iCloud probe to list S3 and WebDAV.
    final groups = ref.watch(accountGroupsOfKindsProvider(libraryKindsKey));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharedLibrary_connection_change)),
      body: library == null
          ? Center(
              child: libraries == null
                  ? const CircularProgressIndicator()
                  // Left meanwhile, or reached by a stale link.
                  : Text(l10n.sharedLibrary_list_empty),
            )
          // A reload keeps the form; see the connect page.
          : groups.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (all) => _body(context, library!, libraryServers(all)),
            ),
    );
  }

  Widget _body(
    BuildContext context,
    SharedLibrary library,
    List<AccountGroup> list,
  ) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Repointing is how a library whose account was removed
        // here is reached again: say so, rather than quietly
        // starting from another account.
        if (list.holding(library.connectedAccountId) == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.sharedLibrary_connection_accountMissing,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        LibraryLocationFields(
          controller: _location,
          servers: list,
          enabled: !_busy,
          onEdited: _edited,
        ),
        if (list.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.settings_accounts_add),
              onPressed: () async {
                final added = await addLibraryServer(context);
                if (added != null) _location.selectServer(added);
              },
            ),
          ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              onPressed: _busy ? null : () => _check(),
              child: Text(l10n.sharedLibrary_connection_check),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_result case final result?) ...[
          const SizedBox(height: 16),
          ..._outcome(l10n, result),
        ],
      ],
    );
  }

  List<Widget> _outcome(AppLocalizations l10n, LibraryLocationCheck result) {
    Widget save(String label, {required bool acceptOlder}) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FilledButton(
        onPressed: _busy ? null : () => _save(acceptOlder: acceptOlder),
        child: Text(label),
      ),
    );
    final name = result.foundName;
    return switch (result.verdict) {
      LibraryLocationVerdict.same => [
        Text(l10n.sharedLibrary_connection_same(name ?? '')),
        const SizedBox(height: 8),
        save(l10n.sharedLibrary_connection_save, acceptOlder: false),
      ],
      LibraryLocationVerdict.olderCopy => [
        Text(l10n.sharedLibrary_connection_olderCopy),
        const SizedBox(height: 8),
        save(l10n.sharedLibrary_connection_saveAnyway, acceptOlder: true),
      ],
      LibraryLocationVerdict.locked => [
        Text(l10n.sharedLibrary_encrypted_probe),
        const SizedBox(height: 8),
        TextField(
          key: const Key('library-secret'),
          controller: _secret,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.sharedLibrary_encrypted_passphrase,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.tonal(
            onPressed: _busy ? null : () => _check(secret: _secret.text),
            child: Text(l10n.sharedLibrary_encrypted_unlock),
          ),
        ),
      ],
      LibraryLocationVerdict.differentLibrary => [
        Text(
          name == null
              ? l10n.sharedLibrary_connection_differentUnnamed
              : l10n.sharedLibrary_connection_different(name),
        ),
      ],
      LibraryLocationVerdict.noLibrary => [
        Text(l10n.sharedLibrary_connection_none),
      ],
      LibraryLocationVerdict.retired => [Text(l10n.sharedLibrary_retired)],
      LibraryLocationVerdict.needsNewerApp => [
        Text(l10n.sharedLibrary_connect_needsNewerApp),
      ],
    };
  }

  Future<void> _check({String? secret}) async {
    if (_location.server == null) return;
    final problem = libraryFolderProblem(context.l10n, _location.folder);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Checked through a signed-in row of the server; nothing is saved
      // until a check finds this library there and the diver saves.
      final account = _location.probeAccount();
      if (account == null) return;
      final result = await ref
          .read(libraryConnectionServiceProvider)
          .check(
            libraryId: widget.libraryId,
            diverId: diverId,
            account: account,
            prefix: _location.folder,
            secret: secret,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _usedSecret = secret;
      });
    } catch (e) {
      if (mounted) setState(() => _error = libraryErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({required bool acceptOlder}) async {
    if (_location.account == null) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    final l10n = context.l10n;
    // Kept for the sync after the save, should the page close meanwhile.
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await _location.resolveAccount(
        ref.read(accountGroupServiceProvider),
      );
      if (account == null) return;
      await ref
          .read(libraryConnectionServiceProvider)
          .repoint(
            libraryId: widget.libraryId,
            diverId: diverId,
            account: account,
            prefix: _location.folder,
            secret: _usedSecret,
            acceptOlder: acceptOlder,
          );
    } on LibraryLocationRejected catch (e) {
      // The folder changed since the check: say what is there now.
      if (mounted) setState(() => _result = e.check);
      return;
    } catch (e) {
      if (mounted) setState(() => _error = libraryErrorText(l10n, e));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    unawaited(
      container
          .read(sharedLibrarySyncProvider.notifier)
          .syncOne(widget.libraryId),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.sharedLibrary_connection_saved)),
    );
    Navigator.of(context).pop();
  }
}
