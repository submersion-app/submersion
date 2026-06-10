import 'package:flutter/material.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Configuration form for the S3-compatible sync backend: endpoint, region,
/// bucket, key prefix, credentials, and addressing style, with a live
/// read+write Test Connection probe against the unsaved form values.
class S3ConfigPage extends ConsumerStatefulWidget {
  const S3ConfigPage({super.key});

  @override
  ConsumerState<S3ConfigPage> createState() => _S3ConfigPageState();
}

class _S3ConfigPageState extends ConsumerState<S3ConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _endpointController = TextEditingController();
  final _regionController = TextEditingController(text: 'us-east-1');
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
    _loadExisting();
  }

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
    final existing = await ref
        .read(s3StorageProviderInstanceProvider)
        .loadConfig();
    if (!mounted || existing == null) return;
    setState(() {
      _endpointController.text = existing.endpoint;
      _regionController.text = existing.region;
      _bucketController.text = existing.bucket;
      _prefixController.text = existing.prefix;
      _accessKeyController.text = existing.accessKeyId;
      _secretKeyController.text = existing.secretAccessKey;
      _pathStyle = existing.pathStyle;
      _pathStyleTouched = true;
      _hasExistingConfig = true;
    });
  }

  void _onEndpointChanged() {
    final isCustom = _endpointController.text.trim().isNotEmpty;
    setState(() {
      if (!_pathStyleTouched) _pathStyle = isCustom;
    });
  }

  // Amendment 1: case-insensitive http warning
  bool get _isInsecureEndpoint =>
      _endpointController.text.trim().toLowerCase().startsWith('http://');

  S3Config _buildConfig() {
    final region = _regionController.text.trim();
    return S3Config(
      endpoint: _endpointController.text,
      region: region.isEmpty ? 'us-east-1' : region,
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
    final successMessage = context.l10n.settings_s3Config_test_success;
    setState(() => _busy = true);
    try {
      await ref
          .read(s3StorageProviderInstanceProvider)
          .testConnection(_buildConfig());
      _showSnack(successMessage);
    } on CloudStorageException catch (e) {
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
      ref.invalidate(s3ConfigProvider);
      if (!mounted) return;
      _showSnack(context.l10n.settings_s3Config_saved);
      // Root-safe in widget tests; pops the pushed route in the app.
      await Navigator.maybePop(context);
    } on CloudStorageException catch (e) {
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_s3Config_remove_confirm_title),
        content: Text(l10n.settings_s3Config_remove_confirm_body),
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
        ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
        await ref.read(syncInitializerProvider).saveProvider(null);
      }
      ref.invalidate(s3ConfigProvider);
      if (!mounted) return;
      _showSnack(context.l10n.settings_s3Config_removed);
      await Navigator.maybePop(context);
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
                helperText: l10n.settings_s3Config_field_endpoint_helper,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              // Amendment 2b: endpoint sub-path rejection
              validator: (value) {
                final trimmed = (value ?? '').trim();
                if (trimmed.isEmpty) return null;
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
              key: const Key('s3-region'),
              controller: _regionController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_region_label,
              ),
              autocorrect: false,
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
              key: const Key('s3-prefix'),
              controller: _prefixController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_prefix_label,
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('s3-access-key'),
              controller: _accessKeyController,
              decoration: InputDecoration(
                labelText: l10n.settings_s3Config_field_accessKeyId_label,
              ),
              autocorrect: false,
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
              validator: (value) => (value ?? '').isEmpty
                  ? l10n.settings_s3Config_validation_required
                  : null,
            ),
            SwitchListTile(
              key: const Key('s3-path-style'),
              title: Text(l10n.settings_s3Config_field_pathStyle_label),
              subtitle: Text(l10n.settings_s3Config_field_pathStyle_subtitle),
              value: _pathStyle,
              onChanged: (value) => setState(() {
                _pathStyle = value;
                _pathStyleTouched = true;
              }),
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
