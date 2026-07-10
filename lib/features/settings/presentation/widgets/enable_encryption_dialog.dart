import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The enable-encryption flow: passphrase form (with warnings and the
/// delete-plaintext-backups choice), then the generated recovery code with a
/// confirm-saved gate. [onEnable] runs the actual enable and returns the
/// recovery code; [onFinished] runs after the user confirms they saved it
/// (its argument is the delete-plaintext-backups checkbox).
class EnableEncryptionDialog extends StatefulWidget {
  final Future<String> Function(String passphrase) onEnable;
  final Future<void> Function(bool deletePlaintextBackups) onFinished;

  const EnableEncryptionDialog({
    super.key,
    required this.onEnable,
    required this.onFinished,
  });

  @override
  State<EnableEncryptionDialog> createState() => _EnableEncryptionDialogState();
}

enum _Phase { form, busy, recovery }

class _EnableEncryptionDialogState extends State<EnableEncryptionDialog> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  var _phase = _Phase.form;
  var _deleteBackups = true;
  var _recoverySaved = false;
  String? _passphraseError;
  String? _confirmError;
  String? _recoveryCode;
  String? _enableError;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final l10n = context.l10n;
    setState(() {
      _passphraseError = _passphrase.text.length < 8
          ? l10n.settings_cloudSync_encryption_passphraseTooShort
          : null;
      _confirmError = _passphrase.text != _confirm.text
          ? l10n.settings_cloudSync_encryption_passphraseMismatch
          : null;
      _enableError = null;
    });
    if (_passphraseError != null || _confirmError != null) return;
    setState(() => _phase = _Phase.busy);
    try {
      final code = await widget.onEnable(_passphrase.text);
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
    setState(() => _phase = _Phase.busy);
    await widget.onFinished(_deleteBackups);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    switch (_phase) {
      case _Phase.form:
        return AlertDialog(
          title: Text(l10n.settings_cloudSync_encryption_enable),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _passphrase,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.settings_cloudSync_encryption_passphrase,
                    errorText: _passphraseError,
                  ),
                ),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n.settings_cloudSync_encryption_passphraseConfirm,
                    errorText: _confirmError,
                  ),
                ),
                const SizedBox(height: 16),
                _WarningText(
                  l10n.settings_cloudSync_encryption_warnUpdateDevices,
                ),
                const SizedBox(height: 8),
                _WarningText(l10n.settings_cloudSync_encryption_warnLoss),
                CheckboxListTile(
                  value: _deleteBackups,
                  onChanged: (v) => setState(() => _deleteBackups = v ?? true),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    l10n.settings_cloudSync_encryption_deletePlaintextBackups,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (_enableError != null)
                  Text(
                    _enableError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.settings_cloudSync_encryption_cancel),
            ),
            FilledButton(
              onPressed: _submitForm,
              child: Text(l10n.settings_cloudSync_encryption_continue),
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
          title: Text(l10n.settings_cloudSync_encryption_recoveryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settings_cloudSync_encryption_recoveryExplain),
              const SizedBox(height: 12),
              RecoveryCodeDisplay(code: _recoveryCode!),
              CheckboxListTile(
                value: _recoverySaved,
                onChanged: (v) => setState(() => _recoverySaved = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  l10n.settings_cloudSync_encryption_recoverySavedConfirm,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: _recoverySaved ? _finish : null,
              child: Text(l10n.settings_cloudSync_encryption_done),
            ),
          ],
        );
    }
  }
}

class _WarningText extends StatelessWidget {
  final String text;

  const _WarningText(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

/// Selectable monospace box for a recovery code. Shared by the enable flow
/// and the regenerate flow.
class RecoveryCodeDisplay extends StatelessWidget {
  final String code;

  const RecoveryCodeDisplay({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        code,
        style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}
