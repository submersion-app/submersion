import 'package:flutter/material.dart';

import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Prompt for a passphrase (or recovery code) and run [onSubmit] with it.
/// A [WrongPassphraseException] keeps the dialog open with an inline error;
/// any success pops with the entered secret. Returns null when cancelled.
Future<String?> showEncryptionPassphraseDialog(
  BuildContext context, {
  required String title,
  String? hint,
  required Future<void> Function(String secret) onSubmit,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _PassphraseDialog(title: title, hint: hint, onSubmit: onSubmit),
  );
}

class _PassphraseDialog extends StatefulWidget {
  final String title;
  final String? hint;
  final Future<void> Function(String secret) onSubmit;

  const _PassphraseDialog({
    required this.title,
    this.hint,
    required this.onSubmit,
  });

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final secret = _controller.text;
    if (secret.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Capture the navigator before the await so we neither touch a
    // possibly-defunct context afterward nor pop the wrong navigator.
    final navigator = Navigator.of(context);
    try {
      await widget.onSubmit(secret);
      // A successful onSubmit can trigger a screen takeover that clears the
      // whole stack (e.g. restore -> RestoreCompletePage.show(), which does
      // pushAndRemoveUntil(..., (_) => false)). Popping here would then remove
      // the last remaining route and empty the navigator history, tripping
      // NavigatorState.build's `_history.isNotEmpty` assertion. Only self-pop
      // when the dialog route is still on the stack to pop.
      if (mounted && navigator.canPop()) navigator.pop(secret);
    } on WrongPassphraseException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.l10n.settings_cloudSync_encryption_wrongPassphrase;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // While onSubmit is running (KDF), a Back gesture must not pop the route:
    // the caller may already have replaced a keyslot (e.g. regenerate rotates
    // the recovery slot before returning), and popping here would discard the
    // result the caller needs to show.
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          obscureText: true,
          autofocus: true,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText:
                widget.hint ?? l10n.settings_cloudSync_encryption_passphrase,
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.settings_cloudSync_encryption_cancel),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.settings_cloudSync_encryption_unlock),
          ),
        ],
      ),
    );
  }
}

/// Change-passphrase dialog: current + new + confirm. [onSubmit] receives
/// (current, next); a [WrongPassphraseException] shows inline on the current
/// field. Returns true when the change succeeded.
Future<bool?> showChangePassphraseDialog(
  BuildContext context, {
  required Future<void> Function(String current, String next) onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ChangePassphraseDialog(onSubmit: onSubmit),
  );
}

class _ChangePassphraseDialog extends StatefulWidget {
  final Future<void> Function(String current, String next) onSubmit;

  const _ChangePassphraseDialog({required this.onSubmit});

  @override
  State<_ChangePassphraseDialog> createState() =>
      _ChangePassphraseDialogState();
}

class _ChangePassphraseDialogState extends State<_ChangePassphraseDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _confirmError;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() {
      _currentError = null;
      _nextError = _next.text.length < 8
          ? l10n.settings_cloudSync_encryption_passphraseTooShort
          : null;
      _confirmError = _next.text != _confirm.text
          ? l10n.settings_cloudSync_encryption_passphraseMismatch
          : null;
    });
    if (_nextError != null || _confirmError != null) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on WrongPassphraseException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _currentError =
            context.l10n.settings_cloudSync_encryption_wrongPassphrase;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _currentError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_cloudSync_encryption_changePassphrase),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l10n.settings_cloudSync_encryption_currentPassphrase,
              errorText: _currentError,
            ),
          ),
          TextField(
            controller: _next,
            obscureText: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l10n.settings_cloudSync_encryption_newPassphrase,
              errorText: _nextError,
            ),
          ),
          TextField(
            controller: _confirm,
            obscureText: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l10n.settings_cloudSync_encryption_passphraseConfirm,
              errorText: _confirmError,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.settings_cloudSync_encryption_cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.settings_cloudSync_encryption_changePassphrase),
        ),
      ],
    );
  }
}
