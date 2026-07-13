import 'package:flutter/material.dart';

import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/l10n/l10n_extension.dart';

/// Change the backup password: verify the current password, then rewrap the
/// passphrase slot with a new one. [onSubmit] performs the change and throws
/// [WrongPassphraseException] when the current password is wrong. Pops `true`
/// on success.
class BackupChangePasswordDialog extends StatefulWidget {
  final Future<void> Function(String current, String next) onSubmit;

  const BackupChangePasswordDialog({super.key, required this.onSubmit});

  @override
  State<BackupChangePasswordDialog> createState() =>
      _BackupChangePasswordDialogState();
}

class _BackupChangePasswordDialogState
    extends State<BackupChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  String? _currentError;
  String? _nextError;
  String? _confirmError;

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
      _nextError = _next.text.length < 8
          ? l10n.settings_backupEncryption_passwordTooShort
          : null;
      _confirmError = _next.text != _confirm.text
          ? l10n.settings_backupEncryption_passwordMismatch
          : null;
      _currentError = null;
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
        _currentError = l10n.settings_backupEncryption_wrongPassword;
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
    // While the KDF/keyslot rewrap is running, a barrier tap or Back must not
    // pop the route: the service would finish changing the password after the
    // dialog vanished, so the user could believe it was cancelled.
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l10n.settings_backupEncryption_changePassword),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _current,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.settings_backupEncryption_currentPassword,
                  errorText: _currentError,
                ),
              ),
              TextField(
                controller: _next,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.settings_backupEncryption_newPassword,
                  errorText: _nextError,
                ),
              ),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.settings_backupEncryption_passwordConfirm,
                  errorText: _confirmError,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.settings_backupEncryption_changePasswordWarn,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.settings_backupEncryption_cancel),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(l10n.settings_backupEncryption_done),
          ),
        ],
      ),
    );
  }
}
