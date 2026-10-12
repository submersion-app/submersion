import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
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
              children: [_accountForm(), ..._errorLine(context)],
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final setup = ref.read(libraryAccountSetupProvider);
      final account = _newKind == AccountKind.s3
          ? await setup.saveS3(_s3.build())
          // A self-signed server is offered for trust, as in the WebDAV
          // settings, before its pin is saved with the account.
          : await setup.saveWebDav(
              await runWithCertificateTrust(
                context,
                _webdav,
                setup.reachWebDav,
              ),
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
    if (!SharedLibraryTransport.isValidPrefix(_prefix.text.trim())) {
      setState(
        () => _error = context.l10n.settings_webdavConfig_validation_folder,
      );
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = libraryErrorText(context.l10n, e));
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
      setState(() => _error = libraryErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
