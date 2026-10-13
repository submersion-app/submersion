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
