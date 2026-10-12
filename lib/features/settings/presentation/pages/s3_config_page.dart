import 'package:flutter/material.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/s3_server_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Configuration form for the S3-compatible sync backend. Endpoint,
/// bucket, and credentials up front; region, key prefix, and addressing
/// style live in a collapsed Advanced section with auto-derived defaults,
/// and a live read+write Test Connection probe (which also adopts
/// server-detected regions) runs against the unsaved form values.
class S3ConfigPage extends ConsumerStatefulWidget {
  const S3ConfigPage({super.key});

  @override
  ConsumerState<S3ConfigPage> createState() => _S3ConfigPageState();
}

class _S3ConfigPageState extends ConsumerState<S3ConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _form = S3FormController();
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
          .read(s3StorageProviderInstanceProvider)
          .loadConfig();
      if (!mounted || existing == null) return;
      // A slow keychain read must not overwrite typing.
      if (_form.hasTyping) return;
      _form.load(existing);
      setState(() => _hasExistingConfig = true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        context.l10n.settings_s3Config_error_secureStorage,
        isError: true,
      );
    }
  }

  S3Config _buildConfig() => _form.build();

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        // Errors now carry the underlying cause (e.g. a TLS handshake
        // detail), which can span several lines; give the reader time.
        duration: isError
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    // The detected-region message is only known after the await, so the
    // l10n object itself is captured before the async gap (same pattern
    // as _remove).
    final l10n = context.l10n;
    setState(() => _busy = true);
    String? detectedRegion;
    try {
      await ref
          .read(s3StorageProviderInstanceProvider)
          .testConnection(
            _buildConfig(),
            onRegionCorrected: (region) => detectedRegion = region,
          );
      // The page may have been popped while the probe ran; the disposed
      // region controller must not be touched.
      if (!mounted) return;
      final detected = detectedRegion;
      if (detected != null) {
        _form.region.text = detected;
        _showSnack(l10n.settings_s3Config_test_regionDetected(detected));
      } else {
        _showSnack(l10n.settings_s3Config_test_success);
      }
    } on CloudStorageException catch (e) {
      _showSnack(e.displayMessage, isError: true);
    } catch (e) {
      _showSnack(
        '${l10n.settings_s3Config_error_secureStorage}: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final storageMessage = l10n.settings_s3Config_error_secureStorage;
    // Capture the app-level container before the first await. It outlives this
    // page, so the provider writes / global refresh / re-derivation below all
    // run (and never throw) even if the page is popped during an async gap --
    // `ref` throws once the ConsumerState is disposed. Global providers other
    // screens listen to (the sync settings page still mounted behind this
    // route) must refresh whether or not THIS page survives.
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      await container
          .read(s3StorageProviderInstanceProvider)
          .saveConfig(_buildConfig());
      container.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.s3;
      await container
          .read(syncInitializerProvider)
          .saveProvider(CloudProviderType.s3);
      // Refresh dependent state before the in-flight re-derivation below so a
      // mid-save pop can't leave those screens stale.
      container.read(syncStateProvider.notifier).refreshState();
      container.invalidate(s3ConfigProvider);
      // Re-derive the sync account so its per-account credential mirror
      // picks up this (possibly in-place) config edit; account-first
      // resolution reads that mirror. Invalidate + await because editing
      // while already on S3 doesn't re-fire the provider-type change.
      container.invalidate(selectedSyncAccountProvider);
      await container.read(selectedSyncAccountProvider.future);
      // Only UI work remains (snackbar + navigation); the page may have been
      // popped while the derivation was in flight, so gate that on mounted.
      if (!mounted) return;
      _showSnack(l10n.settings_s3Config_saved);
      // Root-safe in widget tests; pops the pushed route in the app.
      await Navigator.maybePop(context);
    } on CloudStorageException catch (e) {
      _showSnack(e.displayMessage, isError: true);
    } catch (e) {
      _showSnack('$storageMessage: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final storageMessage = l10n.settings_s3Config_error_secureStorage;
    // Removing the active sync provider also takes cloud backup's
    // destination away; surface that in the same confirmation.
    final warnBackup =
        ref.read(selectedCloudProviderTypeProvider) == CloudProviderType.s3 &&
        ref.read(backupSettingsProvider).cloudBackupEnabled;
    final removeBody = warnBackup
        ? '${l10n.settings_s3Config_remove_confirm_body}\n\n'
              '${l10n.settings_cloudSync_signOut_backupWarning}'
        : l10n.settings_s3Config_remove_confirm_body;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_s3Config_remove_confirm_title),
        content: Text(removeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            key: const Key('s3-remove-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settings_s3Config_remove_confirm_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(s3StorageProviderInstanceProvider).signOut();
      if (ref.read(selectedCloudProviderTypeProvider) == CloudProviderType.s3) {
        // Resets selection, persisted provider, and sync state in one place.
        await ref.read(syncStateProvider.notifier).signOut();
        await ref.read(backupSettingsProvider.notifier).disableCloudBackup();
      }
      ref.invalidate(s3ConfigProvider);
      if (!mounted) return;
      _showSnack(context.l10n.settings_s3Config_removed);
      await Navigator.maybePop(context);
    } catch (e) {
      _showSnack('$storageMessage: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_s3Config_appBar_title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            S3ServerFields(controller: _form),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('s3-test'),
                    onPressed: _busy ? null : _testConnection,
                    child: Text(l10n.settings_s3Config_action_testConnection),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('s3-save'),
                    onPressed: _busy ? null : _save,
                    child: Text(l10n.common_action_save),
                  ),
                ),
              ],
            ),
            if (_hasExistingConfig) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('s3-remove'),
                onPressed: _busy ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.settings_s3Config_action_remove),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
