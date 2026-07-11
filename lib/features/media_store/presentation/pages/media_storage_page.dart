import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_region.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Configuration page for the media store's S3 backend (design spec
/// section 14). Sibling of the sync backend's S3ConfigPage: same field
/// set and validation, its own keychain entry and default prefix, and a
/// connect flow that adopts or creates the bucket's store identity
/// marker. Managed providers (iCloud/Drive/Dropbox) arrive in Phase 4.
class MediaStoragePage extends ConsumerStatefulWidget {
  const MediaStoragePage({super.key});

  @override
  ConsumerState<MediaStoragePage> createState() => _MediaStoragePageState();
}

class _MediaStoragePageState extends ConsumerState<MediaStoragePage> {
  final _formKey = GlobalKey<FormState>();
  final _endpointController = TextEditingController();
  final _regionController = TextEditingController();
  final _bucketController = TextEditingController();
  final _prefixController = TextEditingController(text: 'submersion-media/');
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();

  bool _pathStyle = false;
  bool _pathStyleTouched = false;
  bool _secretVisible = false;
  bool _busy = false;
  bool _syncConfigAvailable = false;
  CloudProviderType _selectedProvider = CloudProviderType.s3;
  // Null until loaded; the switches render only once values are known.
  bool? _autoUpload;
  bool? _photosOnCellular;

  @override
  void initState() {
    super.initState();
    _endpointController.addListener(_onEndpointChanged);
    _regionController.addListener(_onRegionChanged);
    _loadExisting();
    _checkSyncConfig();
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    final policies = ref.read(mediaStorePoliciesProvider);
    final autoUpload = await policies.autoUpload();
    final photosOnCellular = await policies.photosOnCellular();
    if (!mounted) return;
    setState(() {
      _autoUpload = autoUpload;
      _photosOnCellular = photosOnCellular;
    });
  }

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
          .read(mediaStoreCredentialsStoreProvider)
          .load();
      if (!mounted || existing == null) return;
      if (_bucketController.text.isNotEmpty ||
          _accessKeyController.text.isNotEmpty ||
          _secretKeyController.text.isNotEmpty) {
        return;
      }
      setState(() {
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
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        context.l10n.settings_s3Config_error_secureStorage,
        isError: true,
      );
    }
  }

  Future<void> _checkSyncConfig() async {
    try {
      final syncConfig = await S3CredentialsStore().load();
      if (!mounted) return;
      setState(() => _syncConfigAvailable = syncConfig != null);
    } catch (_) {
      // No prefill offer when the sync config cannot be read.
    }
  }

  Future<void> _copyFromSync() async {
    final S3Config? syncConfig;
    try {
      syncConfig = await S3CredentialsStore().load();
    } catch (_) {
      // Same guard as _checkSyncConfig/_loadExisting: keychain access can
      // fail at any time and must not crash the page.
      if (!mounted) return;
      _showSnack(
        context.l10n.settings_s3Config_error_secureStorage,
        isError: true,
      );
      return;
    }
    if (!mounted || syncConfig == null) return;
    final config = syncConfig;
    setState(() {
      _endpointController.text = config.isAws
          ? 'https://s3.${config.region}.amazonaws.com'
          : config.endpoint;
      _regionController.text = config.region;
      _bucketController.text = config.bucket;
      // The media store keeps its own namespace even in a shared bucket.
      _prefixController.text = 'submersion-media/';
      _accessKeyController.text = config.accessKeyId;
      _secretKeyController.text = config.secretAccessKey;
      _pathStyle = config.pathStyle;
      _pathStyleTouched = true;
    });
  }

  void _onEndpointChanged() {
    final trimmed = _endpointController.text.trim();
    final host = Uri.tryParse(trimmed)?.host.toLowerCase() ?? '';
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
      await ref.read(mediaStoreServiceProvider).testConnection(_buildConfig());
      if (!mounted) return;
      _showSnack(l10n.settings_mediaStorage_test_success);
    } on MediaStoreException catch (e) {
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

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(mediaStoreServiceProvider).connectS3(_buildConfig());
      ref.invalidate(mediaStoreRuntimeProvider);
      if (!mounted) return;
      _showSnack(l10n.settings_mediaStorage_saved);
      await Navigator.maybePop(context);
    } on MediaStoreException catch (e) {
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

  Future<void> _backfill() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final count = await ref.read(mediaBackfillServiceProvider).enqueueAll();
      if (!mounted) return;
      _showSnack(l10n.settings_mediaStorage_backfill_enqueued(count));
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      unawaited(runtime?.worker?.drain());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _managedConnectPanel(AppLocalizations l10n) {
    final (hint, label, key, call) = switch (_selectedProvider) {
      CloudProviderType.dropbox => (
        l10n.settings_mediaStorage_connect_dropbox_hint,
        'Dropbox',
        const Key('media-dropbox-connect'),
        () => ref.read(mediaStoreServiceProvider).connectDropbox(),
      ),
      CloudProviderType.googledrive => (
        l10n.settings_mediaStorage_connect_gdrive_hint,
        'Google Drive',
        const Key('media-gdrive-connect'),
        () => ref.read(mediaStoreServiceProvider).connectGoogleDrive(),
      ),
      _ => (
        l10n.settings_mediaStorage_connect_icloud_hint,
        'iCloud',
        const Key('media-icloud-connect'),
        () => ref.read(mediaStoreServiceProvider).connectICloud(),
      ),
    };
    return [
      Text(hint),
      const SizedBox(height: 16),
      FilledButton(
        key: key,
        onPressed: _busy ? null : () => _connectManagedFlow(call),
        child: Text(l10n.settings_mediaStorage_connect_action(label)),
      ),
    ];
  }

  Future<void> _connectManagedFlow(
    Future<MediaStoreConnectResult> Function() call,
  ) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await call();
      ref.invalidate(mediaStoreRuntimeProvider);
      if (!mounted) return;
      _showSnack(l10n.settings_mediaStorage_saved);
      await Navigator.maybePop(context);
    } on MediaStoreException catch (e) {
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_mediaStorage_disconnect_confirm_title),
        content: Text(l10n.settings_mediaStorage_disconnect_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            key: const Key('media-s3-disconnect-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settings_mediaStorage_action_disconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(mediaStoreServiceProvider).disconnect();
      ref.invalidate(mediaStoreRuntimeProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusHint = ref.watch(mediaStoreStatusHintProvider).value;
    final connected = statusHint != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_mediaStorage_entry_title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Card(
              key: const Key('media-s3-status'),
              child: ListTile(
                leading: Icon(
                  connected ? Icons.cloud_done : Icons.cloud_off,
                  color: connected
                      ? Colors.green
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(
                  connected
                      ? l10n.settings_mediaStorage_status_connected(statusHint)
                      : l10n.settings_mediaStorage_status_notConfigured,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!connected) ...[
              Text(
                l10n.settings_mediaStorage_provider_label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<CloudProviderType>(
                key: const Key('media-provider-chooser'),
                segments: [
                  const ButtonSegment(
                    value: CloudProviderType.s3,
                    label: Text('S3'),
                  ),
                  const ButtonSegment(
                    value: CloudProviderType.dropbox,
                    label: Text('Dropbox'),
                  ),
                  const ButtonSegment(
                    value: CloudProviderType.googledrive,
                    label: Text('Google Drive'),
                  ),
                  if (ref.watch(isApplePlatformProvider))
                    const ButtonSegment(
                      value: CloudProviderType.icloud,
                      label: Text('iCloud'),
                    ),
                ],
                selected: {_selectedProvider},
                onSelectionChanged: (selection) =>
                    setState(() => _selectedProvider = selection.single),
              ),
              const SizedBox(height: 16),
              if (_selectedProvider != CloudProviderType.s3)
                ..._managedConnectPanel(l10n),
            ],
            if (!connected && _selectedProvider == CloudProviderType.s3) ...[
              if (_isInsecureEndpoint)
                Card(
                  key: const Key('media-s3-http-warning'),
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
              if (_syncConfigAvailable)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('media-s3-copy-from-sync'),
                    onPressed: _busy ? null : _copyFromSync,
                    icon: const Icon(Icons.copy_all),
                    label: Text(l10n.settings_mediaStorage_action_copyFromSync),
                  ),
                ),
              TextFormField(
                key: const Key('media-s3-endpoint'),
                controller: _endpointController,
                decoration: InputDecoration(
                  labelText: l10n.settings_s3Config_field_endpoint_label,
                  hintText: l10n.settings_s3Config_field_endpoint_helper,
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
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
                key: const Key('media-s3-bucket'),
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
                key: const Key('media-s3-access-key'),
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
                key: const Key('media-s3-secret-key'),
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
                key: const Key('media-s3-advanced'),
                title: Text(l10n.settings_s3Config_advanced_title),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12, bottom: 8),
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  TextFormField(
                    key: const Key('media-s3-region'),
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
                    key: const Key('media-s3-prefix'),
                    controller: _prefixController,
                    decoration: InputDecoration(
                      labelText: l10n.settings_s3Config_field_prefix_label,
                    ),
                    autocorrect: false,
                  ),
                  SwitchListTile(
                    key: const Key('media-s3-path-style'),
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
                      key: const Key('media-s3-test'),
                      onPressed: _busy ? null : _testConnection,
                      child: Text(l10n.settings_s3Config_action_testConnection),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('media-s3-connect'),
                      onPressed: _busy ? null : _connect,
                      child: Text(l10n.common_action_save),
                    ),
                  ),
                ],
              ),
            ],
            if (connected) ...[
              const SizedBox(height: 8),
              if (_autoUpload != null)
                SwitchListTile(
                  key: const Key('media-s3-policy-auto-upload'),
                  title: Text(l10n.settings_mediaStorage_policy_autoUpload),
                  value: _autoUpload!,
                  onChanged: (value) async {
                    setState(() => _autoUpload = value);
                    await ref
                        .read(mediaStorePoliciesProvider)
                        .setAutoUpload(value);
                  },
                ),
              if (_photosOnCellular != null)
                SwitchListTile(
                  key: const Key('media-s3-policy-photos-cellular'),
                  title: Text(
                    l10n.settings_mediaStorage_policy_photosOnCellular,
                  ),
                  value: _photosOnCellular!,
                  onChanged: (value) async {
                    setState(() => _photosOnCellular = value);
                    await ref
                        .read(mediaStorePoliciesProvider)
                        .setPhotosOnCellular(value);
                  },
                ),
              FilledButton.tonal(
                key: const Key('media-s3-backfill'),
                onPressed: _busy ? null : _backfill,
                child: Text(l10n.settings_mediaStorage_backfill_action),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final active =
                      ref.watch(mediaTransferActiveCountProvider).value ?? 0;
                  if (active == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Expanded(child: LinearProgressIndicator()),
                        const SizedBox(width: 12),
                        Text('$active'),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                key: const Key('media-s3-transfers'),
                leading: const Icon(Icons.swap_vert),
                title: Text(l10n.settings_mediaStorage_transfers_entry),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/media-storage/transfers'),
              ),
              TextButton(
                key: const Key('media-s3-disconnect'),
                onPressed: _busy ? null : _disconnect,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.settings_mediaStorage_action_disconnect),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
