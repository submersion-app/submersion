import 'package:flutter/material.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_region.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
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
  final _endpointController = TextEditingController();
  final _regionController = TextEditingController();
  final _bucketController = TextEditingController();
  final _prefixController = TextEditingController(text: 'submersion-sync/');
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();

  bool _pathStyle = false;
  // Once the user flips the switch manually it stops auto-tracking the
  // endpoint field.
  bool _pathStyleTouched = false;
  bool _secretVisible = false;
  bool _busy = false;
  bool _hasExistingConfig = false;

  @override
  void initState() {
    super.initState();
    _endpointController.addListener(_onEndpointChanged);
    _regionController.addListener(_onRegionChanged);
    _loadExisting();
  }

  // The auto-detected helper hides while the field holds a manual value.
  void _onRegionChanged() => setState(() {});

  @override
  void dispose() {
    _endpointController.dispose();
    _regionController.dispose();
    _bucketController.dispose();
    _prefixController.dispose();
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final existing = await ref
          .read(s3StorageProviderInstanceProvider)
          .loadConfig();
      if (!mounted || existing == null) return;
      // A slow keychain read must not overwrite typing.
      if (_bucketController.text.isNotEmpty ||
          _accessKeyController.text.isNotEmpty ||
          _secretKeyController.text.isNotEmpty) {
        return;
      }
      setState(() {
        // Legacy configs stored AWS as a blank endpoint; surface the real
        // URL so the (now required) field re-saves without retyping.
        _endpointController.text = existing.isAws
            ? 'https://s3.${existing.region}.amazonaws.com'
            : existing.endpoint;
        _regionController.text = existing.region;
        _bucketController.text = existing.bucket;
        _prefixController.text = existing.prefix;
        _accessKeyController.text = existing.accessKeyId;
        _secretKeyController.text = existing.secretAccessKey;
        _pathStyle = existing.pathStyle;
        _pathStyleTouched = true;
        // A stored choice (even an auto-derived one) must not silently flip.
        _hasExistingConfig = true;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        context.l10n.settings_s3Config_error_secureStorage,
        isError: true,
      );
    }
  }

  void _onEndpointChanged() {
    final trimmed = _endpointController.text.trim();
    final host = Uri.tryParse(trimmed)?.host.toLowerCase() ?? '';
    // The auto-flip is for MinIO, NAS, and other self-hosted servers. AWS
    // prefers virtual-hosted addressing, and the global endpoint only
    // reaches cross-region buckets in that mode.
    final wantsPathStyle =
        trimmed.isNotEmpty &&
        host != 'amazonaws.com' &&
        !host.endsWith('.amazonaws.com');
    setState(() {
      if (!_pathStyleTouched) _pathStyle = wantsPathStyle;
    });
  }

  bool get _isInsecureEndpoint =>
      _endpointController.text.trim().toLowerCase().startsWith('http://');

  S3Config _buildConfig() {
    final manualRegion = _regionController.text.trim();
    return S3Config(
      endpoint: _endpointController.text,
      region: manualRegion.isEmpty
          ? deriveRegion(_endpointController.text)
          : manualRegion,
      bucket: _bucketController.text,
      prefix: _prefixController.text,
      pathStyle: _pathStyle,
      accessKeyId: _accessKeyController.text,
      secretAccessKey: _secretKeyController.text,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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
        _regionController.text = detected;
        _showSnack(l10n.settings_s3Config_test_regionDetected(detected));
      } else {
        _showSnack(l10n.settings_s3Config_test_success);
      }
    } on CloudStorageException catch (e) {
      _showSnack(e.message, isError: true);
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
    final storageMessage = context.l10n.settings_s3Config_error_secureStorage;
    setState(() => _busy = true);
    try {
      await ref
          .read(s3StorageProviderInstanceProvider)
          .saveConfig(_buildConfig());
      ref.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.s3;
      await ref
          .read(syncInitializerProvider)
          .saveProvider(CloudProviderType.s3);
      ref.read(syncStateProvider.notifier).refreshState();
      ref.invalidate(s3ConfigProvider);
      if (!mounted) return;
      _showSnack(context.l10n.settings_s3Config_saved);
      // Root-safe in widget tests; pops the pushed route in the app.
      await Navigator.maybePop(context);
    } on CloudStorageException catch (e) {
      _showSnack(e.message, isError: true);
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
            if (_isInsecureEndpoint)
              Card(
                key: const Key('s3-http-warning'),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_open,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.settings_s3Config_warning_http),
                      ),
                    ],
                  ),
                ),
              ),
            TextFormField(
              key: const Key('s3-endpoint'),
              controller: _endpointController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_endpoint_label,
                // In-field hint: visible only while blank, so it cannot be
                // misread as describing the Bucket field below.
                hintText: l10n.settings_s3Config_field_endpoint_helper,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              // Sub-paths break SigV4 key addressing; host-only endpoints are accepted.
              validator: (value) {
                final trimmed = (value ?? '').trim();
                if (trimmed.isEmpty) {
                  return l10n.settings_s3Config_validation_required;
                }
                final uri = Uri.tryParse(trimmed);
                final valid =
                    uri != null &&
                    (uri.scheme == 'http' || uri.scheme == 'https') &&
                    uri.host.isNotEmpty;
                if (!valid) {
                  return l10n.settings_s3Config_validation_endpointInvalid;
                }
                if (uri.path.isNotEmpty && uri.path != '/') {
                  return l10n.settings_s3Config_validation_endpointPath;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('s3-bucket'),
              controller: _bucketController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_bucket_label,
              ),
              autocorrect: false,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.settings_s3Config_validation_required
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('s3-access-key'),
              controller: _accessKeyController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_accessKeyId_label,
              ),
              autocorrect: false,
              enableSuggestions: false,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.settings_s3Config_validation_required
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('s3-secret-key'),
              controller: _secretKeyController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_secretAccessKey_label,
                suffixIcon: IconButton(
                  icon: Icon(
                    _secretVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _secretVisible = !_secretVisible),
                ),
              ),
              obscureText: !_secretVisible,
              autocorrect: false,
              enableSuggestions: false,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.settings_s3Config_validation_required
                  : null,
            ),
            ExpansionTile(
              key: const Key('s3-advanced'),
              title: Text(l10n.settings_s3Config_advanced_title),
              tilePadding: EdgeInsets.zero,
              // Top inset keeps the first child's floating label clear of
              // the header row.
              childrenPadding: const EdgeInsets.only(top: 12, bottom: 8),
              // Suppress the M3 outline the tile draws when expanded.
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                TextFormField(
                  key: const Key('s3-region'),
                  controller: _regionController,
                  decoration: InputDecoration(
                    labelText: l10n.settings_s3Config_field_region_label,
                    helperText: _regionController.text.trim().isEmpty
                        ? l10n.settings_s3Config_field_region_helperAuto(
                            deriveRegion(_endpointController.text),
                          )
                        : null,
                  ),
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('s3-prefix'),
                  controller: _prefixController,
                  decoration: InputDecoration(
                    labelText: l10n.settings_s3Config_field_prefix_label,
                  ),
                  autocorrect: false,
                ),
                SwitchListTile(
                  key: const Key('s3-path-style'),
                  title: Text(l10n.settings_s3Config_field_pathStyle_label),
                  subtitle: Text(
                    l10n.settings_s3Config_field_pathStyle_subtitle,
                  ),
                  value: _pathStyle,
                  onChanged: (value) => setState(() {
                    _pathStyle = value;
                    _pathStyleTouched = true;
                  }),
                ),
              ],
            ),
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
