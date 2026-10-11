import 'package:flutter/material.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/settings/presentation/widgets/webdav_trust_certificate_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Form state shared by the sync settings page and the media form.
class WebDavFormController extends ChangeNotifier {
  WebDavFormController({String defaultFolder = kDefaultWebDavSyncFolder})
    : folder = TextEditingController(text: defaultFolder) {
    for (final c in [serverUrl, username, password, folder]) {
      c
        ..addListener(notifyListeners)
        ..addListener(_markEdited);
    }
    // The resolved Nextcloud id belongs to one login on one server; a new
    // one must be resolved again, never inherited.
    serverUrl.addListener(_dropResolvedUserId);
    username.addListener(_dropResolvedUserId);
  }

  bool _loading = false;

  /// True once the user changed a field or the server type, so a late load
  /// of the saved config must not replace their input.
  bool get userEdited => _userEdited;
  bool _userEdited = false;

  void _markEdited() {
    if (!_loading) _userEdited = true;
  }

  void _dropResolvedUserId() {
    if (!_loading) nextcloudUserId = null;
  }

  final serverUrl = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final TextEditingController folder;

  WebDavPreset preset = WebDavPreset.nextcloud;
  String? pinnedCertSha256;
  String? nextcloudUserId;
  bool passwordVisible = false;

  void setPreset(WebDavPreset value) {
    preset = value;
    nextcloudUserId = null;
    _userEdited = true;
    notifyListeners();
  }

  void togglePasswordVisible() {
    passwordVisible = !passwordVisible;
    notifyListeners();
  }

  void trust(String sha256) {
    pinnedCertSha256 = sha256;
    notifyListeners();
  }

  void forgetPin() {
    pinnedCertSha256 = null;
    notifyListeners();
  }

  void load(WebDavConfig config) {
    _loading = true;
    preset = config.preset;
    serverUrl.text = config.serverUrl;
    username.text = config.username;
    password.text = config.password;
    folder.text = config.folder;
    _loading = false;
    pinnedCertSha256 = config.pinnedCertSha256;
    nextcloudUserId = config.nextcloudUserId;
    notifyListeners();
  }

  /// Server, login and pin from [source]; the folder stays [keepFolder] so
  /// media never lands in the sync folder.
  void copyServerFrom(WebDavConfig source, {required String keepFolder}) {
    load(source.copyWith(folder: keepFolder));
    _userEdited = true;
  }

  WebDavConfig build() => WebDavConfig(
    preset: preset,
    serverUrl: preset.needsServerUrl ? serverUrl.text : '',
    username: username.text,
    password: password.text,
    folder: folder.text,
    nextcloudUserId: nextcloudUserId,
    pinnedCertSha256: pinnedCertSha256,
  );

  /// The resolved DAV root for display, or null while the URL is unusable.
  String? get davRootPreview {
    if (preset.needsServerUrl &&
        Uri.tryParse(serverUrl.text.trim())?.host.isEmpty != false) {
      return null;
    }
    return build().davRoot.toString();
  }

  bool get isInsecure =>
      preset.needsServerUrl &&
      serverUrl.text.trim().toLowerCase().startsWith('http://');

  @override
  void dispose() {
    for (final c in [serverUrl, username, password, folder]) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Runs [op] with the form's config; on an untrusted certificate asks the
/// user, and when they trust it pins it and runs [op] once more.
Future<T> runWithCertificateTrust<T>(
  BuildContext context,
  WebDavFormController form,
  Future<T> Function(WebDavConfig config) op,
) async {
  try {
    return await op(form.build());
  } catch (e) {
    final untrusted = switch (e) {
      WebDavUntrustedCertificateException() => e,
      MediaStoreException(cause: final WebDavUntrustedCertificateException c) =>
        c,
      _ => null,
    };
    if (untrusted == null || !context.mounted) rethrow;
    final trusted = await showWebDavTrustDialog(context, untrusted);
    if (!trusted) rethrow;
    form.trust(untrusted.certificate.sha256);
    return op(form.build());
  }
}

String presetLabel(AppLocalizations l10n, WebDavPreset preset) =>
    switch (preset) {
      WebDavPreset.nextcloud => l10n.settings_webdavConfig_preset_nextcloud,
      WebDavPreset.owncloud => l10n.settings_webdavConfig_preset_owncloud,
      WebDavPreset.synology => l10n.settings_webdavConfig_preset_synology,
      WebDavPreset.koofr => l10n.settings_webdavConfig_preset_koofr,
      WebDavPreset.pcloudUs => l10n.settings_webdavConfig_preset_pcloudUs,
      WebDavPreset.pcloudEu => l10n.settings_webdavConfig_preset_pcloudEu,
      WebDavPreset.fastmail => l10n.settings_webdavConfig_preset_fastmail,
      WebDavPreset.yandex => l10n.settings_webdavConfig_preset_yandex,
      WebDavPreset.other => l10n.settings_webdavConfig_preset_other,
    };

/// Server type, address, login, folder, DAV root preview, http warning and
/// trusted-certificate row. Lives inside the caller's [Form].
class WebDavServerFields extends StatelessWidget {
  const WebDavServerFields({
    super.key,
    required this.controller,
    this.keyPrefix = 'webdav',
  });

  final WebDavFormController controller;
  final String keyPrefix;

  Key _k(String name) => Key('$keyPrefix-$name');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final preset = controller.preset;
        final root = controller.davRootPreview;
        final pin = controller.pinnedCertSha256;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.isInsecure)
              Card(
                key: _k('http-warning'),
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_open,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.settings_webdavConfig_warning_http),
                      ),
                    ],
                  ),
                ),
              ),
            DropdownButtonFormField<WebDavPreset>(
              key: _k('preset'),
              initialValue: preset,
              decoration: InputDecoration(
                labelText: l10n.settings_webdavConfig_field_preset_label,
              ),
              items: [
                for (final p in WebDavPreset.values)
                  DropdownMenuItem(value: p, child: Text(presetLabel(l10n, p))),
              ],
              onChanged: (value) {
                if (value != null) controller.setPreset(value);
              },
            ),
            if (preset.needsServerUrl) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: _k('server-url'),
                controller: controller.serverUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.settings_webdavConfig_field_serverUrl_label,
                  hintText: switch (preset) {
                    WebDavPreset.synology =>
                      l10n.settings_webdavConfig_field_serverUrl_hintSynology,
                    WebDavPreset.other =>
                      l10n.settings_webdavConfig_field_serverUrl_hintDav,
                    _ => l10n.settings_webdavConfig_field_serverUrl_hintHost,
                  },
                  helperText: preset == WebDavPreset.synology
                      ? l10n.settings_webdavConfig_synology_helper
                      : null,
                  helperMaxLines: 3,
                ),
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) {
                    return l10n.settings_webdavConfig_validation_required;
                  }
                  final uri = Uri.tryParse(trimmed);
                  final ok =
                      uri != null &&
                      (uri.scheme == 'http' || uri.scheme == 'https') &&
                      uri.host.isNotEmpty;
                  if (!ok) return l10n.settings_webdavConfig_validation_url;
                  if (uri.hasQuery || uri.hasFragment) {
                    return l10n.settings_webdavConfig_validation_urlQuery;
                  }
                  return uri.userInfo.isEmpty
                      ? null
                      : l10n.settings_webdavConfig_validation_urlCredentials;
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: _k('username'),
              controller: controller.username,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.settings_webdavConfig_field_username_label,
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? l10n.settings_webdavConfig_validation_required
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: _k('password'),
              controller: controller.password,
              obscureText: !controller.passwordVisible,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.settings_webdavConfig_field_password_label,
                helperText: preset.recommendsAppPassword
                    ? l10n.settings_webdavConfig_field_password_appPasswordHelper
                    : null,
                suffixIcon: IconButton(
                  icon: Icon(
                    controller.passwordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: controller.togglePasswordVisible,
                ),
              ),
              validator: (v) => (v ?? '').isEmpty
                  ? l10n.settings_webdavConfig_validation_required
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: _k('folder'),
              controller: controller.folder,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.settings_webdavConfig_field_folder_label,
                helperText: l10n.settings_webdavConfig_field_folder_helper,
              ),
              validator: (v) {
                final segments = (v ?? '')
                    .split('/')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                if (segments.isEmpty) {
                  return l10n.settings_webdavConfig_validation_required;
                }
                if (segments.any((s) => s == '.' || s == '..')) {
                  return l10n.settings_webdavConfig_validation_folder;
                }
                return null;
              },
            ),
            if (root != null)
              ListTile(
                key: _k('dav-root'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.settings_webdavConfig_davRoot_label,
                  style: theme.textTheme.labelMedium,
                ),
                subtitle: SelectableText(root),
              ),
            if (pin != null)
              ListTile(
                key: _k('pin-row'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(
                  l10n.settings_webdavConfig_trustedCertificate(
                    formatFingerprint(pin),
                  ),
                ),
                trailing: IconButton(
                  key: _k('forget-pin'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.settings_webdavConfig_action_forgetCertificate,
                  onPressed: controller.forgetPin,
                ),
              ),
          ],
        );
      },
    );
  }
}
