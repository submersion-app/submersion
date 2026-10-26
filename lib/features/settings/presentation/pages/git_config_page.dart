import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/features/settings/presentation/providers/git_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/git_error_text.dart';
import 'package:submersion/features/settings/presentation/widgets/git_host_note.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A Git repository as an account (the account sheet's "Git" entry):
/// repository address, username, access token and branch. Test connection
/// and Save both check the repository, and Save warns before keeping a
/// public one, which syncs only encrypted. Save records the account and
/// pops with its roster row; pointing sync at it is the caller's step.
///
/// With [existing], the form signs that account in again, filled from what
/// this device holds for it.
class GitConfigPage extends ConsumerStatefulWidget {
  const GitConfigPage({super.key, this.existing});

  final AccountGroup? existing;

  @override
  ConsumerState<GitConfigPage> createState() => _GitConfigPageState();
}

class _GitConfigPageState extends ConsumerState<GitConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _repoUrl = TextEditingController();
  final _username = TextEditingController();
  final _token = TextEditingController();
  final _branch = TextEditingController(text: kDefaultGitBranch);
  String? _pinnedCertSha256;
  bool _busy = false;
  bool _userEdited = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_repoUrl, _username, _token, _branch]) {
      c.addListener(_onEdited);
    }
    _loadExisting();
  }

  @override
  void dispose() {
    for (final c in [_repoUrl, _username, _token, _branch]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onEdited() {
    _userEdited = true;
    // The host note follows the address.
    setState(() {});
  }

  GitConfig _build() => GitConfig(
    repoUrl: _repoUrl.text,
    username: _username.text,
    token: _token.text,
    branch: _branch.text,
    pinnedCertSha256: _pinnedCertSha256,
  );

  Future<void> _loadExisting() async {
    final group = widget.existing;
    if (group == null) return;
    try {
      final existing = decodeGitConfig(
        await ref
            .read(accountCredentialsStoreProvider)
            .read(group.rows.first.id),
      );
      if (!mounted) return;
      // A slow keychain read must not overwrite anything the user changed.
      if (_userEdited) return;
      if (existing == null) {
        // Not signed in here: start from the address the account's name
        // gives, with the secrets left to type.
        final address = GitConfig.addressFromLabel(group.rows.first.label);
        if (address != null) {
          _repoUrl.text = address.repoUrl;
          _branch.text = address.branch;
          _userEdited = false;
        }
        return;
      }
      _repoUrl.text = existing.repoUrl;
      _username.text = existing.username;
      _token.text = existing.token;
      _branch.text = existing.branch;
      _pinnedCertSha256 = existing.pinnedCertSha256;
      _userEdited = false;
    } catch (_) {
      _showSnack(
        context.l10n.settings_gitConfig_error_secureStorage,
        isError: true,
      );
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: isError
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4),
      ),
    );
  }

  /// The localized message for [field]'s problem, if the current input has
  /// one.
  String? _fieldError(Set<GitConfigProblem> field) {
    final l10n = context.l10n;
    final problem = _build().problems().where(field.contains).firstOrNull;
    return switch (problem) {
      null => null,
      GitConfigProblem.repoUrl ||
      GitConfigProblem.repoQuery ||
      GitConfigProblem.repoPath => l10n.settings_gitConfig_validation_repoUrl,
      GitConfigProblem.credentialsInUrl =>
        l10n.settings_gitConfig_validation_credentialsInUrl,
      GitConfigProblem.username => l10n.settings_gitConfig_validation_username,
      GitConfigProblem.token => l10n.settings_gitConfig_validation_token,
      GitConfigProblem.tokenSpaces =>
        l10n.settings_gitConfig_validation_tokenSpaces,
      GitConfigProblem.branch => l10n.settings_gitConfig_validation_branch,
    };
  }

  /// Runs [op] on the current input; a certificate the platform does not
  /// trust is offered to the user once, and [op] retried with it pinned.
  Future<(GitConfig, GitConnectionReport)> _withTrust(
    Future<GitConnectionReport> Function(GitConfig config) op,
  ) async {
    var config = _build();
    try {
      return (config, await op(config));
    } on GitUntrustedCertificateException catch (e) {
      if (!mounted) rethrow;
      // No progress bar behind a question the diver has to answer.
      setState(() => _busy = false);
      final trusted = await showWebDavTrustDialog(
        context,
        WebDavUntrustedCertificateException(
          e.certificate,
          pinnedSha256: config.pinnedCertSha256,
        ),
      );
      if (!trusted) rethrow;
      if (mounted) setState(() => _busy = true);
      _pinnedCertSha256 = e.certificate.sha256;
      config = _build();
      return (config, await op(config));
    }
  }

  String _successText(GitConfig config, GitConnectionReport report) {
    final l10n = context.l10n;
    final main = report.branchExists
        ? l10n.settings_gitConfig_test_successExisting(config.branch)
        : l10n.settings_gitConfig_test_successNew(config.branch);
    return report.willBecomeDefault
        ? '$main ${l10n.settings_gitConfig_test_becomesDefault(config.branch)}'
        : main;
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final (config, report) = await _withTrust(
        ref.read(gitStorageProviderInstanceProvider).testConnection,
      );
      if (!mounted) return;
      _showSnack(_successText(config, report));
    } on GitException catch (e) {
      _showSnack(gitErrorText(l10n, e, branch: _build().branch), isError: true);
    } catch (e) {
      // Test connection reads nothing from the keychain.
      _showSnack('${l10n.common_error_tryAgain} ($e)', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmPublic() async {
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.public),
        title: Text(l10n.settings_gitConfig_public_title),
        content: Text(l10n.settings_gitConfig_public_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_action_cancel),
          ),
          // Only saves: encryption is turned on from the Cloud sync page this
          // page returns to, as the dialog text and the snack say.
          FilledButton(
            key: const Key('git-public-save'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.common_action_save),
          ),
        ],
      ),
    );
    return go == true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    // The app-level container outlives this page, so the writes below finish
    // even if the page is popped mid-save.
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    var savingToKeychain = false;
    try {
      final provider = container.read(gitStorageProviderInstanceProvider);
      final (config, report) = await _withTrust(provider.testConnection);
      final encrypted = container
          .read(syncPreferencesProvider)
          .syncEncryptionEnabled;
      // A public repository syncs only encrypted. Saving it anyway lets the
      // diver turn encryption on next: until then the provider refuses
      // every data upload.
      final mustEncrypt = report.isPublic && !encrypted;
      if (mustEncrypt) {
        if (!mounted) return;
        // No progress bar behind a question the diver has to answer.
        setState(() => _busy = false);
        if (!await _confirmPublic() || !mounted) return;
        setState(() => _busy = true);
      }
      savingToKeychain = true;
      final row = await saveGitAccount(container, config);
      savingToKeychain = false;
      if (!mounted) return;
      _showSnack(
        mustEncrypt
            ? l10n.settings_gitConfig_public_saved
            : l10n.settings_gitConfig_saved,
      );
      Navigator.of(context).pop(row);
    } on GitException catch (e) {
      _showSnack(gitErrorText(l10n, e, branch: _build().branch), isError: true);
    } catch (e) {
      _showSnack(
        savingToKeychain
            ? '${l10n.settings_gitConfig_error_secureStorage}: $e'
            : '${l10n.common_error_tryAgain} ($e)',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final address = _repoUrl.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l10n.settings_gitConfig_appBar_title
              : l10n.settings_accounts_signInTo(widget.existing!.label),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            TextFormField(
              key: const Key('git-repo-url'),
              controller: _repoUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.settings_gitConfig_field_repoUrl_label,
                hintText: l10n.settings_gitConfig_field_repoUrl_hint,
                helperText: l10n.settings_gitConfig_field_repoUrl_helper,
              ),
              validator: (_) => _fieldError(const {
                GitConfigProblem.repoUrl,
                GitConfigProblem.credentialsInUrl,
                GitConfigProblem.repoQuery,
                GitConfigProblem.repoPath,
              }),
            ),
            if (address.isNotEmpty) GitHostNote(hostKind: _build().hostKind),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('git-username'),
              controller: _username,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.settings_gitConfig_field_username_label,
              ),
              validator: (_) => _fieldError(const {GitConfigProblem.username}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('git-token'),
              controller: _token,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.settings_gitConfig_field_token_label,
              ),
              validator: (_) => _fieldError(const {
                GitConfigProblem.token,
                GitConfigProblem.tokenSpaces,
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('git-branch'),
              controller: _branch,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.settings_gitConfig_field_branch_label,
                helperText: l10n.settings_gitConfig_field_branch_helper,
                helperMaxLines: 4,
              ),
              validator: (_) => _fieldError(const {GitConfigProblem.branch}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('git-test'),
                    onPressed: _busy ? null : _testConnection,
                    child: Text(l10n.settings_gitConfig_action_testConnection),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('git-save'),
                    onPressed: _busy ? null : _save,
                    child: Text(l10n.common_action_save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Records [config] as a Git account: its roster row (one per repository
/// and branch) and the config, token included, under that row's own key.
/// Returns the row.
Future<ConnectedAccount> saveGitAccount(
  ProviderContainer container,
  GitConfig config,
) async {
  final row = await container
      .read(connectedAccountsRepositoryProvider)
      .ensure(
        kind: AccountKind.git,
        naturalKey: gitNaturalKey(config),
        label: config.displayLabel,
      );
  await container
      .read(accountCredentialsStoreProvider)
      .write(row.id, jsonEncode(config.toJson()));
  return row;
}

/// Pushes the Git account form on its own page and returns the row it
/// saved, or null when the diver backs out. [rootNavigator] as for
/// showOwnServerPage: the first-run wizard has no diver for a go_router
/// push to land on.
Future<ConnectedAccount?> showGitAccountPage(
  BuildContext context, {
  AccountGroup? existing,
  bool rootNavigator = false,
}) =>
    Navigator.of(context, rootNavigator: rootNavigator).push<ConnectedAccount>(
      MaterialPageRoute(builder: (_) => GitConfigPage(existing: existing)),
    );
