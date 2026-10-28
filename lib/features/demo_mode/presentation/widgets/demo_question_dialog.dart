import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before entering or leaving demo mode. Completes with true only when
/// [action] is tapped; Cancel, a tap outside or Back all answer no.
///
/// Both questions go through here so they keep the same buttons, order and
/// dismissal. The dialog reads only through its own context: it can outlive
/// the caller's, as when the Settings pane it was opened from is replaced.
Future<bool> askDemoQuestion(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return answer ?? false;
}
