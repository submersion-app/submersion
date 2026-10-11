import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/presentation/pages/media_storage_page.dart'
    show mediaStoreErrorMessage;
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_error_text.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_server_fields.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Media Storage page's WebDAV form: the same server fields as the sync
/// settings, its own folder, and a shortcut that copies the sync server.
class WebDavMediaForm extends ConsumerStatefulWidget {
  const WebDavMediaForm({super.key});

  @override
  ConsumerState<WebDavMediaForm> createState() => _WebDavMediaFormState();
}

class _WebDavMediaFormState extends ConsumerState<WebDavMediaForm> {
  final _formKey = GlobalKey<FormState>();
  final _form = WebDavFormController(defaultFolder: kDefaultWebDavMediaFolder);
  bool _busy = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
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

  String _errorText(AppLocalizations l10n, MediaStoreException e) {
    final cause = e.cause;
    return cause is WebDavException
        ? webDavErrorText(l10n, cause)
        : mediaStoreErrorMessage(l10n, e);
  }

  Future<void> _run(Future<void> Function() body) async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await body();
    } on MediaStoreException catch (e) {
      _snack(_errorText(l10n, e), isError: true);
    } catch (e) {
      _snack(
        '${l10n.settings_webdavConfig_error_secureStorage}: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() => _run(() async {
    final service = ref.read(mediaStoreServiceProvider);
    final l10n = context.l10n;
    final resolved = await runWithCertificateTrust(
      context,
      _form,
      service.testWebDav,
    );
    _form.nextcloudUserId = resolved.nextcloudUserId;
    _snack(l10n.settings_mediaStorage_test_success);
  });

  Future<void> _connect() => _run(() async {
    final service = ref.read(mediaStoreServiceProvider);
    final l10n = context.l10n;
    await runWithCertificateTrust(context, _form, service.connectWebDav);
    invalidateMediaStoreAttachment(ref);
    if (!mounted) return;
    _snack(l10n.settings_mediaStorage_saved);
    await Navigator.maybePop(context);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final syncConfig = ref.watch(webdavConfigProvider).valueOrNull;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (syncConfig != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('webdav-media-use-sync'),
                icon: const Icon(Icons.copy_outlined),
                label: Text(l10n.settings_mediaStorage_webdav_useSyncServer),
                onPressed: _busy
                    ? null
                    : () => _form.copyServerFrom(
                        syncConfig,
                        keepFolder: _form.folder.text.trim().isEmpty
                            ? kDefaultWebDavMediaFolder
                            : _form.folder.text,
                      ),
              ),
            ),
          WebDavServerFields(controller: _form, keyPrefix: 'webdav-media'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('webdav-media-test'),
                  onPressed: _busy ? null : _test,
                  child: Text(l10n.settings_webdavConfig_action_testConnection),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('webdav-media-connect'),
                  onPressed: _busy ? null : _connect,
                  child: Text(l10n.common_action_save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
