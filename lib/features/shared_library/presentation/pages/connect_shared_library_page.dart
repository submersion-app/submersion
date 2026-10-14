import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_restore_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/s3_server_fields.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/picked_file_path.dart';
import 'package:submersion/features/shared_library/presentation/widgets/recovery_code_dialog.dart';
import 'package:submersion/features/shared_library/presentation/widgets/storage_setup_sheet.dart';
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

  late final TextEditingController _prefix = TextEditingController(
    text: widget.initialPrefix ?? '',
  );
  final _libraryName = TextEditingController();
  final _displayName = TextEditingController();

  /// The passphrase or recovery code of an encrypted library, and whether
  /// it unlocked the probed one.
  final _secret = TextEditingController();
  bool _unlocked = false;
  ConnectedAccount? _account;
  LibraryProbe? _probe;
  String? _probedPrefix;
  bool _busy = false;
  String? _error;
  bool _nameSeeded = false;

  // An account set up right here (issue #2567): its own folder,
  // submersion-sites, is fixed by LibraryAccountSetup.
  bool _addingAccount = false;
  AccountKind _newKind = AccountKind.s3;
  String? _selectedAccountId;
  final _accountFormKey = GlobalKey<FormState>();
  final _s3 = S3FormController(
    defaultPrefix: '${SharedLibraryLayout.librariesDir}/',
  );
  final _webdav = WebDavFormController(
    defaultFolder: SharedLibraryLayout.librariesDir,
  );

  @override
  void dispose() {
    _prefix.dispose();
    _libraryName.dispose();
    _displayName.dispose();
    _secret.dispose();
    _s3.dispose();
    _webdav.dispose();
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
          if (list.isEmpty && !_addingAccount) return _noAccounts(context);
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _folderField(),
                const SizedBox(height: 12),
                _accountForm(),
                ..._errorLine(context),
              ],
            );
          }
          // The list rebuilds with new instances whenever an account
          // changes: keep the chosen one by id, or the dropdown loses it.
          final wanted = _selectedAccountId ?? _account?.id;
          _account = list.firstWhere(
            (a) => a.id == wanted,
            orElse: () => list.first,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // The folder first: an account added below is saved for it.
              _folderField(),
              const SizedBox(height: 12),
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
                  _selectedAccountId = a?.id;
                  _probe = null;
                }),
              ),
              if (_addingAccount) ...[
                const SizedBox(height: 12),
                _accountForm(),
              ] else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.sharedLibrary_connect_addAccount),
                    onPressed: () => setState(() => _addingAccount = true),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: _busy ? null : _runProbe,
                  child: Text(l10n.sharedLibrary_connect_probe_action),
                ),
              ),
              ..._errorLine(context),
              if (_probe != null) ...[const SizedBox(height: 16), _result()],
            ],
          );
        },
      ),
    );
  }

  Widget _folderField() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('library-prefix'),
          controller: _prefix,
          decoration: InputDecoration(
            labelText: l10n.sharedLibrary_connect_prefix_label,
            helperText: l10n.sharedLibrary_connect_prefix_help,
            helperMaxLines: 3,
          ),
          onChanged: (_) => setState(() => _probe = null),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.help_outline),
            label: Text(l10n.sharedLibrary_setup_title),
            onPressed: () async {
              final bucket = await _bucketForGuide();
              if (!mounted) return;
              await showStorageSetupSheet(
                context,
                bucket: bucket,
                folder: _prefix.text,
              );
            },
          ),
        ),
      ],
    );
  }

  /// The bucket the example policies name: the one being typed in, or the
  /// selected S3 account's own (from its stored settings: an account made
  /// for personal sync carries a label of its own), else a placeholder.
  Future<String> _bucketForGuide() async {
    if (_addingAccount && _newKind == AccountKind.s3) {
      final typed = _s3.bucket.text.trim();
      if (typed.isNotEmpty) return typed;
    }
    final account = _account;
    if (account != null && account.kind == AccountKind.s3) {
      final stored = await ref
          .read(libraryAccountSetupProvider)
          .s3Bucket(account.id);
      if (stored != null) return stored;
    }
    return 'your-bucket';
  }

  /// Why the typed folder cannot hold a library, or null when it can.
  String? _folderProblem() {
    final folder = _prefix.text.trim();
    if (SharedLibraryTransport.leavesLibraries(folder)) {
      return context.l10n.settings_webdavConfig_validation_folder;
    }
    if (SharedLibraryTransport.startsReserved(folder)) {
      return context.l10n.sharedLibrary_connect_reservedFolder;
    }
    if (SharedLibraryTransport.hasPolicyWildcards(folder)) {
      return context.l10n.sharedLibrary_connect_folderChars;
    }
    return null;
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
              label: Text(l10n.sharedLibrary_connect_addAccount),
              onPressed: () => setState(() => _addingAccount = true),
            ),
          ],
        ),
      ),
    );
  }

  /// An S3 or WebDAV account, set up here: server and keys only, as the
  /// library's folder comes from the field below.
  Widget _accountForm() {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _accountFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<AccountKind>(
                segments: [
                  ButtonSegment(
                    value: AccountKind.s3,
                    label: Text(l10n.settings_cloudSync_provider_s3_title),
                  ),
                  ButtonSegment(
                    value: AccountKind.webdav,
                    label: Text(l10n.settings_mediaStorage_provider_webdav),
                  ),
                ],
                selected: {_newKind},
                onSelectionChanged: (kinds) =>
                    setState(() => _newKind = kinds.first),
              ),
              const SizedBox(height: 12),
              if (_newKind == AccountKind.s3)
                S3ServerFields(
                  controller: _s3,
                  showPrefix: false,
                  keyPrefix: 'library-s3',
                )
              else
                WebDavServerFields(
                  controller: _webdav,
                  showFolder: false,
                  keyPrefix: 'library-webdav',
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _addingAccount = false),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _saveAccount,
                    child: Text(l10n.sharedLibrary_connect_saveAccount),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAccount() async {
    if (!(_accountFormKey.currentState?.validate() ?? false)) return;
    final problem = _folderProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final folder = _prefix.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final setup = ref.read(libraryAccountSetupProvider);
      final account = _newKind == AccountKind.s3
          ? await setup.saveS3(_s3.build(), folder: folder)
          // A self-signed server is offered for trust, as in the WebDAV
          // settings, before its pin is saved with the account.
          : await setup.saveWebDav(
              await runWithCertificateTrust(
                context,
                _webdav,
                setup.reachWebDav,
              ),
              folder: folder,
            );
      if (!mounted) return;
      ref.invalidate(eligibleLibraryAccountsProvider);
      setState(() {
        _selectedAccountId = account.id;
        _addingAccount = false;
        _probe = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = libraryErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final account = _account;
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
    final account = _account;
    if (account == null) return;
    final problem = _folderProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
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
    context.pushReplacement('/settings/shared-libraries/${library.id}');
  }

  /// Restores a backup file into the empty folder just checked, keeping the
  /// library's id (issue #2567). An encrypted backup asks for its
  /// passphrase, with the page idle while it does.
  Future<void> _restoreFromBackup() async {
    final account = _account;
    final prefix = _probedPrefix;
    if (account == null || prefix == null) return;
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
