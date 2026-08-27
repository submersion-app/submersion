import 'package:flutter/material.dart';

import 'package:submersion/features/settings/presentation/widgets/enable_encryption_dialog.dart'
    show RecoveryCodeDisplay;
import 'package:submersion/l10n/l10n_extension.dart';

/// The set-app-password flow: a password form, then the generated recovery
/// code behind a confirm-saved gate. [onSetPassword] runs the actual enable
/// and returns the recovery code. Pops `true` once the user confirms they
/// saved the code. Mirrors BackupEnableEncryptionDialog.
class SecuritySetupDialog extends StatefulWidget {
  final Future<String> Function(String password) onSetPassword;

  const SecuritySetupDialog({super.key, required this.onSetPassword});

  @override
  State<SecuritySetupDialog> createState() => _SecuritySetupDialogState();
}

enum _Phase { form, busy, recovery }

class _SecuritySetupDialogState extends State<SecuritySetupDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _phase = _Phase.form;
  var _recoverySaved = false;
  String? _passwordError;
  String? _confirmError;
  String? _recoveryCode;
  String? _enableError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final l10n = context.l10n;
    setState(() {
      _passwordError = _password.text.length < 4
          ? l10n.settings_security_passwordTooShort
          : null;
      _confirmError = _password.text != _confirm.text
          ? l10n.settings_security_passwordMismatch
          : null;
      _enableError = null;
    });
    if (_passwordError != null || _confirmError != null) return;
    setState(() => _phase = _Phase.busy);
    try {
      final code = await widget.onSetPassword(_password.text);
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

  @override
  Widget build(BuildContext context) {
    // Once the credential exists (busy + recovery phases), the Back gesture
    // must not bypass the saved-code gate. Only the initial form may pop.
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
          title: Text(l10n.settings_security_setPassword),
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
                    labelText: l10n.settings_security_password,
                    errorText: _passwordError,
                  ),
                ),
                // Outlined fields float their label over the top border and
                // reserve no room above the box for it, so stacking them flush
                // paints this label onto the field above.
                const SizedBox(height: 16),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.settings_security_confirmPassword,
                    errorText: _confirmError,
                  ),
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
              child: Text(l10n.settings_security_cancel),
            ),
            FilledButton(
              onPressed: _submitForm,
              child: Text(l10n.settings_security_continue),
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
          title: Text(l10n.settings_security_recoveryCode_title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settings_security_recoveryCode_explain),
              const SizedBox(height: 12),
              RecoveryCodeDisplay(code: _recoveryCode!),
              CheckboxListTile(
                value: _recoverySaved,
                onChanged: (v) => setState(() => _recoverySaved = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  l10n.settings_security_recoveryCode_savedConfirm,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: _recoverySaved
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text(l10n.settings_security_done),
            ),
          ],
        );
    }
  }
}
