import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/settings/presentation/widgets/s3_server_fields.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/storage_setup_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Why [folder] cannot hold a library, or null when it can.
String? libraryFolderProblem(AppLocalizations l10n, String folder) {
  final f = folder.trim();
  if (SharedLibraryTransport.leavesLibraries(f)) {
    return l10n.settings_webdavConfig_validation_folder;
  }
  if (SharedLibraryTransport.startsReserved(f)) {
    return l10n.sharedLibrary_connect_reservedFolder;
  }
  if (SharedLibraryTransport.hasPolicyWildcards(f)) {
    return l10n.sharedLibrary_connect_folderChars;
  }
  return null;
}

/// The folder and storage account a library is reached through, as the
/// connect page and the change-connection page pick them.
class LibraryLocationController extends ChangeNotifier {
  LibraryLocationController({String initialPrefix = '', this.selectedAccountId})
    : prefix = TextEditingController(text: initialPrefix);

  final TextEditingController prefix;

  /// The account chosen by id: the list rebuilds with new instances
  /// whenever an account changes, so the choice is kept by id.
  String? selectedAccountId;

  /// The chosen account as last resolved against the eligible accounts.
  ConnectedAccount? account;

  /// Whether the inline form for a new account is open.
  bool addingAccount = false;

  String get folder => prefix.text.trim();

  void selectAccount(ConnectedAccount? a) {
    account = a;
    selectedAccountId = a?.id;
    notifyListeners();
  }

  void setAddingAccount(bool adding) {
    addingAccount = adding;
    notifyListeners();
  }

  @override
  void dispose() {
    prefix.dispose();
    super.dispose();
  }
}

/// The folder field (with the storage setup guide), the account picker
/// and the inline form adding an S3 or WebDAV account (issue #2567).
/// [onEdited] runs whenever the location changes, so a caller can drop a
/// check made against the old one.
class LibraryLocationFields extends ConsumerStatefulWidget {
  const LibraryLocationFields({
    super.key,
    required this.controller,
    required this.accounts,
    required this.onEdited,
    this.enabled = true,
  });

  final LibraryLocationController controller;

  /// False while the caller is busy (checking, joining): the location and
  /// the account form wait.
  final bool enabled;
  final List<ConnectedAccount> accounts;
  final VoidCallback onEdited;

  @override
  ConsumerState<LibraryLocationFields> createState() =>
      _LibraryLocationFieldsState();
}

class _LibraryLocationFieldsState extends ConsumerState<LibraryLocationFields> {
  // An account set up right here (issue #2567): its own folder,
  // submersion-sites, is fixed by LibraryAccountSetup.
  AccountKind _newKind = AccountKind.s3;
  final _accountFormKey = GlobalKey<FormState>();
  final _s3 = S3FormController(
    defaultPrefix: '${SharedLibraryLayout.librariesDir}/',
  );
  final _webdav = WebDavFormController(
    defaultFolder: SharedLibraryLayout.librariesDir,
  );
  bool _saving = false;
  String? _error;

  LibraryLocationController get _c => widget.controller;

  @override
  void dispose() {
    _s3.dispose();
    _webdav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = widget.accounts;
    if (list.isEmpty) {
      _c.account = null;
    } else {
      final wanted = _c.selectedAccountId ?? _c.account?.id;
      _c.account = list.firstWhere(
        (a) => a.id == wanted,
        orElse: () => list.first,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The folder first: an account added below is saved for it.
        _folderField(),
        const SizedBox(height: 12),
        if (list.isNotEmpty)
          DropdownButtonFormField<ConnectedAccount>(
            initialValue: _c.account,
            // Library account labels name the bucket, host and folder: too
            // long for a phone without an ellipsis.
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.sharedLibrary_connect_account_label,
            ),
            items: [
              for (final a in list)
                DropdownMenuItem(
                  value: a,
                  child: Text(a.displayName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: widget.enabled
                ? (a) {
                    _c.selectAccount(a);
                    widget.onEdited();
                  }
                : null,
          ),
        if (_c.addingAccount) ...[
          if (list.isNotEmpty) const SizedBox(height: 12),
          _accountForm(),
        ] else if (list.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.sharedLibrary_connect_addAccount),
              onPressed: widget.enabled
                  ? () => _c.setAddingAccount(true)
                  : null,
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _folderField() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('library-prefix'),
          controller: _c.prefix,
          // A check running against this location must not find it
          // changed under its result.
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: l10n.sharedLibrary_connect_prefix_label,
            helperText: l10n.sharedLibrary_connect_prefix_help,
            helperMaxLines: 3,
          ),
          onChanged: (_) => widget.onEdited(),
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
                folder: _c.prefix.text,
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
    if (_c.addingAccount && _newKind == AccountKind.s3) {
      final typed = _s3.bucket.text.trim();
      if (typed.isNotEmpty) return typed;
    }
    final account = _c.account;
    if (account != null && account.kind == AccountKind.s3) {
      final stored = await ref
          .read(libraryAccountSetupProvider)
          .s3Bucket(account.id);
      if (stored != null) return stored;
    }
    return 'your-bucket';
  }

  /// An S3 or WebDAV account, set up here: server and keys only, as the
  /// library's folder comes from the field above.
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
                    onPressed: _saving || !widget.enabled
                        ? null
                        : () => _c.setAddingAccount(false),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving || !widget.enabled ? null : _saveAccount,
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
    final problem = libraryFolderProblem(context.l10n, _c.folder);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final folder = _c.folder;
    setState(() {
      _saving = true;
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
      _c
        ..selectedAccountId = account.id
        ..setAddingAccount(false);
      widget.onEdited();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = libraryErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
