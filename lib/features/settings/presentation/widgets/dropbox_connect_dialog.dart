import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/browser_launch.dart';

/// The copy-paste OAuth dialog: opens the Dropbox authorize page in the
/// system browser and exchanges the pasted code. Pops `true` on success.
///
/// Copy link is always offered, not just after a failed launch: on Linux a
/// stale GIO scheme handler makes the launch report success and show nothing
/// (Debian 13), so there is no error state to hang the escape hatch off.
///
/// [openUri] is injectable for widget tests; production uses [openInBrowser].
class DropboxConnectDialog extends StatefulWidget {
  const DropboxConnectDialog({
    required this.provider,
    this.openUri,
    this.expectedAccount,
    this.onDifferentAccount,
    super.key,
  });

  final DropboxStorageProvider provider;
  final Future<bool> Function(Uri uri)? openUri;

  /// The account this sign-in must be; another closes the dialog with false
  /// after telling [onDifferentAccount] which it was (issue #3811).
  final String? expectedAccount;
  final ValueChanged<String>? onDifferentAccount;

  @override
  State<DropboxConnectDialog> createState() => _DropboxConnectDialogState();
}

class _DropboxConnectDialogState extends State<DropboxConnectDialog> {
  static final _log = LoggerService.forClass(DropboxConnectDialog);

  final _codeController = TextEditingController();
  Uri? _authorizeUri;
  String? _errorText;
  bool _linkCopied = false;
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

  /// The pending authorize URI, generated on first use.
  ///
  /// The same URI is reused by Reopen browser and Copy link: a second
  /// [DropboxStorageProvider.beginAuthorization] would replace the pending
  /// PKCE verifier, and the code from the page already open would then fail
  /// the exchange. Returns null after reporting an auth error inline.
  Uri? _pendingAuthorizeUri() {
    try {
      return _authorizeUri ??= widget.provider.beginAuthorization();
    } on CloudStorageException catch (e) {
      // The dialog is barrier-dismissible; this can outlive the State.
      if (mounted) setState(() => _errorText = e.displayMessage);
      return null;
    }
  }

  Future<void> _openBrowser() async {
    final uri = _pendingAuthorizeUri();
    if (uri == null) return;

    bool opened;
    try {
      opened = await (widget.openUri ?? openInBrowser)(uri);
    } catch (e) {
      // Off Linux, url_launcher reports "no handler" by throwing a raw
      // PlatformException. Its toString() named no action a diver could
      // take, so the failure reads the same either way and the detail goes
      // to the log.
      _log.warning('Could not open the Dropbox authorize page: $e');
      opened = false;
    }
    if (!mounted) return;
    // launchUrl reports failure by returning false, not only by throwing;
    // leaving that silent strands the user on a dialog whose instructions
    // claim a browser page is open. A successful (re)open clears any
    // stale error from an earlier failed attempt.
    setState(
      () => _errorText = opened
          ? null
          : context.l10n.settings_oauth_connect_browserFailed,
    );
  }

  /// Copies the authorize URL so the user can open it by hand.
  Future<void> _copyLink() async {
    final uri = _pendingAuthorizeUri();
    if (uri == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
    } on Exception catch (e) {
      // A platform-channel call, so it can throw. Letting that escape the
      // button handler would hand a dead button to the one user who needs
      // this most: the one whose browser never opened.
      _log.warning('Could not copy the authorize link: $e');
      if (!mounted) return;
      setState(
        () => _errorText = context.l10n.settings_oauth_connect_copyFailed,
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _linkCopied = true;
      // The user now has the link, so the launch failure is spent advice.
      _errorText = null;
    });
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
      await widget.provider.completeAuthorization(
        code,
        expectedAccount: widget.expectedAccount,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on CloudAccountMismatchException catch (e) {
      widget.onDifferentAccount?.call(e.signedInAs);
      if (mounted) Navigator.of(context).pop(false);
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
      // Scrollable so the copy-link row cannot push the code field off a
      // short window; the actions stay pinned below it.
      scrollable: true,
      title: Text(l10n.settings_cloudSync_dropbox_connect_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settings_cloudSync_dropbox_connect_instructions),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _connecting ? null : _copyLink,
              icon: const Icon(Icons.link, size: 18),
              label: Text(l10n.settings_oauth_connect_copyLink),
            ),
          ),
          if (_linkCopied)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.settings_oauth_connect_linkCopied,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
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
