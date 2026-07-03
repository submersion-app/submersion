import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The copy-paste OAuth dialog: opens the Dropbox authorize page in the
/// system browser and exchanges the pasted code. Pops `true` on success.
///
/// [openUri] is injectable for widget tests; production uses url_launcher.
class DropboxConnectDialog extends StatefulWidget {
  const DropboxConnectDialog({required this.provider, this.openUri, super.key});

  final DropboxStorageProvider provider;
  final Future<bool> Function(Uri uri)? openUri;

  @override
  State<DropboxConnectDialog> createState() => _DropboxConnectDialogState();
}

class _DropboxConnectDialogState extends State<DropboxConnectDialog> {
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
      final uri = _authorizeUri ??= widget.provider.beginAuthorization();
      final open =
          widget.openUri ??
          (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
      final opened = await open(uri);
      // launchUrl reports failure by returning false, not only by throwing;
      // leaving that silent strands the user on a dialog whose instructions
      // claim a browser page is open.
      if (!opened) {
        if (!mounted) return;
        setState(
          () => _errorText =
              context.l10n.settings_cloudSync_dropbox_connect_browserFailed,
        );
      }
    } on CloudStorageException catch (e) {
      // The dialog is barrier-dismissible; the open can outlive this State.
      if (!mounted) return;
      setState(() => _errorText = e.displayMessage);
    } catch (e) {
      // launchUrl can throw a raw PlatformException (e.g. no browser
      // available); surface it the same way instead of leaving the dialog
      // silently stuck.
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    }
  }

  Future<void> _connect() async {
    final l10n = context.l10n;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(
        () => _errorText = l10n.settings_cloudSync_dropbox_connect_emptyCode,
      );
      return;
    }
    setState(() {
      _connecting = true;
      _errorText = null;
    });
    try {
      await widget.provider.completeAuthorization(code);
      if (mounted) Navigator.of(context).pop(true);
    } on CloudStorageException catch (e) {
      // The dialog is barrier-dismissible; the exchange can outlive this
      // State.
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorText = l10n.settings_cloudSync_dropbox_connect_failed(
          e.displayMessage,
        );
      });
    } catch (e) {
      // completeAuthorization's final _store.save() can throw a raw
      // PlatformException from the keychain (see FallbackSecureStorage,
      // which rethrows anything except -34018). Without this catch the
      // dialog would stay wedged forever with _connecting stuck true.
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorText = l10n.settings_cloudSync_dropbox_connect_failed(
          e.toString(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_cloudSync_dropbox_connect_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_cloudSync_dropbox_connect_instructions),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            autofocus: true,
            enabled: !_connecting,
            decoration: InputDecoration(
              labelText: l10n.settings_cloudSync_dropbox_connect_codeLabel,
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
          child: Text(l10n.settings_cloudSync_dropbox_connect_reopenBrowser),
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
              : Text(l10n.settings_cloudSync_dropbox_connect_submit),
        ),
      ],
    );
  }
}
