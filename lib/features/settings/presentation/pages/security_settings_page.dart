import 'package:flutter/material.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/biometric_service.dart';
import 'package:submersion/core/services/security/database_security_service.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/features/settings/presentation/widgets/enable_encryption_dialog.dart'
    show RecoveryCodeDisplay;
import 'package:submersion/features/settings/presentation/widgets/security_setup_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App Security settings: the App Lock tier (password/biometric gate,
/// auto-lock timeout) and the Database Encryption tier (SQLCipher at rest),
/// sharing one credential. Reads DatabaseSecurityService directly — the
/// service is a pre-provider singleton, so this page is stateful rather
/// than provider-driven, mirroring how the service itself works.
class SecuritySettingsPage extends StatefulWidget {
  /// Argon2id cost for slots this page mints. Overridable only so widget
  /// tests can exercise the credential flows: the production parameters are
  /// 64 MiB / 3 passes, which is pure-Dart (and unusably slow) under
  /// `flutter test`. Same seam the service itself exposes.
  @visibleForTesting
  final KdfParams kdf;

  const SecuritySettingsPage({super.key, this.kdf = const KdfParams()});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  DatabaseSecurityService get _security => DatabaseSecurityService.instance;

  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    BiometricService().isAvailable().then((available) {
      if (mounted) setState(() => _biometricsAvailable = available);
    });
  }

  Future<String> _dbPath() => DatabaseService.instance.databasePath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final appLockOn = _security.appLockEnabled;
    final encryptionOn = _security.encryptionEnabled;
    final hasCredential = appLockOn || encryptionOn;

    return ListView(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: Text(l10n.settings_security_appLock),
          subtitle: Text(l10n.settings_security_appLock_subtitle),
          value: appLockOn,
          onChanged: (v) => v ? _enableAppLock() : _disableAppLock(),
        ),
        if (appLockOn) ...[
          if (_biometricsAvailable)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(l10n.settings_security_biometrics),
              value: _security.preferences.appLockBiometricsEnabled,
              onChanged: (v) async {
                await _security.preferences.setAppLockBiometricsEnabled(v);
                if (mounted) setState(() {});
              },
            ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l10n.settings_security_autoLock),
            subtitle: Text(
              _timeoutLabel(
                context,
                _security.preferences.appLockTimeoutMinutes,
              ),
            ),
            onTap: _pickTimeout,
          ),
        ],
        if (hasCredential) ...[
          ListTile(
            leading: const Icon(Icons.password),
            title: Text(l10n.settings_security_changePassword),
            onTap: _changePassword,
          ),
          ListTile(
            leading: const Icon(Icons.autorenew),
            title: Text(l10n.settings_security_regenerateRecovery),
            onTap: _regenerateRecovery,
          ),
          const Divider(),
        ],
        SwitchListTile(
          secondary: Icon(
            encryptionOn ? Icons.enhanced_encryption : Icons.no_encryption,
            color: encryptionOn ? theme.colorScheme.primary : null,
          ),
          title: Text(l10n.settings_security_encryption),
          subtitle: Text(l10n.settings_security_encryption_subtitle),
          value: encryptionOn,
          onChanged: (v) async {
            if (!v) {
              await _disableEncryption();
              return;
            }
            final dbPath = await _dbPath();
            if (!mounted) return;
            final credentialExists =
                hasCredential || _security.hasCredential(dbPath: dbPath);
            if (!credentialExists) {
              final ok = await _setupCredential(enableAppLock: false);
              if (!ok || !mounted) return;
            } else if (!_security.isUnlocked) {
              final secret = await _promptPassword(
                l10n.settings_security_unlock_title,
              );
              if (secret == null || !mounted) return;
            }
            await _enableEncryption(clearCredentialOnCancel: !hasCredential);
          },
        ),
      ],
    );
  }

  String _timeoutLabel(BuildContext context, int minutes) {
    final l10n = context.l10n;
    if (minutes < 0) return l10n.settings_security_autoLock_never;
    if (minutes == 0) return l10n.settings_security_autoLock_immediately;
    return l10n.settings_security_autoLock_minutes(minutes);
  }

  Future<bool> _enableAppLock() async {
    if (_security.encryptionEnabled) {
      if (!_security.isUnlocked) {
        final secret = await _promptPassword(
          context.l10n.settings_security_unlock_title,
        );
        if (secret == null || !mounted) return false;
      }
      await _security.setAppLockEnabled(true);
      if (mounted) setState(() {});
      return true;
    }
    return _setupCredential(enableAppLock: true);
  }

  Future<bool> _setupCredential({required bool enableAppLock}) async {
    final dbPath = await _dbPath();
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SecuritySetupDialog(
        onSetPassword: (password) async {
          final recoveryCode = await _security.enableSecurity(
            password: password,
            dbPath: dbPath,
            kdf: widget.kdf,
          );
          if (enableAppLock) {
            await _security.setAppLockEnabled(true);
          }
          return recoveryCode;
        },
      ),
    );
    if (mounted) setState(() {});
    return ok == true;
  }

  Future<void> _disableAppLock() async {
    final l10n = context.l10n;
    final secret = await _promptPassword(l10n.settings_security_unlock_title);
    if (secret == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_security_turnOffAppLock_title),
        content: Text(l10n.settings_security_turnOffAppLock_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settings_security_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_security_turnOff),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_security.encryptionEnabled) {
      await _security.setAppLockEnabled(false);
    } else {
      await _security.disableSecurity(dbPath: await _dbPath());
    }
    if (mounted) setState(() {});
  }

  Future<void> _enableEncryption({bool clearCredentialOnCancel = false}) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_security_enableEncryption_title),
        content: Text(l10n.settings_security_enableEncryption_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settings_security_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_security_continue),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (clearCredentialOnCancel &&
          !_security.appLockEnabled &&
          !_security.encryptionEnabled) {
        await _security.disableSecurity(dbPath: await _dbPath());
        if (mounted) setState(() {});
      }
      return;
    }
    if (!mounted) return;
    await _runWithProgress(
      (onPhase) => _security.enableEncryption(onPhase: onPhase),
    );
    if (mounted) setState(() {});
  }

  Future<void> _disableEncryption() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_security_disableEncryption_title),
        content: Text(l10n.settings_security_disableEncryption_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.settings_security_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_security_turnOff),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runWithProgress(
      (onPhase) => _security.disableEncryption(onPhase: onPhase),
    );
    if (mounted) setState(() {});
  }

  /// Runs a long encryption operation behind a blocking progress dialog.
  Future<void> _runWithProgress(
    Future<void> Function(void Function(String) onPhase) operation,
  ) async {
    final phase = ValueNotifier<String>('backup');
    Object? error;
    // Unawaited: the dialog closes from the operation's completion below.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: phase,
            builder: (context, value, _) => Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(_phaseLabel(context, value))),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await operation((p) => phase.value = p);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(error.toString()),
        ),
      );
    }
    phase.dispose();
  }

  String _phaseLabel(BuildContext context, String phase) {
    final l10n = context.l10n;
    switch (phase) {
      case 'backup':
        return l10n.settings_security_encryption_progress_backup;
      case 'encrypt':
        return l10n.settings_security_encryption_progress_encrypt;
      case 'decrypt':
        return l10n.settings_security_encryption_progress_decrypt;
      case 'reopen':
      default:
        return l10n.settings_security_encryption_progress_reopen;
    }
  }

  Future<void> _pickTimeout() async {
    final l10n = context.l10n;
    const options = [0, 1, 5, 15, -1];
    final current = _security.preferences.appLockTimeoutMinutes;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.settings_security_autoLock),
        children: [
          RadioGroup<int>(
            groupValue: current,
            onChanged: (v) => Navigator.of(dialogContext).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final minutes in options)
                  RadioListTile<int>(
                    value: minutes,
                    title: Text(_timeoutLabel(dialogContext, minutes)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await _security.preferences.setAppLockTimeoutMinutes(selected);
    if (mounted) setState(() {});
  }

  Future<void> _changePassword() async {
    final dbPath = await _dbPath();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ChangePasswordDialog(
        onSubmit: (current, next) => _security.changePassword(
          currentSecret: current,
          newPassword: next,
          dbPath: dbPath,
          kdf: widget.kdf,
        ),
      ),
    );
  }

  Future<void> _regenerateRecovery() async {
    final l10n = context.l10n;
    final secret = await _promptPassword(l10n.settings_security_unlock_title);
    if (secret == null || !mounted) return;
    final String newCode;
    try {
      newCode = await _security.regenerateRecoveryCode(
        currentSecret: secret,
        dbPath: await _dbPath(),
        kdf: widget.kdf,
      );
    } on WrongPassphraseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settings_security_wrongPassword)),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_security_recoveryCode_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settings_security_recoveryCode_explain),
            const SizedBox(height: 12),
            RecoveryCodeDisplay(code: newCode),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.settings_security_done),
          ),
        ],
      ),
    );
  }

  /// Prompts for the current password and verifies it by unwrap. Returns the
  /// accepted secret, or null on cancel.
  Future<String?> _promptPassword(String title) async {
    final l10n = context.l10n;
    final dbPath = await _dbPath();
    if (!mounted) return null;
    final controller = TextEditingController();
    String? accepted;
    // Outside the builder: setDialogState rebuilds the builder body, so a
    // local declared inside it would reset to false on every rebuild and
    // the error could never display.
    var showError = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.settings_security_password,
                errorText: showError
                    ? l10n.settings_security_wrongPassword
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.settings_security_cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await _security.unlockWithSecret(
                    controller.text,
                    dbPath: dbPath,
                  );
                  if (ok) {
                    accepted = controller.text;
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } else {
                    setDialogState(() => showError = true);
                  }
                },
                child: Text(l10n.settings_security_continue),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return accepted;
  }
}

/// Current + new + confirm password dialog for the App Security credential.
class _ChangePasswordDialog extends StatefulWidget {
  final Future<void> Function(String current, String next) onSubmit;

  const _ChangePasswordDialog({required this.onSubmit});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
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
      _currentError = null;
      _nextError = _next.text.length < 4
          ? l10n.settings_security_passwordTooShort
          : null;
      _confirmError = _next.text != _confirm.text
          ? l10n.settings_security_passwordMismatch
          : null;
    });
    if (_nextError != null || _confirmError != null) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop();
    } on WrongPassphraseException {
      if (mounted) {
        setState(() => _currentError = l10n.settings_security_wrongPassword);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.settings_security_changePassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _current,
              obscureText: true,
              autofocus: true,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.settings_security_currentPassword,
                errorText: _currentError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _next,
              obscureText: true,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n.settings_security_newPassword,
                errorText: _nextError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              obscureText: true,
              enabled: !_busy,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.settings_security_confirmPassword,
                errorText: _confirmError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.settings_security_cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.settings_security_continue),
        ),
      ],
    );
  }
}
