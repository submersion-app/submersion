import 'package:flutter/material.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
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
    final code = await _withProgress(
      context,
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
    if (code != null && context.mounted) {
      ref.invalidate(currentMembershipsProvider);
      await showRecoveryCodeDialog(context, code);
    }
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
    await _withProgress(context, (progress) async {
      await ref
          .read(libraryEncryptionServiceProvider)
          .turnOff(
            libraryId: library.id,
            diverId: me.diverId,
            progress: progress,
          );
      return '';
    });
    ref.invalidate(currentMembershipsProvider);
  }

  /// Runs [work] behind a dialog counting the files rewritten. Null when it
  /// failed, which a snack bar explains.
  Future<String?> _withProgress(
    BuildContext context,
    Future<String> Function(void Function(int, int) progress) work,
  ) async {
    final l10n = context.l10n;
    final done = ValueNotifier<(int, int)>((0, 0));
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<(int, int)>(
            valueListenable: done,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: value.$2 == 0 ? null : value.$1 / value.$2,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.sharedLibrary_encryption_progress(value.$1, value.$2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      return await work((d, t) => done.value = (d, t));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(libraryErrorText(l10n, e))));
      }
      return null;
    } finally {
      navigator.pop();
      done.dispose();
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
