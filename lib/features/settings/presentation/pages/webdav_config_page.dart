import 'package:flutter/material.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Configuration for the WebDAV sync backend. Test connection and Save both
/// run the live probe (Save needs it to resolve the Nextcloud user id) and
/// both offer to trust a self-signed certificate.
class WebDavConfigPage extends ConsumerStatefulWidget {
  const WebDavConfigPage({super.key});

  @override
  ConsumerState<WebDavConfigPage> createState() => _WebDavConfigPageState();
}

class _WebDavConfigPageState extends ConsumerState<WebDavConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _form = WebDavFormController();
  bool _busy = false;
  bool _hasExistingConfig = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final existing = await ref
          .read(webdavStorageProviderInstanceProvider)
          .loadConfig();
      if (!mounted || existing == null) return;
      // Remove must be offered whenever a config exists, typing or not.
      setState(() => _hasExistingConfig = true);
      // A slow keychain read must not overwrite anything the user changed.
      if (_form.userEdited) return;
      _form.load(existing);
    } catch (_) {
      _showSnack(
        context.l10n.settings_webdavConfig_error_secureStorage,
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

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final resolved = await runWithCertificateTrust(
        context,
        _form,
        ref.read(webdavStorageProviderInstanceProvider).testConnection,
      );
      _form.nextcloudUserId = resolved.nextcloudUserId;
      _showSnack(l10n.settings_webdavConfig_test_success);
    } on WebDavException catch (e) {
      _showSnack(webDavErrorText(l10n, e), isError: true);
    } catch (e) {
      _showSnack(
        '${l10n.settings_webdavConfig_error_secureStorage}: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    // The app-level container outlives this page, so the writes below finish
    // even if the page is popped mid-save (the S3 page does the same).
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      final provider = container.read(webdavStorageProviderInstanceProvider);
      final resolved = await runWithCertificateTrust(
        context,
        _form,
        provider.testConnection,
      );
      await provider.saveConfig(resolved);
      container.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.webdav;
      await container
          .read(syncInitializerProvider)
          .saveProvider(CloudProviderType.webdav);
      container.read(syncStateProvider.notifier).refreshState();
      container.invalidate(webdavConfigProvider);
      container.invalidate(selectedSyncAccountProvider);
      await container.read(selectedSyncAccountProvider.future);
      if (!mounted) return;
      _showSnack(l10n.settings_webdavConfig_saved);
      await Navigator.maybePop(context);
    } on WebDavException catch (e) {
      _showSnack(webDavErrorText(l10n, e), isError: true);
    } catch (e) {
      _showSnack(
        '${l10n.settings_webdavConfig_error_secureStorage}: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final warnBackup =
        ref.read(selectedCloudProviderTypeProvider) ==
            CloudProviderType.webdav &&
        ref.read(backupSettingsProvider).cloudBackupEnabled;
    final body = warnBackup
        ? '${l10n.settings_webdavConfig_remove_confirm_body}\n\n${l10n.settings_cloudSync_signOut_backupWarning}'
        : l10n.settings_webdavConfig_remove_confirm_body;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_webdavConfig_remove_confirm_title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            key: const Key('webdav-remove-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settings_webdavConfig_remove_confirm_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // As in _save: the app-level container outlives this page, so leaving
    // mid-remove cannot strand the password copy or the backup setting.
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      final provider = container.read(webdavStorageProviderInstanceProvider);
      final existing = await provider.loadConfig();
      final selectedAccount = container.read(selectedSyncAccountProvider).value;
      await provider.signOut();
      // Saving also copied the config, password included, under the sync
      // account's own key; the confirmation promises it leaves this device.
      // A media account on another folder has its own key and stays.
      final accountCredentials = container.read(
        accountCredentialsStoreProvider,
      );
      if (existing != null) {
        await accountCredentials.delete(
          accountIdFor(
            kind: AccountKind.webdav,
            naturalKey: webdavNaturalKey(existing),
          ),
        );
      }
      if (selectedAccount != null &&
          selectedAccount.kind == AccountKind.webdav) {
        await accountCredentials.delete(selectedAccount.id);
      }
      if (container.read(selectedCloudProviderTypeProvider) ==
          CloudProviderType.webdav) {
        await container.read(syncStateProvider.notifier).signOut();
        await container
            .read(backupSettingsProvider.notifier)
            .disableCloudBackup();
      }
      container.invalidate(webdavConfigProvider);
      if (!mounted) return;
      _showSnack(context.l10n.settings_webdavConfig_removed);
      await Navigator.maybePop(context);
    } catch (e) {
      _showSnack(
        '${l10n.settings_webdavConfig_error_secureStorage}: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_webdavConfig_appBar_title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            WebDavServerFields(controller: _form),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('webdav-test'),
                    onPressed: _busy ? null : _testConnection,
                    child: Text(
                      l10n.settings_webdavConfig_action_testConnection,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('webdav-save'),
                    onPressed: _busy ? null : _save,
                    child: Text(l10n.common_action_save),
                  ),
                ),
              ],
            ),
            if (_hasExistingConfig) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('webdav-remove'),
                onPressed: _busy ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.settings_webdavConfig_action_remove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
