import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Escape-hatch dialogs for the startup lock screen. Rendered inside the
/// splash MaterialApp, which now carries the localization delegates (see
/// `StartupWrapper.build`), so these strings resolve through `context.l10n`
/// like the rest of the app.

/// Recovery-code entry. [onSubmit] returns true when the code unlocked the
/// database. The dialog pops with true on success, false/null on cancel.
Future<bool?> showRecoveryCodeUnlockDialog(
  BuildContext context, {
  required Future<bool> Function(String code) onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _SecretPromptDialog(
      title: context.l10n.lock_recoveryCode_title,
      body: context.l10n.lock_recoveryCode_body,
      fieldLabel: context.l10n.settings_cloudSync_encryption_recoveryTitle,
      submitLabel: context.l10n.settings_cloudSync_encryption_unlock,
      errorText: context.l10n.lock_recoveryCode_error,
      obscure: false,
      onSubmit: onSubmit,
    ),
  );
}

/// Confirms setting the locked database aside. Requires typing START FRESH.
Future<bool?> showStartFreshConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _StartFreshConfirmDialog(),
  );
}

/// Forces a new password after a recovery-code unlock (the old password is
/// lost). Modal: no cancel, must complete.
Future<void> showForcedPasswordResetDialog(
  BuildContext context, {
  required Future<void> Function(String newPassword) onSubmit,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _NewPasswordDialog(
      title: context.l10n.lock_forcedReset_title,
      body: context.l10n.lock_forcedReset_body,
      onSubmit: onSubmit,
    ),
  );
}

/// Sidecar repair: confirm the password to rebuild the lost key file.
/// [onSubmit] rebuilds and returns true; the caller shows the new recovery
/// code afterwards. Declining is allowed (repair is reoffered next launch).
Future<bool?> showSidecarRepairDialog(
  BuildContext context, {
  required Future<bool> Function(String password) onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _SecretPromptDialog(
      title: context.l10n.lock_sidecarRepair_title,
      body: context.l10n.lock_sidecarRepair_body,
      fieldLabel: context.l10n.settings_security_password,
      submitLabel: context.l10n.lock_sidecarRepair_submit,
      errorText: context.l10n.lock_sidecarRepair_error,
      obscure: true,
      onSubmit: onSubmit,
    ),
  );
}

/// Shows a freshly generated recovery code with a save confirmation.
Future<void> showNewRecoveryCodeDialog(BuildContext context, String code) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.lock_newRecoveryCode_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.settings_security_recoveryCode_explain),
          const SizedBox(height: 16),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.settings_security_recoveryCode_savedConfirm),
        ),
      ],
    ),
  );
}

/// Shared single-secret prompt with inline error handling.
class _SecretPromptDialog extends StatefulWidget {
  final String title;
  final String body;
  final String fieldLabel;
  final String submitLabel;
  final String errorText;
  final bool obscure;
  final Future<bool> Function(String secret) onSubmit;

  const _SecretPromptDialog({
    required this.title,
    required this.body,
    required this.fieldLabel,
    required this.submitLabel,
    required this.errorText,
    required this.obscure,
    required this.onSubmit,
  });

  @override
  State<_SecretPromptDialog> createState() => _SecretPromptDialogState();
}

class _SecretPromptDialogState extends State<_SecretPromptDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _showError = false;
    });
    try {
      final ok = await widget.onSubmit(_controller.text);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _showError = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.body),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: widget.obscure,
            autofocus: true,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.fieldLabel,
              border: const OutlineInputBorder(),
              errorText: _showError ? widget.errorText : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

/// The typed confirmation token. Deliberately NOT localized: the comparison
/// below is exact, the same literal is shown as the field hint, and keeping
/// one ASCII token avoids putting a locale-dependent gate in front of a
/// destructive action.
const String _startFreshToken = 'START FRESH';

class _StartFreshConfirmDialog extends StatefulWidget {
  const _StartFreshConfirmDialog();

  @override
  State<_StartFreshConfirmDialog> createState() =>
      _StartFreshConfirmDialogState();
}

class _StartFreshConfirmDialogState extends State<_StartFreshConfirmDialog> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final match = _controller.text.trim() == _startFreshToken;
      if (match != _confirmed) setState(() => _confirmed = match);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.lock_startFresh_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.lock_startFresh_body(_startFreshToken)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: _startFreshToken,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          child: Text(context.l10n.lock_startFresh_confirm),
        ),
      ],
    );
  }
}

/// New password + confirmation, no cancel (forced reset after recovery).
class _NewPasswordDialog extends StatefulWidget {
  final String title;
  final String body;
  final Future<void> Function(String newPassword) onSubmit;

  const _NewPasswordDialog({
    required this.title,
    required this.body,
    required this.onSubmit,
  });

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_password.text.length < 4) {
      setState(() => _error = context.l10n.settings_security_passwordTooShort);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = context.l10n.settings_security_passwordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_password.text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.lock_forcedReset_error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.body),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: context.l10n.settings_security_newPassword,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            enabled: !_busy,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: context.l10n.settings_security_confirmPassword,
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(context.l10n.lock_forcedReset_submit),
        ),
      ],
    );
  }
}
