import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before a location delete (a place, or one history entry). True only
/// when the diver confirms.
Future<bool> confirmLocationDelete(BuildContext context, String message) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          key: const ValueKey('location_confirm_delete'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// The one message every location write shows when it fails.
void showLocationWriteFailed(ScaffoldMessengerState messenger, String text) {
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
