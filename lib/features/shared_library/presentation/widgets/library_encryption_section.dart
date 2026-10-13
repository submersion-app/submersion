import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/library_encryption_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/settings/presentation/widgets/sync_maintenance_progress_dialog.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/features/shared_library/presentation/widgets/recovery_code_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether the library is encrypted, and for owners turning it on or off
/// and changing its passphrase (issue #2567).
class LibraryEncryptionSection extends ConsumerWidget {
  const LibraryEncryptionSection({
    super.key,
    required this.library,
    required this.role,
    required this.membership,
  });

  final SharedLibrary library;
  final SharedLibraryRole role;
  final SharedLibraryMembership? membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = membership;
    final owner = canManageLibrary(role) && me != null;
    final unlocked = library.encrypted && me?.libraryKeyId == library.keyId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(
            library.encrypted ? Icons.lock_outline : Icons.lock_open_outlined,
          ),
          title: Text(l10n.sharedLibrary_encryption_title),
          subtitle: Text(
            library.encrypted
                ? l10n.sharedLibrary_encryption_statusOn
                : l10n.sharedLibrary_encryption_statusOff,
          ),
        ),
        if (owner && !library.encrypted)
          ListTile(
            leading: const Icon(Icons.enhanced_encryption_outlined),
            title: Text(l10n.sharedLibrary_encryption_on),
            subtitle: Text(l10n.sharedLibrary_encryption_onHelp),
            onTap: () => _choosePassphrase(
              context,
              ref,
              me,
              action: l10n.sharedLibrary_encryption_on,
              turnOn: true,
            ),
          ),
        if (owner && unlocked) ...[
          ListTile(
            leading: const Icon(Icons.password),
            title: Text(l10n.sharedLibrary_encryption_change),
            subtitle: Text(l10n.sharedLibrary_encryption_changeHelp),
            onTap: () => _choosePassphrase(
              context,
              ref,
              me,
              action: l10n.sharedLibrary_encryption_change,
              turnOn: false,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.no_encryption_outlined),
            title: Text(l10n.sharedLibrary_encryption_off),
            onTap: () => _turnOff(context, ref, me),
          ),
        ],
      ],
    );
  }

  Future<void> _choosePassphrase(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership me, {
    required String action,
    required bool turnOn,
  }) async {
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => _PassphraseDialog(action: action),
    );
    if (passphrase == null || !context.mounted) return;
    final service = ref.read(libraryEncryptionServiceProvider);
    // The page may rebuild this section away while the files are
    // rewritten: the new code is shown over the whole app, never skipped.
    final shown = Navigator.of(context, rootNavigator: true).context;
    final container = ProviderScope.containerOf(context, listen: false);
    final code = await _withProgress(
      context,
      action,
      (progress) => turnOn
          ? service.turnOn(
              libraryId: library.id,
              diverId: me.diverId,
              passphrase: passphrase,
              progress: progress,
            )
          : service.changePassphrase(
              libraryId: library.id,
              diverId: me.diverId,
              passphrase: passphrase,
              progress: progress,
            ),
    );
    if (code == null) return;
    container.invalidate(currentMembershipsProvider);
    if (shown.mounted) await showRecoveryCodeDialog(shown, code);
  }

  Future<void> _turnOff(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership me,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sharedLibrary_encryption_off),
        content: Text(l10n.sharedLibrary_encryption_offConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sharedLibrary_encryption_off),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    await _withProgress(context, l10n.sharedLibrary_encryption_off, (
      progress,
    ) async {
      await ref
          .read(libraryEncryptionServiceProvider)
          .turnOff(
            libraryId: library.id,
            diverId: me.diverId,
            progress: progress,
          );
      return '';
    });
    container.invalidate(currentMembershipsProvider);
  }

  /// Runs [work] behind the app's progress dialog, counting the files
  /// rewritten, with the screen held awake. Null when it failed, which a
  /// snack bar explains.
  Future<String?> _withProgress(
    BuildContext context,
    String title,
    Future<String> Function(void Function(int, int) progress) work,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      return await runWithSyncMaintenanceProgress(
        context: context,
        title: title,
        task: (report) => work((done, total) => report(done, total)),
      );
    } catch (e) {
      // Stopped after the manifest named the new key: its recovery code is
      // the way back in, so it is shown all the same.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            libraryErrorText(l10n, e is RekeyIncompleteError ? e.cause : e),
          ),
        ),
      );
      return e is RekeyIncompleteError ? e.recoveryCode : null;
    }
  }
}

/// A new passphrase, typed twice: at least 8 characters, as for encrypted
/// sync.
class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.action});

  final String action;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final error = _passphrase.text.length < 8
        ? l10n.settings_cloudSync_encryption_passphraseTooShort
        : _passphrase.text != _confirm.text
        ? l10n.settings_cloudSync_encryption_passphraseMismatch
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _passphrase.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.action),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('passphrase-field'),
            controller: _passphrase,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.sharedLibrary_encryption_passphrase,
            ),
          ),
          TextField(
            key: const Key('passphrase-confirm'),
            controller: _confirm,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.sharedLibrary_encryption_confirm,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
