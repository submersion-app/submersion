import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_restore_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_location_fields.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/picked_file_path.dart';
import 'package:submersion/features/shared_library/presentation/widgets/recovery_code_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Connect a shared site library (issue #2567): pick an S3 or WebDAV account,
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
  /// Kept for the work that goes on after a join should the page close
  /// meanwhile: `ref` is unusable then.
  late ProviderContainer _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  late final _location = LibraryLocationController(
    initialPrefix: widget.initialPrefix ?? '',
  )..addListener(_relayout);

  void _relayout() {
    if (mounted) setState(() {});
  }

  final _libraryName = TextEditingController();
  final _displayName = TextEditingController();

  /// The passphrase or recovery code of an encrypted library, and whether
  /// it unlocked the probed one.
  final _secret = TextEditingController();
  bool _unlocked = false;
  LibraryProbe? _probe;
  String? _probedPrefix;
  bool _busy = false;
  String? _error;
  bool _nameSeeded = false;

  @override
  void dispose() {
    _location.dispose();
    _libraryName.dispose();
    _displayName.dispose();
    _secret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Own servers only: no Google or iCloud probe to list S3 and WebDAV.
    final groups = ref.watch(accountGroupsOfKindsProvider(libraryKindsKey));
    final diver = ref.watch(currentDiverProvider).valueOrNull;
    if (!_nameSeeded && diver != null) {
      _displayName.text = diver.name;
      _nameSeeded = true;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharedLibrary_connect_action)),
      // A reload (any roster or sync tick) keeps the form: replacing it with
      // a spinner would drop what the diver typed or just chose.
      body: groups.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (all) {
          final list = libraryServers(all);
          if (list.isEmpty) return _noAccounts(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LibraryLocationFields(
                controller: _location,
                servers: list,
                enabled: !_busy,
                onEdited: () => setState(() {
                  _probe = null;
                  _error = null;
                }),
              ),
              if (list.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : _runProbe,
                    // The same words as the change-connection page: it
                    // checks a folder (spec section 4).
                    child: Text(l10n.sharedLibrary_connection_check),
                  ),
                ),
              ],
              ..._errorLine(context),
              if (_probe != null) ...[const SizedBox(height: 16), _result()],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _errorLine(BuildContext context) => [
    if (_error != null) ...[
      const SizedBox(height: 12),
      Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  ];

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
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.settings_accounts_add),
              onPressed: () async {
                final added = await addLibraryServer(context);
                if (added != null) _location.selectServer(added);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _result() {
    final l10n = context.l10n;
    final probe = _probe!;
    if (probe.retired) return Text(l10n.sharedLibrary_retired);
    if (probe.needsNewerApp) {
      return Text(l10n.sharedLibrary_connect_needsNewerApp);
    }
    if (probe.encrypted && !_unlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              onPressed: _busy ? null : _unlockProbe,
              child: Text(l10n.sharedLibrary_encrypted_unlock),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // What the owners say the library is for (issue #3389), so the
        // diver can tell they found the right one before joining.
        if (probe.exists && probe.description != null) ...[
          Text(
            probe.description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
        ],
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
        if (!probe.exists) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.restore),
            label: Text(l10n.sharedLibrary_restoreInto_action),
            onPressed: _busy ? null : _restoreFromBackup,
          ),
        ],
      ],
    );
  }

  /// Opens the probed encrypted library with the typed secret to show its
  /// name; the secret is used again to join.
  Future<void> _unlockProbe() async {
    final account = _location.account;
    final prefix = _probedPrefix;
    if (account == null || prefix == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final probe = await ref
          .read(sharedLibraryMembershipServiceProvider)
          .unlockProbe(account: account, prefix: prefix, secret: _secret.text);
      if (!mounted) return;
      setState(() {
        _probe = probe;
        _unlocked = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = libraryErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runProbe() async {
    if (_location.server == null) return;
    final problem = libraryFolderProblem(context.l10n, _location.folder);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Checked through a signed-in row of the server; nothing is saved
      // until the diver joins or creates.
      final account = _location.probeAccount();
      if (account == null) return;
      final probe = await ref
          .read(sharedLibraryMembershipServiceProvider)
          .probe(account: account, prefix: _location.folder);
      if (!mounted) return;
      setState(() {
        _probe = probe;
        _probedPrefix = _location.folder;
        _unlocked = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = libraryErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Creates the library, then shows its recovery code before anything
  /// else happens. Null when the page went away meanwhile.
  Future<SharedLibrary?> _createShowingRecovery(
    SharedLibraryMembershipService service, {
    required ConnectedAccount account,
    required String prefix,
    required String name,
    required String diverId,
    required String displayName,
  }) async {
    final created = await service.createWithRecovery(
      account: account,
      prefix: prefix,
      name: name,
      diverId: diverId,
      displayName: displayName,
    );
    if (!mounted) return null;
    await showRecoveryCodeDialog(context, created.recoveryCode);
    return mounted ? created.library : null;
  }

  Future<void> _connect() async {
    final probe = _probe;
    if (_location.account == null || probe == null) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    final displayName = _displayName.text.trim();
    if (displayName.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The library's own row on the chosen server, made now that the diver
      // joins or creates.
      final account = await _location.resolveAccount(
        ref.read(accountGroupServiceProvider),
      );
      if (account == null) return;
      final service = ref.read(sharedLibraryMembershipServiceProvider);
      final prefix = _probedPrefix ?? _location.folder;
      final library = probe.exists
          ? await service.join(
              account: account,
              prefix: prefix,
              diverId: diverId,
              displayName: displayName,
              secret: probe.encrypted ? _secret.text : null,
            )
          : await _createShowingRecovery(
              service,
              account: account,
              prefix: prefix,
              name: _libraryName.text.trim().isEmpty
                  ? prefix
                  : _libraryName.text.trim(),
              diverId: diverId,
              displayName: displayName,
            );
      if (library == null) return;
      await _opened(library);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = libraryErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// After a join, create or restore: syncs the library here, then opens
  /// its page. Joined either way, so the library syncs even when the page
  /// closed meanwhile.
  Future<void> _opened(SharedLibrary library) async {
    final container = _container
      ..invalidate(currentMembershipsProvider)
      ..invalidate(sitesProvider);
    await container
        .read(sharedLibrarySyncProvider.notifier)
        .syncOne(library.id);
    container.invalidate(sitesProvider);
    if (!mounted) return;
    context.replaceSettingsPage('/settings/shared-libraries/${library.id}');
  }

  /// Restores a backup file into the empty folder just checked, keeping the
  /// library's id (issue #2567). An encrypted backup asks for its
  /// passphrase, with the page idle while it does.
  Future<void> _restoreFromBackup() async {
    final prefix = _probedPrefix;
    if (_location.account == null || prefix == null) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    final displayName = _displayName.text.trim();
    if (displayName.isEmpty) return;
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(type: FileType.any);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = libraryErrorText(context.l10n, e));
      return;
    }
    final file = picked;
    if (file == null || !mounted) return;
    final l10n = context.l10n;
    final restore = ref.read(libraryRestoreServiceProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await _location.resolveAccount(
        ref.read(accountGroupServiceProvider),
      );
      if (account == null) return;
      String? secret;
      RestoredLibrary? restored;
      while (restored == null) {
        try {
          restored = await withLocalPath(
            file,
            (path) => restore.restoreInto(
              account: account,
              prefix: prefix,
              diverId: diverId,
              displayName: displayName,
              path: path,
              secret: secret,
            ),
          );
        } on BackupNeedsOldKeyError {
          if (!mounted) return;
          setState(() => _busy = false);
          final typed = await promptLibrarySecret(
            context,
            message: secret == null
                ? l10n.sharedLibrary_restoreInto_needsKey
                : l10n.sharedLibrary_encrypted_wrong,
          );
          if (typed == null || !mounted) return;
          secret = typed;
          setState(() => _busy = true);
        }
      }
      if (restored.oldStillThere && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l10n.sharedLibrary_restoreInto_oldStillThere),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      await _opened(restored.library);
    } on BackupRefusedError {
      if (mounted) {
        setState(() => _error = l10n.sharedLibrary_restoreInto_refused);
      }
    } catch (e) {
      if (mounted) setState(() => _error = libraryErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
