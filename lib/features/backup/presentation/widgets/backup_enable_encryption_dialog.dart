import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/enable_encryption_dialog.dart'
    show RecoveryCodeDisplay;
import 'package:submersion/l10n/l10n_extension.dart';

/// The enable-backup-encryption flow: a password form (with a data-loss
/// warning), then the generated recovery code behind a confirm-saved gate.
/// [onEnable] runs the actual enable and returns the recovery code; [onFinished]
/// runs after the user confirms they saved the code. Pops `true` on success.
class BackupEnableEncryptionDialog extends StatefulWidget {
  final Future<String> Function(String passphrase) onEnable;
  final Future<void> Function() onFinished;

  const BackupEnableEncryptionDialog({
    super.key,
    required this.onEnable,
    required this.onFinished,
  });

  @override
  State<BackupEnableEncryptionDialog> createState() =>
      _BackupEnableEncryptionDialogState();
}

enum _Phase { form, busy, recovery }

class _BackupEnableEncryptionDialogState
    extends State<BackupEnableEncryptionDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _phase = _Phase.form;
  var _recoverySaved = false;
  String? _passwordError;
  String? _confirmError;
  String? _recoveryCode;
  String? _enableError;
  String? _finishError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final l10n = context.l10n;
    setState(() {
      _passwordError = _password.text.length < 8
          ? l10n.settings_backupEncryption_passwordTooShort
          : null;
      _confirmError = _password.text != _confirm.text
          ? l10n.settings_backupEncryption_passwordMismatch
          : null;
      _enableError = null;
    });
    if (_passwordError != null || _confirmError != null) return;
    setState(() => _phase = _Phase.busy);
    try {
      final code = await widget.onEnable(_password.text);
      if (!mounted) return;
      setState(() {
        _recoveryCode = code;
        _phase = _Phase.recovery;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _enableError = e.toString();
      });
    }
  }

  Future<void> _finish() async {
    setState(() {
      _phase = _Phase.busy;
      _finishError = null;
    });
    try {
      await widget.onFinished();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      // Don't strand the user on the non-poppable spinner with the recovery
      // code hidden. Return to the recovery gate with an error so they can
      // retry -- the code is still shown and the saved checkbox stays ticked.
      setState(() {
        _phase = _Phase.recovery;
        _finishError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Once onEnable has persisted the key/mirror (busy + recovery phases), the
    // system Back gesture must not bypass the saved-code gate and leave the
    // preference off with a half-completed key lifecycle. Only the initial form
    // phase (nothing persisted yet) may pop.
    return PopScope(
      canPop: _phase == _Phase.form,
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final l10n = context.l10n;
    switch (_phase) {
      case _Phase.form:
        return AlertDialog(
          title: Text(l10n.settings_backupEncryption_enable),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.settings_backupEncryption_password,
                    errorText: _passwordError,
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
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.settings_backupEncryption_warnLoss,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (_enableError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _enableError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.settings_backupEncryption_cancel),
            ),
            FilledButton(
              onPressed: _submitForm,
              child: Text(l10n.settings_backupEncryption_continue),
            ),
          ],
        );
      case _Phase.busy:
        return const AlertDialog(
          content: SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      case _Phase.recovery:
        return AlertDialog(
          title: Text(l10n.settings_backupEncryption_recoveryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settings_backupEncryption_recoveryExplain),
              const SizedBox(height: 12),
              RecoveryCodeDisplay(code: _recoveryCode!),
              CheckboxListTile(
                value: _recoverySaved,
                onChanged: (v) => setState(() => _recoverySaved = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  l10n.settings_backupEncryption_recoverySavedConfirm,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (_finishError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _finishError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: _recoverySaved ? _finish : null,
              child: Text(l10n.settings_backupEncryption_done),
            ),
          ],
        );
    }
  }
}
