import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The paste-the-redirected-URL OAuth dialog: opens the Adobe IMS
/// authorize page in the system browser and exchanges the pasted URL (or
/// raw code). Pops `true` on success.
///
/// [openUri] is injectable for widget tests; production uses url_launcher.
class LightroomConnectDialog extends StatefulWidget {
  const LightroomConnectDialog({
    required this.authManager,
    required this.clientId,
    this.clientSecret,
    this.redirectUri,
    this.openUri,
    super.key,
  });

  final AdobeImsAuthManager authManager;
  final String clientId;
  final String? clientSecret;

  /// Per-credential redirect URI for BYO Native App credentials (which use an
  /// Adobe-generated custom scheme). Null falls back to the bundled web
  /// callback in [AdobeImsAuthManager.beginAuthorization].
  final String? redirectUri;
  final Future<bool> Function(Uri uri)? openUri;

  @override
  State<LightroomConnectDialog> createState() => _LightroomConnectDialogState();
}

class _LightroomConnectDialogState extends State<LightroomConnectDialog> {
  final _codeController = TextEditingController();
  Uri? _authorizeUri;
  String? _errorText;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    // beginAuthorization generates the PKCE verifier; the same URI (and
    // verifier) is reused by "Reopen browser" so the pasted code always
    // matches the pending verifier.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowser());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openBrowser() async {
    try {
      final uri = _authorizeUri ??= widget.authManager.beginAuthorization(
        clientId: widget.clientId,
        clientSecret: widget.clientSecret,
        redirectUri: widget.redirectUri,
      );
      final open =
          widget.openUri ??
          (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
      final opened = await open(uri);
      if (!mounted) return;
      // launchUrl reports failure by returning false, not only by throwing.
      // A successful (re)open clears any stale error.
      setState(
        () => _errorText = opened
            ? null
            : context.l10n.settings_cloudSync_dropbox_connect_browserFailed,
      );
    } on CloudStorageException catch (e) {
      // The dialog is barrier-dismissible; the open can outlive this State.
      if (!mounted) return;
      setState(() => _errorText = e.displayMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    }
  }

  Future<void> _connect() async {
    final l10n = context.l10n;
    final input = _codeController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorText = l10n.settings_lightroom_connect_emptyCode);
      return;
    }
    setState(() {
      _connecting = true;
      _errorText = null;
    });
    try {
      await widget.authManager.completeAuthorization(input);
      if (mounted) Navigator.of(context).pop(true);
    } on CloudStorageException catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorText = l10n.settings_lightroom_connect_failed(e.displayMessage);
      });
    } catch (e) {
      // The final store save can throw a raw PlatformException from the
      // keychain; without this catch the dialog wedges with _connecting
      // stuck true.
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorText = l10n.settings_lightroom_connect_failed(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_lightroom_connect_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_lightroom_connect_instructions),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            autofocus: true,
            enabled: !_connecting,
            decoration: InputDecoration(
              labelText: l10n.settings_lightroom_connect_codeLabel,
              errorText: _errorText,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _connect(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _connecting ? null : _openBrowser,
          child: Text(l10n.settings_lightroom_connect_reopenBrowser),
        ),
        TextButton(
          onPressed: _connecting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _connecting ? null : _connect,
          child: _connecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.settings_lightroom_connect_submit),
        ),
      ],
    );
  }
}
