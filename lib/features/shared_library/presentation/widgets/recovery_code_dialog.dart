import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Shows a shared site library's recovery code once (issue #2567). It can
/// make its holder an owner and unlock an encrypted library, so the dialog
/// closes only when the owner says it is stored.
Future<void> showRecoveryCodeDialog(BuildContext context, String code) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        final theme = Theme.of(dialogContext);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.sharedLibrary_recovery_title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.sharedLibrary_recovery_body),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    code,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.common_action_copy),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: code)),
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.sharedLibrary_recovery_stored),
              ),
            ],
          ),
        );
      },
    );

/// Asks for a library's passphrase or recovery code (hidden while typed).
/// Null when cancelled.
Future<String?> promptLibrarySecret(BuildContext context, {String? message}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _SecretDialog(message: message),
    );

/// Owns its controller, so the field outlives the closing animation.
class _SecretDialog extends StatefulWidget {
  const _SecretDialog({this.message});

  /// Why the secret is asked for, above the field.
  final String? message;

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sharedLibrary_encrypted_unlock),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          TextField(
            key: const Key('secret-field'),
            controller: _controller,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.sharedLibrary_encrypted_passphrase,
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.sharedLibrary_encrypted_unlock),
        ),
      ],
    );
  }
}
